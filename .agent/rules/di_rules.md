# Dependency Injection Rules

依存性の注入（DI）に関しては、以下のルールに従ってください。

## 1. Library

- **Uber Dig**: DIコンテナとして `go.uber.org/dig` を使用すること。
- **Container Package**: DIの定義は `internal/container` パッケージに集約すること。

## 2. Implementation Pattern

- **Constructors**: 各コンポーネントは `New...` というコンストラクタ関数を提供し、依存関係を引数で受け取り、インターフェースまたは構造体のポインタを返すこと。
- **Providers**: `container.go` 内で、コンストラクタを `dig.Container.Provide` に登録すること。
- **Grouping**: `BuildAPI`, `BuildWorker` のように、アプリケーションの役割ごとにプロバイダーの登録処理を関数化して整理すること。

## 3. Invocation

- **Invoke**: アプリケーションの起動ポイント（`main.go`）でのみ `dig.Container.Invoke` を使用し、ルートとなるコンポーネント（サーバーやワーカー）を取り出すこと。
- **Avoid Service Locator**: ビジネスロジック内でDIコンテナを直接参照（Service Locatorパターン）しないこと。必ずコンストラクタインジェクションを使用すること。
