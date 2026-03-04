---
inclusion: fileMatch
fileMatchPattern: ["**/*.go"]
description: "Golangのコーディングルール。Stack、命名規則、パッケージ構成、エラーハンドリング、HTTP handler、DB、DI、テスト、Observability実装。"
---

# Golang Coding Rules

Goのコーディングにおいては、以下のルールに従うこと。

## 1. Stack

- Go 1.25+
- HTTP Router: `net/http.ServeMux`（外部ルーターライブラリは使用しない）
- DI: `go.uber.org/dig`
- DB Driver: `github.com/jackc/pgx/v5` + `pgxpool`
- SQL Code Gen: `sqlc`
- Config: `github.com/caarlos0/env` + `github.com/joho/godotenv`
- Logging: `log/slog`
- Tracing: OpenTelemetry
- WebSocket: `github.com/coder/websocket`

## 2. Naming Convention

- パッケージ名: 小文字、単数形、短く（`user`, `config`, `middleware`）。アンダースコアやキャメルケースは使わない
- ファイル名: スネークケース（`user_handler.go`, `error_response.go`）
- エクスポートされる型/関数: PascalCase
- 非エクスポート: camelCase
- インターフェース: 単一メソッドの場合は `-er` サフィックス（`Reader`, `Writer`）。複数メソッドの場合は役割を表す名前（`UserRepository`）
- コンストラクタ: `New` プレフィックス（`NewServer`, `NewUserService`）
- レシーバ名: 型名の1〜2文字の略称（`s` for `Server`, `us` for `UserService`）。`this` や `self` は使わない

## 3. Package Structure

Clean Architecture の原則は `architecture-philosophy.md` を参照。ここでは Go プロジェクトの具体的なディレクトリ構成を定義する。

```
cmd/
├── http/main.go          # HTTPサーバーエントリポイント
├── grpc/main.go          # gRPCサーバーエントリポイント
└── api/main.go           # 統合サーバー
internal/
├── model/                # Domain Model 層: エンティティ・インターフェース（標準ライブラリのみ依存可）
├── application/          # Application 層: ユースケース（model のみに依存）
│   └── {domain}/service.go
├── infrastructure/       # Infrastructure 層: 外部技術実装
│   ├── http/
│   │   ├── handler/
│   │   └── server.go
│   ├── database/postgres/
│   │   ├── queries/      # sqlcクエリ
│   │   └── schema/       # マイグレーション
│   └── queue/
├── config/config.go      # 設定構造体
└── container/            # DIコンテナ
pkg/
├── lifecycle/            # Application interface (Run/Shutdown)
└── middleware/            # HTTPミドルウェア
```

## 4. Interface Design

- インターフェースは使う側（consumer）で定義する。実装側で定義しない
- 小さく保つ。1〜3メソッドが理想
- `internal/model` にドメインの Repository interface を定義し、`infrastructure` で実装する
- 暗黙的な実装（implicit satisfaction）を活用する。コンパイル時チェックには `var _ Interface = (*Impl)(nil)` を使う

```go
// internal/model/user.go
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
}
```

## 5. Error Handling

- エラーを返す際は `fmt.Errorf("operation failed: %w", err)` でラップし、コンテキストを付与する
- エラー判定には `errors.Is` / `errors.As` を使用する
- センチネルエラーは `internal/model/error.go` に定義する（`ErrNotFound`, `ErrDuplicate`, `ErrValidation` など）
- パニックは使わない。エラーを返す。Recovery middleware でのみ捕捉する
- エラーのログ出力は呼び出し元の最上位（handler / worker）で行う。途中の層ではラップして返すだけ（実装例は §14 エラーログを参照）

```go
// Good: ラップして返すだけ
func (s *Service) Do(ctx context.Context) error {
    err := s.repo.Find(ctx)
    if err != nil {
        return fmt.Errorf("service.Do: %w", err)
    }
}
```

## 6. Context Usage

- 関数/メソッドの第一引数に `context.Context` を渡す。構造体フィールドに保持しない
- 非同期処理・I/O操作では `ctx.Done()` を監視してキャンセレーションに対応する
- `context.WithValue` はトレースID等の横断的関心事のみに使用する。ビジネスデータの受け渡しには使わない
- タイムアウトが必要な操作には `context.WithTimeout` / `context.WithDeadline` を設定する

## 7. Concurrency Pattern

