# Message Handler Pattern

メッセージキュー（SQS, NATS, Kafka）からのメッセージ処理は、**Registry パターン**を使用して統一的に扱います。

## コアインターフェース

### Message インターフェース
すべてのメッセージが実装すべきインターフェース：

```go
// internal/model/message.go
type Message interface {
    ID() string                      // メッセージID（一意）
    Type() string                    // メッセージタイプ（例: "user.created"）
    Body() []byte                    // メッセージ本体（JSON等）
    Attributes() map[string]string   // メタデータ
    Timestamp() time.Time            // 受信時刻
}
```

### MessageHandler インターフェース
各メッセージタイプのハンドラーが実装すべきインターフェース：

```go
// internal/model/message.go
type MessageHandler interface {
    Handle(ctx context.Context, msg Message) error  // メッセージ処理
    MessageType() string                            // 処理対象のメッセージタイプ
    IdempotencyKey(msg Message) (string, error)     // 冪等性キーの生成
}
```

## Registry パターン

### Registry の役割
- メッセージタイプに基づいてハンドラーをディスパッチ
- 冪等性チェックの共通化
- エラーハンドリングの統一

### Registry 実装例

```go
// internal/infrastructure/queue/handler/registry.go
type Registry struct {
    handlers           map[string]MessageHandler
    idempotencyChecker IdempotencyChecker
    logger             *slog.Logger
}

func (r *Registry) Register(handler MessageHandler) {
    r.handlers[handler.MessageType()] = handler
}

func (r *Registry) Handle(ctx context.Context, msg Message) error {
    // 1. ハンドラーを検索
    handler, exists := r.handlers[msg.Type()]
    if !exists {
        return fmt.Errorf("no handler for message type: %s", msg.Type())
    }

    // 2. 冪等性チェック
    key, _ := r.generateIdempotencyKey(handler, msg)
    if processed, _ := r.idempotencyChecker.IsProcessed(ctx, key); processed {
        return nil // 既に処理済み
    }

    // 3. 処理実行
    err := handler.Handle(ctx, msg)

    // 4. 結果を記録
    if err != nil {
        r.idempotencyChecker.MarkFailed(ctx, key, err)
    } else {
        r.idempotencyChecker.MarkCompleted(ctx, key)
    }

    return err
}
```

## ハンドラー実装例

```go
// internal/infrastructure/queue/handler/user_created.go
package handler

type UserCreatedHandler struct {
    service *user.Service
    logger  *slog.Logger
}

func NewUserCreatedHandler(service *user.Service, logger *slog.Logger) *UserCreatedHandler {
    return &UserCreatedHandler{
        service: service,
        logger:  logger,
    }
}

// Handle はメッセージを処理
func (h *UserCreatedHandler) Handle(ctx context.Context, msg model.Message) error {
    var payload model.UserCreatedPayload
    if err := json.Unmarshal(msg.Body(), &payload); err != nil {
        return fmt.Errorf("%w: invalid message format", model.ErrPermanent)
    }

    // Application層のServiceを呼び出す
    _, err := h.service.Create(ctx, model.CreateUserRequest{
        Name:  payload.Name,
        Email: payload.Email,
    })
    return err
}

// MessageType は処理対象のメッセージタイプを返す
func (h *UserCreatedHandler) MessageType() string {
    return "user.created"
}

// IdempotencyKey はカスタム冪等性キーを生成
func (h *UserCreatedHandler) IdempotencyKey(msg model.Message) (string, error) {
    var payload model.UserCreatedPayload
    if err := json.Unmarshal(msg.Body(), &payload); err != nil {
        return "", nil // パースエラー時はデフォルト（メッセージID）を使用
    }

    // ユーザーIDとメールアドレスで冪等性を保証
    data := fmt.Sprintf("user.created:%s:%s", payload.UserID, payload.Email)
    hash := sha256.Sum256([]byte(data))
    return hex.EncodeToString(hash[:]), nil
}
```

## Consumer への登録

```go
// internal/container/container.go (BuildWorker内)

// ハンドラーを作成
userCreatedHandler := queuehandler.NewUserCreatedHandler(userService, logger)
userUpdatedHandler := queuehandler.NewUserUpdatedHandler(userService, logger)

// Registryに登録
registry := queuehandler.NewRegistry(idempotencyChecker, logger)
registry.Register(userCreatedHandler)
registry.Register(userUpdatedHandler)

// ConsumerにRegistryを注入
consumer.RegisterHandler(registry)
```

## 新しいメッセージタイプの追加手順

1. **Payload定義** (`internal/model/job.go`)
2. **ハンドラー実装** (`internal/infrastructure/queue/handler/xxx_handler.go`)
3. **Registry登録** (`internal/container/container.go`)
