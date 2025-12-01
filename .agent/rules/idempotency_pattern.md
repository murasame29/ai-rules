# Idempotency Pattern

分散システムにおいては、メッセージの重複配信が発生するため、**冪等性（Idempotency）** の担保が必須です。

## IdempotencyChecker インターフェース

```go
// internal/model/idempotency.go
type IdempotencyChecker interface {
    IsProcessed(ctx context.Context, key string) (bool, error)
    MarkProcessing(ctx context.Context, key string, ttl time.Duration) error
    MarkCompleted(ctx context.Context, key string) error
    MarkFailed(ctx context.Context, key string, err error) error
}
```

## データベーススキーマ

```sql
-- internal/infrastructure/database/postgres/schema/001_processed_messages.sql
CREATE TABLE processed_messages (
    idempotency_key VARCHAR(256) PRIMARY KEY,
    message_id      VARCHAR(256) NOT NULL,
    message_type    VARCHAR(100) NOT NULL,
    status          VARCHAR(20) NOT NULL,  -- 'processing', 'completed', 'failed'
    started_at      TIMESTAMP NOT NULL,
    completed_at    TIMESTAMP,
    error           TEXT,
    expires_at      TIMESTAMP NOT NULL,    -- TTL
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_processed_messages_expires_at ON processed_messages(expires_at);
```

## 実装例

```go
// internal/infrastructure/database/postgres/idempotency.go
package postgres

type IdempotencyChecker struct {
    queries *sqlc.Queries
}

func NewIdempotencyChecker(pool *pgxpool.Pool) *IdempotencyChecker {
    return &IdempotencyChecker{
        queries: sqlc.New(pool),
    }
}

func (c *IdempotencyChecker) IsProcessed(ctx context.Context, key string) (bool, error) {
    msg, err := c.queries.GetProcessedMessage(ctx, key)
    if err != nil {
        if err == pgx.ErrNoRows {
            return false, nil // 未処理
        }
        return false, err
    }

    // 有効期限切れは未処理扱い
    if time.Now().After(msg.ExpiresAt) {
        return false, nil
    }

    // 完了ステータスのみ処理済みとする
    return msg.Status == "completed", nil
}

func (c *IdempotencyChecker) MarkProcessing(ctx context.Context, key string, ttl time.Duration) error {
    return c.queries.UpsertProcessedMessage(ctx, sqlc.UpsertProcessedMessageParams{
        IdempotencyKey: key,
        Status:         "processing",
        ExpiresAt:      time.Now().Add(ttl),
    })
}

func (c *IdempotencyChecker) MarkCompleted(ctx context.Context, key string) error {
    return c.queries.UpdateProcessedMessageStatus(ctx, sqlc.UpdateProcessedMessageStatusParams{
        IdempotencyKey: key,
        Status:         "completed",
        CompletedAt:    sql.NullTime{Time: time.Now(), Valid: true},
    })
}

func (c *IdempotencyChecker) MarkFailed(ctx context.Context, key string, err error) error {
    return c.queries.UpdateProcessedMessageStatus(ctx, sqlc.UpdateProcessedMessageStatusParams{
        IdempotencyKey: key,
        Status:         "failed",
        Error:          sql.NullString{String: err.Error(), Valid: true},
    })
}
```

## 冪等性キーの生成戦略

### 1. デフォルト: メッセージID
最もシンプルな方法。メッセージIDが一意であれば機能します。

```go
func (h *Handler) IdempotencyKey(msg Message) (string, error) {
    return "", nil // 空文字列を返すとRegistryがmsg.ID()を使用
}
```

### 2. ビジネスキー: ドメイン固有の一意性
同じビジネスイベント（例: 同じユーザーの同じメールアドレスでの登録）を重複処理しない。

```go
func (h *UserCreatedHandler) IdempotencyKey(msg Message) (string, error) {
    var payload UserCreatedPayload
    json.Unmarshal(msg.Body(), &payload)

    // ユーザーID + メールアドレスで一意性を保証
    data := fmt.Sprintf("user.created:%s:%s", payload.UserID, payload.Email)
    hash := sha256.Sum256([]byte(data))
    return hex.EncodeToString(hash[:]), nil
}
```

### 3. リクエストID: 外部システムからの識別子
外部システムが付与したリクエストIDを使用。

```go
func (h *Handler) IdempotencyKey(msg Message) (string, error) {
    requestID := msg.Attributes()["request_id"]
    if requestID == "" {
        return "", nil // フォールバック: メッセージID
    }
    return requestID, nil
}
```

## TTL（有効期限）の設定

- **推奨値**: 24時間〜7日
- **理由**: リトライ間隔を考慮し、十分な期間を確保
- **クリーンアップ**: 定期的に `expires_at` が過去のレコードを削除

```sql
-- 有効期限切れレコードの削除（cronで定期実行）
DELETE FROM processed_messages
WHERE expires_at < NOW() - INTERVAL '7 days';
```
