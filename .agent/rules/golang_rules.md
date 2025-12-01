# Golang Coding Rules

Golangのコーディングにおいては、以下のルールに従ってください。

## 1. Project Structure

- **Standard Layout**: `cmd/` (エントリポイント), `internal/` (プライベートコード), `pkg/` (ライブラリコード) の構成を守ること。
- **Internal**: アプリケーション固有のビジネスロジックやインフラ実装は `internal/` 配下に配置し、外部からのインポートを防ぐこと。

## 2. Error Handling

- **Wrapping**: エラーを上位に返す際は、`fmt.Errorf("%w", err)` を使用してラップし、元のエラー情報を保持すること。
- **Checking**: エラーの判定には `errors.Is` または `errors.As` を使用すること。
- **Custom Errors**: ドメイン固有のエラー（例: `ErrNotFound`, `ErrValidation`）は `internal/model` などで定義し、センチネルエラーとして扱うこと。

## 3. Context

- **Propagation**: 関数やメソッドの第一引数には必ず `context.Context` を受け取ること（構造体のフィールドに保持しない）。
- **Cancellation**: 非同期処理やI/O操作を行う際は、必ずContextのキャンセレーション（`ctx.Done()`）を考慮すること。

## 4. Logging

- **Slog**: 標準ライブラリの `log/slog` を使用すること。
- **Structured**: ログメッセージは固定文字列とし、変数は属性（`slog.String`, `slog.Int` など）として渡すこと。
- **Context**: `logger.InfoContext(ctx, ...)` のように、Context付きのメソッドを使用し、トレースIDなどをログに含めること。

## 5. Testing

- **Table Driven**: テストケースが多い場合はテーブル駆動テストを採用すること。
- **Mocks**: インターフェースに依存させ、テスト時はモック（`gomock` や手書きのモック）を使用可能にすること。

## 6. Server Architecture

- **Separation**: サーバーの種類（HTTP, gRPC, WebSocket）ごとに独立したコマンド（`cmd/http`, `cmd/grpc`, `cmd/websocket`）を作成すること。
- **Integration**: 統合サーバー（`cmd/api`）はすべてのサーバーをまとめて起動するために使用すること。
- **Makefile**: 各サーバーの起動コマンド（`run-http`, `run-grpc`, `run-websocket`）をMakefileに定義すること。

## 7. Dependency Injection

- **Dig**: DIコンテナには `go.uber.org/dig` を使用すること。
- **Container Package**: DIロジックは `internal/container` パッケージに集約し、`BuildAPI` などのメソッドでプロバイダを登録すること。
- **Providers**: プロバイダは関数として定義し、依存関係を引数で受け取り、生成物を戻り値とすること。

## 8. WebSocket Implementation

- **Library**: `github.com/coder/websocket` を使用すること。
- **Structure**: `Hub`（接続管理）, `Handler`（HTTPアップグレードとルーティング）, `UserHandler`（ビジネスロジック）の構成をとること。
- **Protocol**: メッセージはJSON形式とし、`type`（コマンド/イベント名）と `payload`（データ）フィールドを持つこと。
  ```json
  { "type": "create_user", "payload": { ... } }
  ```
- **Broadcasting**: イベントは `Hub` を通じて全クライアントにブロードキャストすること。
- **Direct Response**: 操作の結果（成功/失敗）は、ブロードキャストの前に送信元クライアントへ直接返信すること。

## 9. Verification

- **Shell Scripts**: HTTP/gRPCの検証にはシェルスクリプト（`scripts/verify_http.sh`, `scripts/verify_grpc.sh`）を使用すること。
- **Go Scripts**: 複雑な検証（WebSocketなど）にはGoプログラム（`cmd/verify_ws/main.go`）を使用すること。
- **Tools**: gRPC検証には `grpcurl`、HTTP検証には `curl` を使用すること。

## 10. Middleware

- **Chain Pattern**: ミドルウェアは `func(http.Handler) http.Handler` のシグネチャを持ち、`middleware.Chain` パターンを使用して適用すること。