- goroutine の起動時は必ずライフサイクルを管理する（`errgroup`, `sync.WaitGroup`, `context` cancellation）
- 野良 goroutine（起動したまま管理しない）は禁止
- チャネルは作成した側が close する
- `sync.Mutex` よりチャネルベースの設計を優先する。ただし単純な排他制御には Mutex で良い
- `errgroup.Group` を使って複数の goroutine のエラーハンドリングとキャンセレーションを統合する

```go
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error { return server.Run(ctx) })
g.Go(func() error { return consumer.Start(ctx) })
if err := g.Wait(); err != nil {
    return fmt.Errorf("component failed: %w", err)
}
```

## 8. HTTP Handler

### Routing
- `net/http.ServeMux` を使用。パスパラメータは `r.PathValue("key")` で取得
- メソッド制限は ServeMux パターンで行う（`POST /users`, `GET /users/{id}`）

### Request / Response
- JSON を基本とする
- エラーレスポンスは RFC 7807 Problem Details (`application/problem+json`) に準拠（API 設計の原則は `system-design-patterns.md` を参照）
- 適切な HTTP ステータスコードを返す

### Middleware
`func(http.Handler) http.Handler` シグネチャで実装し、`middleware.Chain` で適用する。
適用順序: Recovery → RequestID → Logging → Tracing → Metrics → CORS → Handler

### Health Check
- `/livez`: Liveness Probe
- `/readyz`: Readiness Probe（DB接続確認等）

### Pagination
- リスト系APIはページネーションを必須とする（詳細は `system-design-patterns.md` API 設計を参照）
- デフォルト値は環境変数から読み込む

### Lifecycle
Graceful Shutdown の原則は `system-design-patterns.md` を参照。Go では `pkg/lifecycle.Application` interface を実装する:

```go
type Application interface {
    Run(ctx context.Context) error
    Shutdown(ctx context.Context) error
}
```

## 9. Database Access

- PostgreSQL ドライバ: `pgx/v5` + `pgxpool`（接続プール）
- 接続確立時はリトライロジックを組み込む
- SQL コード生成: `sqlc` を使用。手書きクエリは避ける
- クエリファイル: `internal/infrastructure/database/postgres/queries/` に機能ごとに配置
- スキーマ: `internal/infrastructure/database/postgres/schema/` にバージョン管理
- 複数更新操作は必ずトランザクションを使用する
- マイグレーションツール: `golang-migrate` / `tern`（マイグレーション戦略は `system-design-patterns.md` を参照）

## 10. Configuration Management

設定管理の原則は `architecture-philosophy.md` を参照。ここでは Go 固有の実装を定義する。

- `github.com/caarlos0/env` で構造体タグにマッピング
- 開発環境では `.env` ファイル（`godotenv`）をサポート
- 設定構造体は `internal/config/config.go` に定義し、機能ごとにグルーピング（`ServerConfig`, `DatabaseConfig` 等）
- `env` タグで環境変数名を明示、`envDefault` で安全なデフォルト値を提供
- 設定は DI コンテナ経由で注入。グローバル変数は使わない
- 読み込み時に必須項目のバリデーションを行う

## 11. Dependency Injection

- `go.uber.org/dig` を使用
- DI ロジックは `internal/container` パッケージに集約
- 各コンポーネントは `New...` コンストラクタで依存を引数に受け取り、interface またはポインタを返す
- `BuildAPI`, `BuildWorker` のように役割ごとにプロバイダ登録を関数化
- `Invoke` は `main.go` でのみ使用。ビジネスロジック内で DI コンテナを直接参照しない（Service Locator 禁止）

## 12. Validation

- 入力バリデーションは `application` 層（Service）で行う
- 構造体タグベースのバリデーションライブラリ（`go-playground/validator` 等）は使用可。ただしドメインルールのバリデーションは手動で実装する
- バリデーションエラーは `ErrValidation` をラップして返し、handler 層で 400 系レスポンスに変換する
- DB 制約（UNIQUE 等）に依存したバリデーションは避ける。アプリケーション層で事前チェックする

## 13. Test

テストの基本哲学・原則は `testing-philosophy.md` を参照。ここでは Go 固有の実装パターンを定義する。

### テスト構成

- テストファイルは対象ファイルと同じパッケージに配置（`service.go` → `service_test.go`）
- テスト関数名: `Test{型名}_{メソッド名}` でテーブル駆動のサブテストに分ける
- テストヘルパーには必ず `t.Helper()` を付与する
- `testdata/` ディレクトリにテスト用のフィクスチャファイルを配置する（Go toolchain が自動で無視する）

