# Common Server & Worker Rules

すべてのサーバーおよびワーカーコンポーネントは、以下の共通ルールに従って実装する必要があります。

## 1. Lifecycle Management

すべてのコンポーネントは、`pkg/lifecycle` パッケージの `Application` インターフェースを満たす必要があります。

```go
type Application interface {
    // Run はメインループを開始します。
    // contextがキャンセルされるまでブロックするか、エラーが発生した場合は即座に戻る必要があります。
    Run(ctx context.Context) error

    // Shutdown はリソースのクリーンアップと停止処理を行います。
    // 指定されたcontextのタイムアウト内に完了する必要があります。
    Shutdown(ctx context.Context) error
}
```

### 実装要件
- **Run**:
    - 起動ログを出力すること。
    - 致命的なエラーが発生した場合は即座にエラーを返すこと。
    - `context.Done()` を監視し、キャンセレーションを受け取ったら速やかに終了処理を開始すること（またはShutdownに任せる）。
- **Shutdown**:
    - 終了ログを出力すること。
    - 処理中のリクエストやジョブの完了を待機すること（Graceful Shutdown）。
    - データベース接続やファイルハンドルなどのリソースを解放すること。
    - タイムアウト（Context）を尊重し、期限内に終了できない場合は強制終了すること。

## 2. Observability

### Logging
- `log/slog` を使用して構造化ログを出力すること。
- コンテキスト（`ctx`）をロガーに渡し、トレースIDなどのメタデータを含めること。
- エラーログには必ず `error` 属性を含めること。

### Telemetry
- OpenTelemetry (`otel`) を使用してトレーシングを行うこと。
- 主要な操作（ハンドラー、ジョブ処理など）ごとにスパンを作成すること。
- エラー発生時は `span.RecordError(err)` を呼び出すこと。

## 3. Configuration
- 設定は構造体（Struct）で定義し、環境変数から読み込むこと（`internal/config` パッケージを使用）。
- ハードコードされた値（タイムアウト、リトライ回数、制限値など）を避け、設定可能にすること。

## 4. Graceful Shutdown 実装パターン

### HTTP Server の例

```go
// internal/infrastructure/http/server.go
type Server struct {
    server *http.Server
    logger *slog.Logger
}

func (s *Server) Run(ctx context.Context) error {
    s.logger.Info("starting HTTP server", slog.String("addr", s.server.Addr))

    errChan := make(chan error, 1)
    go func() {
        if err := s.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            errChan <- err
        }
    }()

    select {
    case err := <-errChan:
        return err
    case <-ctx.Done():
        return nil
    }
}

func (s *Server) Shutdown(ctx context.Context) error {
    s.logger.Info("shutting down HTTP server")
    return s.server.Shutdown(ctx) // 処理中のリクエストの完了を待機
}
```

### Queue Consumer の例

```go
// internal/infrastructure/queue/consumer/kafka.go
type KafkaConsumer struct {
    reader   *kafka.Reader
    handlers map[string]MessageHandler
    logger   *slog.Logger
}

func (c *KafkaConsumer) Start(ctx context.Context) error {
    c.logger.Info("starting Kafka consumer")

    for {
        select {
        case <-ctx.Done():
            return nil // シャットダウンシグナル受信
        default:
            msg, err := c.reader.ReadMessage(ctx)
            if err != nil {
                if ctx.Err() != nil {
                    return nil
                }
                c.logger.Error("failed to read message", slog.Any("error", err))
                continue
            }

            // メッセージ処理
            if err := c.handleMessage(ctx, msg); err != nil {
                c.logger.Error("failed to handle message", slog.Any("error", err))
            }
        }
    }
}

func (c *KafkaConsumer) Stop(ctx context.Context) error {
    c.logger.Info("stopping Kafka consumer")
    return c.reader.Close() // 接続を閉じる
}
```

