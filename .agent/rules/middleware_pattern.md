# Middleware Pattern

HTTPサーバーでは、横断的関心事（Logging, Tracing, Metrics, Recovery など）を**ミドルウェア**として実装します。

## Middleware 型定義

```go
// pkg/middleware/chain.go
type Middleware func(http.Handler) http.Handler
```

## Middleware の実装例

### 1. Logging Middleware

```go
// pkg/middleware/logging.go
package middleware

func Logging(logger *slog.Logger) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()

            // レスポンスをキャプチャするためのラッパー
            wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

            // 次のハンドラーを実行
            next.ServeHTTP(wrapped, r)

            // ログ出力
            logger.InfoContext(r.Context(), "request handled",
                slog.String("method", r.Method),
                slog.String("path", r.URL.Path),
                slog.Int("status", wrapped.statusCode),
                slog.Duration("duration", time.Since(start)),
            )
        })
    }
}

type responseWriter struct {
    http.ResponseWriter
    statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.statusCode = code
    rw.ResponseWriter.WriteHeader(code)
}
```

### 2. Recovery Middleware

```go
// pkg/middleware/recovery.go
package middleware

func Recovery(logger *slog.Logger) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            defer func() {
                if err := recover(); err != nil {
                    logger.ErrorContext(r.Context(), "panic recovered",
                        slog.Any("error", err),
                        slog.String("stack", string(debug.Stack())),
                    )

                    w.Header().Set("Content-Type", "application/json")
                    w.WriteHeader(http.StatusInternalServerError)
                    json.NewEncoder(w).Encode(map[string]string{
                        "error": "internal server error",
                    })
                }
            }()

            next.ServeHTTP(w, r)
        })
    }
}
```

### 3. Tracing Middleware

```go
// pkg/middleware/tracing.go
package middleware

func Tracing(tracer trace.Tracer) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            ctx, span := tracer.Start(r.Context(), r.Method+" "+r.URL.Path)
            defer span.End()

            span.SetAttributes(
                attribute.String("http.method", r.Method),
                attribute.String("http.url", r.URL.String()),
            )

            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

### 4. Request ID Middleware

```go
// pkg/middleware/request_id.go
package middleware

const RequestIDHeader = "X-Request-ID"

func RequestID() Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            requestID := r.Header.Get(RequestIDHeader)
            if requestID == "" {
                requestID = uuid.New().String()
            }

            // ヘッダーに設定
            w.Header().Set(RequestIDHeader, requestID)

            // Contextに保存
            ctx := context.WithValue(r.Context(), "request_id", requestID)

            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

## Middleware Chain の構築

```go
// pkg/middleware/chain.go
package middleware

func Chain(middlewares ...Middleware) Middleware {
    return func(handler http.Handler) http.Handler {
        // 逆順で適用（最初のミドルウェアが最も外側）
        for i := len(middlewares) - 1; i >= 0; i-- {
            handler = middlewares[i](handler)
        }
        return handler
    }
}
```

## Server での使用例

```go
// internal/infrastructure/http/server.go
package http

func NewServer(cfg ServerParams, handler *v1.UserHandler, logger *slog.Logger, tracer trace.Tracer) *Server {
    mux := http.NewServeMux()

    // ルート登録
    mux.HandleFunc("POST /api/v1/users", handler.Create)
    mux.HandleFunc("GET /api/v1/users/{id}", handler.Get)

    // ミドルウェアチェーンを構築
    middlewareChain := middleware.Chain(
        middleware.Recovery(logger),      // 1. パニックからの回復（最も外側）
        middleware.RequestID(),            // 2. リクエストID付与
        middleware.Logging(logger),        // 3. ログ記録
        middleware.Tracing(tracer),        // 4. トレーシング
        middleware.Metrics(),              // 5. メトリクス収集
        middleware.CORS(),                 // 6. CORS設定
    )

    // チェーンを適用
    handler := middlewareChain(mux)

    server := &http.Server{
        Addr:    ":" + cfg.Port,
        Handler: handler,
    }

    return &Server{server: server, logger: logger}
}
```

## ミドルウェアの実行順序

```
Request
  ↓
Recovery (パニック捕捉)
  ↓
RequestID (ID付与)
  ↓
Logging (リクエスト記録)
  ↓
Tracing (スパン開始)
  ↓
Metrics (メトリクス記録)
  ↓
CORS (ヘッダー設定)
  ↓
Handler (ビジネスロジック)
  ↓
CORS ←
  ↓
Metrics ←
  ↓
Tracing ← (スパン終了)
  ↓
Logging ← (レスポンス記録)
  ↓
RequestID ←
  ↓
Recovery ←
  ↓
Response
```

## 新しいミドルウェアの追加

1. `pkg/middleware` に実装
2. `Middleware` 型に準拠
3. `Chain()` に追加
