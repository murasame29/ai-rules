# Antigravity ルール

このファイルは、AIエージェント "Antigravity" がこのプロジェクトで作業する際に遵守すべきルールを定義します。`.agent/rules/` ディレクトリ内の詳細なルールファイルに基づいています。

参照すべきルールファイル:
- `README.md`: ルール全体の概要
- `architecture_overview.md`: アーキテクチャ概要
- `common_server_rules.md`: サーバー共通ルール
- `communication_rules.md`: コミュニケーションルール
- `config_rules.md`: 設定ルール
- `di_rules.md`: DI (Dependency Injection) ルール
- `golang_rules.md`: Go言語コーディング規約
- `http_server_rules.md`: HTTPサーバルール
- `idempotency_pattern.md`: 冪等性パターン
- `kafka_consumer_rules.md`: Kafka Consumer ルール
- `message_handler_pattern.md`: メッセージハンドラパターン
- `middleware_pattern.md`: ミドルウェアパターン
- `nats_consumer_rules.md`: NATS Consumer ルール
- `rdb_rules.md`: RDB (PostgreSQL) ルール
- `sqs_consumer_rules.md`: SQS Consumer ルール
- `websocket_rules.md`: WebSocket ルール

- **自然言語**: すべてのドキュメント、コードコメント、コミットメッセージ、およびユーザーとの対話（計画、説明など）は **日本語** で行ってください。
- **コード**: 変数名、関数名、型名、パッケージ名などの識別子は **英語** を使用してください。
- **技術用語**: 一般的な技術用語（例: Worker, SQS, HTTP）は英語のまま使用し、必要に応じて日本語の説明を加えてください。

## 2. Golang コーディング標準

### 2.1 基本原則
- **可読性優先**: パフォーマンスよりも可読性と保守性を優先してください。
- **構造化ログ**: `log` パッケージや `fmt.Printf` ではなく、必ず `log/slog` を使用してください。
- **コンテキスト伝播**: `context.Context` を第一引数として渡し、ロガーやトレーシング情報を伝播させてください。
- **Panic禁止**: `panic` は使用せず、必ず `error` を返してください。

### 2.2 命名規則
- **パッケージ名**: 小文字1単語（例: `user`, `auth`）。
- **関数名**: `CreateUser` ではなく `Create` のように、パッケージ名と重複しないようにしてください（呼び出し側で `user.Create` となるため）。
- **型定義**: `interface{}` は使用せず、`any` を使用してください。

### 2.3 エラーハンドリング
- **ラップ**: `fmt.Errorf("failed to ...: %w", err)` を使用してエラーをラップし、コンテキストを追加してください。
- **判定**: `errors.Is` や `errors.As` を使用してエラーを判定してください。
- **独自エラー**: 共通のエラー定義は `internal/model/error.go` などを参照・作成してください。

### 2.4 テスト
- **テーブル駆動テスト**: テストケースを構造体のスライスとして定義し、ループで実行する形式を採用してください。
- **サブテスト**: `t.Run` を使用して各テストケースを実行してください。

### 2.5 プロジェクト構造
- **cmd/**: エントリーポイント（`main.go`）。ロジックは含めず、`run()` 関数を呼び出すだけにしてください。
- **internal/**: 外部からインポートされない内部パッケージ。
    - **model/**: ドメインとアプリケーション層で共有されるデータ構造。
    - **domain/**: ビジネスロジック。
    - **application/**: ユースケース。
    - **infrastructure/**: 外部依存の実装。
- **pkg/**: 外部公開可能なライブラリ。

## 3. アーキテクチャとパターン

### 3.1 main関数のパターン
- `main` 関数は `os.Exit(run())` のみを呼び出し、`run() int` 関数内でアプリケーションの初期化と実行を行ってください。
- `run` 関数は終了コード（0: 正常, 1: エラー）を返してください。

### 3.2 HTTPサーバー
- **RFC 9457**: エラーレスポンスには RFC 9457 (Problem Details) に準拠した形式を使用してください。
- **Graceful Shutdown**: サーバーは必ずグレースフルシャットダウンを実装してください。

### 3.3 ロギング
- ログレベルを適切に使い分けてください：
    - **Info**: 正常な操作（404, 400エラー含む）。
    - **Warn**: 注意が必要な操作（401, 403, 409, 429エラーなど）。
    - **Error**: システムエラー（500系エラー、DB接続失敗など）。

## 4. ドキュメント作成

- **README.md**: プロジェクトの概要、セットアップ方法、使い方を日本語で記述してください。
- **成果物**: `implementation_plan.md` や `task.md` などのアーティファクトもすべて日本語で記述してください。