### テストサイズの分離

- Small テスト: ビルドタグ不要。`go test ./...` で実行される
- Medium / Large テスト: `//go:build integration` タグで分離する
- CI では `go test ./...`（Small）と `go test -tags=integration ./...`（Medium以上）を分けて実行する

### テーブル駆動テスト

Go のテストの基本形。サブテスト名は日本語でも良い。

```go
func TestUserService_Create(t *testing.T) {
    tests := []struct {
        name    string
        input   *model.CreateUserRequest
        setup   func(repo *MockUserRepository)
        wantErr error
    }{
        {
            name:  "正常にユーザーが作成される",
            input: &model.CreateUserRequest{Name: "test"},
            setup: func(repo *MockUserRepository) {
                repo.EXPECT().Create(gomock.Any(), gomock.Any()).Return(nil)
            },
            wantErr: nil,
        },
        {
            name:  "重複ユーザーでエラー",
            input: &model.CreateUserRequest{Name: "existing"},
            setup: func(repo *MockUserRepository) {
                repo.EXPECT().Create(gomock.Any(), gomock.Any()).Return(model.ErrDuplicate)
            },
            wantErr: model.ErrDuplicate,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            ctrl := gomock.NewController(t)
            repo := NewMockUserRepository(ctrl)
            tt.setup(repo)
            svc := NewUserService(repo)

            // Act
            err := svc.Create(context.Background(), tt.input)

            // Assert
            if !errors.Is(err, tt.wantErr) {
                t.Errorf("got %v, want %v", err, tt.wantErr)
            }
        })
    }
}
```

### テストダブルの実装

- `gomock`（`go.uber.org/mock`）を使用してインターフェースからモックを生成する
- `//go:generate mockgen` ディレクティブをインターフェース定義の近くに配置する
- 手書きの Fake が有効なケース: Repository の Fake をインメモリ map で実装し、複数テストで再利用する

```go
// internal/model/user.go
//go:generate mockgen -source=user.go -destination=mock_user_test.go -package=model

type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
}
```

```go
// Fake の例: テスト用インメモリ Repository
type FakeUserRepository struct {
    users map[string]*model.User
}

func NewFakeUserRepository() *FakeUserRepository {
    return &FakeUserRepository{users: make(map[string]*model.User)}
}

func (r *FakeUserRepository) FindByID(_ context.Context, id string) (*model.User, error) {
    u, ok := r.users[id]
    if !ok {
        return nil, model.ErrNotFound
    }
    return u, nil
}

func (r *FakeUserRepository) Create(_ context.Context, user *model.User) error {
    if _, exists := r.users[user.ID]; exists {
        return model.ErrDuplicate
    }
    r.users[user.ID] = user
    return nil
}
```

### Go 固有のテストパターン

#### t.Cleanup でリソース解放
`defer` の代わりに `t.Cleanup` を使うと、サブテストのスコープで確実にクリーンアップされる。

```go
func setupTestDB(t *testing.T) *pgxpool.Pool {
    t.Helper()
    pool, err := pgxpool.New(context.Background(), os.Getenv("TEST_DATABASE_URL"))
    require.NoError(t, err)
    t.Cleanup(func() { pool.Close() })
    return pool
}
```

#### t.Parallel で並列実行
独立したテストは `t.Parallel()` で並列実行し、フィードバック速度を上げる。ただしテーブル駆動テストではループ変数のキャプチャに注意（Go 1.22+ では不要）。

```go
func TestUserService_FindByID(t *testing.T) {
    t.Parallel()
    tests := []struct { /* ... */ }{}
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            // ...
        })
    }
}
```

#### 時刻に依存するテスト
`time.Now()` を直接呼ばず、インターフェースまたは関数型で注入する。

```go
// 関数型で注入
type NowFunc func() time.Time

type Service struct {
    now NowFunc
}

// テスト時
svc := &Service{now: func() time.Time { return time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC) }}
```

#### エラーの検証
`errors.Is` / `errors.As` を使い、エラーの型や値を正確に検証する。文字列比較は避ける。

```go
// Good
if !errors.Is(err, model.ErrNotFound) {
    t.Errorf("expected ErrNotFound, got %v", err)
}

// Bad
if err.Error() != "not found" {
    t.Errorf("unexpected error: %v", err)
}
```

### カバレッジ目標

- application 層: 80% 以上
- infrastructure 層: integration test でカバー
- `go test -cover ./internal/application/...` で定期的に確認する

