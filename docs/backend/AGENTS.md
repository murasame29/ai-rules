# Backend AGENTS.md

バックエンドサーバー実装に関するルールとパターンを定義します。

---

## 📚 目次

1. [Configuration Rules](#1-configuration-rules)
2. [Dependency Injection Rules](#2-dependency-injection-rules)
3. [Common Server Rules](#3-common-server-rules)
4. [HTTP Server Rules](#4-http-server-rules)
5. [Middleware Pattern](#5-middleware-pattern)
6. [RDB Handling Rules](#6-rdb-handling-rules)
7. [Message Handler & Idempotency](#7-message-handler--idempotency)
8. [Queue Consumers](#8-queue-consumers)
9. [WebSocket Rules](#9-websocket-rules)

---

## 1. Configuration Rules

- **Source**: 環境変数 (`github.com/caarlos0/env`)。`.env` もサポート。
- **Structure**: `internal/config/config.go` に定義。
- **Injection**: DIコンテナ経由で注入。グローバル変数は禁止。

```go
type Config struct {
    Port     int    `env:"PORT" envDefault:"8080"`
    LogLevel string `env:"LOG_LEVEL" envDefault:"info"`
}
```

---

## 2. Dependency Injection Rules

- **Library**: `go.uber.org/dig`
- **Pattern**: `New...` コンストラクタ定義
- **Definition**: `internal/container` パッケージに集約
- **Execution**: `main.go` で `Invoke`

```go
// コンストラクタパターン
func NewUserService(repo UserRepository) *UserService {
    return &UserService{repo: repo}
}

// コンテナ登録
container.Provide(NewUserService)
```

⚠️ Service Locatorパターンは禁止。

---

## 3. Common Server Rules

### Lifecycle
- `pkg/lifecycle.Application` インターフェースを実装
  - `Run(ctx context.Context) error`
  - `Shutdown(ctx context.Context) error`
- **Graceful Shutdown** を必須とする

### Observability
- OpenTelemetry (`otel`) でトレーシング
- エラー時は `span.RecordError(err)` を呼び出す

---

## 4. HTTP Server Rules

| 項目 | ルール |
|------|--------|
| Router | Go 1.22+ `net/http.ServeMux` |
| Response | JSON形式 |
| Error | RFC 7807 (Problem Details) |
| Health Check | `/livez`, `/readyz` |

### Middleware適用順序
Recovery → Logging → Tracing → Metrics → CORS → Handler

---

## 5. Middleware Pattern

```go
// 型定義
type Middleware func(http.Handler) http.Handler

// チェーン構築
handler := middleware.Chain(
    middleware.Recovery,
    middleware.Logging,
    middleware.Tracing,
)(finalHandler)
```

### 実行順序
```
Request → Recovery → Logging → Tracing → Handler
Response ← Recovery ← Logging ← Tracing ← Handler
```

---

## 6. RDB Handling Rules

| 項目 | ルール |
|------|--------|
| Driver | `pgx/v5` + `pgxpool` |
| Query | `sqlc` でGoコード自動生成 |
| Transaction | 複数更新時は必須 |
| Migration | `internal/infrastructure/database/postgres/schema` |

### Transaction伝播
```go
func (s *Service) CreateUser(ctx context.Context, user *User) error {
    return s.txManager.WithTx(ctx, func(ctx context.Context) error {
        // ctx経由でTxが伝播される
        return s.repo.Create(ctx, user)
    })
}
```

⚠️ 手書きSQLは避け、`sqlc` を使用すること。

---

## 7. Message Handler & Idempotency

### Message Handler Pattern

```go
type Message interface {
    ID() string
    Body() []byte
    Type() string
}

type MessageHandler interface {
    Handle(ctx context.Context, msg Message) error
    MessageType() string
}
```

- **Registry**: メッセージタイプごとにハンドラーを振り分け
- **Structure**: `internal/infrastructure/queue/handler/` に実装

### Idempotency (冪等性) Pattern

分散システムでは必須。

```go
type IdempotencyChecker interface {
    IsProcessed(ctx context.Context, key string) (bool, error)
    MarkProcessing(ctx context.Context, key string) error
    MarkCompleted(ctx context.Context, key string) error
}
```

- **Storage**: DB (`processed_messages` テーブル)
- **Key生成**: メッセージID、またはビジネスキーのハッシュ

---

## 8. Queue Consumers

### 共通ルール
- Registry & Idempotency を必ず併用すること

### SQS Consumer
- **Long Polling**: `WaitTimeSeconds > 0`
- **Delete**: 処理成功時のみ削除

### NATS JetStream Consumer
- **AckPolicy**: `Explicit`
- 成功時 `Ack`, 失敗時 `Nak`
- **Durable**: 再起動耐性を持たせる

### Kafka Consumer
- **GroupID**: 必須
- **Commit**: 処理完了後に明示的にコミット

---

## 9. WebSocket Rules

- **Library**: `github.com/coder/websocket`
- **Hub Pattern**: `Hub` が全接続を管理
- **Broadcasting**: Hub経由でNon-blockingに送信
- **Lifecycle**: HubもGraceful Shutdown対象

```go
type Hub struct {
    clients    map[*Client]bool
    broadcast  chan []byte
    register   chan *Client
    unregister chan *Client
}
```
