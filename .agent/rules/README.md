# Rules Documentation Index

このディレクトリには、プロジェクトのアーキテクチャとコーディング規約に関するすべてのルールが含まれています。

## 📚 ドキュメント一覧

### アーキテクチャ

- **[architecture_overview.md](architecture_overview.md)** - Clean Architectureの全体像、責任境界、マルチドメイン構成例（SNS）

### デザインパターン

- **[message_handler_pattern.md](message_handler_pattern.md)** - メッセージハンドラーとレジストリパターンの実装
- **[idempotency_pattern.md](idempotency_pattern.md)** - 冪等性チェックの実装パターン
- **[middleware_pattern.md](middleware_pattern.md)** - HTTPミドルウェアチェーンの実装

### 共通ルール

- **[common_server_rules.md](common_server_rules.md)** - すべてのサーバー/ワーカーに共通のルール（Lifecycle、Observability、Graceful Shutdown）
- **[golang_rules.md](golang_rules.md)** - Golangコーディング規約
- **[config_rules.md](config_rules.md)** - 設定管理と環境変数の扱い
- **[di_rules.md](di_rules.md)** - Dependency Injection（DI）のルール
- **[rdb_rules.md](rdb_rules.md)** - RDB（PostgreSQL）の取り扱い
- **[communication_rules.md](communication_rules.md)** - コミュニケーションに関するルール（言語設定など）

### コンポーネント別ルール

#### HTTP Server
- **[http_server_rules.md](http_server_rules.md)** - HTTPサーバーの実装ルール

#### Queue Consumers
- **[sqs_consumer_rules.md](sqs_consumer_rules.md)** - AWS SQSコンシューマーのルール
- **[nats_consumer_rules.md](nats_consumer_rules.md)** - NATS JetStreamコンシューマーのルール
- **[kafka_consumer_rules.md](kafka_consumer_rules.md)** - Apache Kafkaコンシューマーのルール

## 🚀 使い方

### 新規プロジェクト開始時
1. [architecture_overview.md](architecture_overview.md) でアーキテクチャの全体像を把握
2. [common_server_rules.md](common_server_rules.md) で共通ルールを確認
3. 必要なコンポーネント（HTTP, Queue）のルールを読む

### 新機能追加時
1. [architecture_overview.md](architecture_overview.md) でドメイン構成を確認
2. 該当する層（Model, Application, Infrastructure）のルールに従って実装

### 新しいメッセージハンドラー追加時
1. [message_handler_pattern.md](message_handler_pattern.md) でパターンを確認
2. [idempotency_pattern.md](idempotency_pattern.md) で冪等性キーの戦略を決定

## ✅ 自己チェックリスト

これらのドキュメントだけで、`template/` と同等のアーキテクチャのコードを書けますか？

- [ ] Clean Architectureの層と責任境界を理解している
- [ ] 新しいドメイン（例: Post, Follow）をどこに配置するか分かる
- [ ] HTTPハンドラーの実装方法が分かる
- [ ] ミドルウェアチェーンの構築方法が分かる
- [ ] メッセージハンドラーの実装と登録方法が分かる
- [ ] 冪等性チェックの実装方法が分かる
- [ ] DIコンテナへの登録方法が分かる
- [ ] Graceful Shutdownの実装方法が分かる

すべてにチェックが入れば、ドキュメントは完成です！