## 14. Log & Observability

Observability の基本原則・属性命名は `observability-philosophy.md` を参照。ここでは Go 固有の実装を定義する。

### Logging（slog）

`log/slog` を使用する。サードパーティロガー（zap, zerolog 等）は使わない。

```go
// slog の初期化（JSON ハンドラー）
handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
})
logger := slog.New(handler)
slog.SetDefault(logger)
```

#### 属性の渡し方

メッセージは固定文字列。変数は `slog.Attr` で渡す。`fmt.Sprintf` でメッセージに埋め込まない。

```go
// Good: 属性として渡す（NewRelic/Datadog で自動パースされる）
slog.InfoContext(ctx, "request completed",
    slog.String("http.request.method", r.Method),
    slog.String("http.route", "/api/v1/users/{id}"),
    slog.Int("http.response.status_code", status),
    slog.Float64("duration_ms", elapsed.Seconds()*1000),
    slog.String("user.id", userID),
)

// Bad: メッセージに変数を埋め込む
slog.Info(fmt.Sprintf("request %s %s completed in %dms", r.Method, r.URL.Path, elapsed))
```

#### Context 付きログ

必ず `InfoContext`, `ErrorContext` 等の Context 付きメソッドを使う。
カスタム slog.Handler で Context から trace_id / span_id を自動抽出する。

```go
// pkg/logging/handler.go — trace_id を自動付与するハンドラー
type TraceHandler struct {
    inner slog.Handler
}

func (h *TraceHandler) Handle(ctx context.Context, r slog.Record) error {
    span := trace.SpanFromContext(ctx)
    if span.SpanContext().IsValid() {
        r.AddAttrs(
            slog.String("trace_id", span.SpanContext().TraceID().String()),
            slog.String("span_id", span.SpanContext().SpanID().String()),
        )
    }
    return h.inner.Handle(ctx, r)
}
```

#### エラーログ

エラーログは handler / worker の最上位でのみ出力する。途中の層ではラップして返すだけ。

```go
// handler 層: ここでログ出力
func (h *UserHandler) Get(w http.ResponseWriter, r *http.Request) {
    user, err := h.service.FindByID(r.Context(), r.PathValue("id"))
    if err != nil {
        slog.ErrorContext(r.Context(), "failed to get user",
            slog.String("error.type", fmt.Sprintf("%T", err)),
            slog.String("error.message", err.Error()),
            slog.String("user.id", r.PathValue("id")),
        )
        // エラーレスポンスを返す
        return
    }
}

// service 層: ラップして返すだけ（ログ出力しない）
func (s *UserService) FindByID(ctx context.Context, id string) (*model.User, error) {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("UserService.FindByID: %w", err)
    }
    return user, nil
}
```

### Tracing（OpenTelemetry）

```go
// スパンの作成
func (s *UserService) Create(ctx context.Context, req *model.CreateUserRequest) (*model.User, error) {
    ctx, span := s.tracer.Start(ctx, "user.Service.Create")
    defer span.End()

    // 業務属性をスパンに設定
    span.SetAttributes(attribute.String("user.name", req.Name))

    user, err := s.repo.Create(ctx, req)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return nil, fmt.Errorf("UserService.Create: %w", err)
    }

    return user, nil
}
```

- `tracer` は DI で注入する（`otel.Tracer("service-name")`）
- HTTP middleware で自動的にサーバースパンを作成する（`otelhttp`）
- DB スパンは `pgx` の tracer hook で自動作成する

### Metrics（Prometheus）

```go
// HTTP middleware でリクエストメトリクスを自動収集
// otelhttp.NewHandler を使用するか、カスタム middleware で Prometheus メトリクスを記録する

var (
    httpRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name:    "http_server_request_duration_seconds",
        Help:    "HTTP request duration in seconds",
        Buckets: prometheus.DefBuckets,
    }, []string{"method", "route", "status_code"})
)
```

- `/metrics` エンドポイントで Prometheus 形式でエクスポートする
- ラベルのカーディナリティルールは `observability-philosophy.md` を参照

## 15. Linting & Formatting

- `gofmt` / `goimports` でフォーマット統一
- `golangci-lint` を CI で実行
- 推奨 linter: `errcheck`, `govet`, `staticcheck`, `unused`, `gosimple`, `ineffassign`, `misspell`
- `//nolint` コメントを使う場合は理由を併記する（`//nolint:errcheck // fire-and-forget`）
