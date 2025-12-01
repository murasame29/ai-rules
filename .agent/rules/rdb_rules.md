# RDB Handling Rules

リレーショナルデータベース（RDB）の取り扱いは、以下のルールに従ってください。

## 1. Driver & Connection

- **pgx**: PostgreSQLドライバとして `github.com/jackc/pgx/v5` を使用すること。
- **Connection Pool**: `pgxpool` を使用し、接続プールを管理すること。
- **Retry**: 接続確立時はリトライロジック（`pkg/retry`）を組み込み、データベースの起動待ちなどに対応すること。

## 2. Query Generation

- **sqlc**: SQLクエリは手書きせず、`sqlc` を使用してGoコードを自動生成すること。
- **Type Safety**: `sqlc` が生成する型安全なインターフェースを使用し、実行時エラーを防ぐこと。
- **Queries**: SQLファイルは `internal/infrastructure/database/postgres/queries` に配置し、機能ごとにファイルを分けること。

## 3. Transactions

- **Consistency**: 複数の更新操作を行う場合は必ずトランザクションを使用すること。
- **Context**: トランザクション内での操作には、トランザクションから生成されたContextまたはTxオブジェクトを確実に渡すこと。

## 4. Migrations

- **Schema**: データベーススキーマ定義（DDL）は `internal/infrastructure/database/postgres/schema` に配置し、バージョン管理すること。
- **Tools**: マイグレーションツール（`golang-migrate` や `tern` など）を使用して適用可能な状態にすること。
