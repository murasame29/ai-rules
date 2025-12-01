# NATS Consumer Rules

NATS (JetStream) コンシューマーの実装は、以下のルールに従う必要があります。

## 1. JetStream

- **Persistence**: Core NATSではなく、必ず **JetStream** を使用してメッセージの永続化と信頼性を確保すること。
- **Stream/Consumer**: ストリームとコンシューマーの定義は、可能な限りIaC（Infrastructure as Code）で管理すること。アプリケーションコードでの自動生成は開発環境に留めることが望ましい。

## 2. Acknowledgement

- **Explicit Ack**: `AckPolicy` は `AckExplicit` を使用すること。
- **Ack/Nak**:
    - 処理成功時: `msg.Ack()` を呼び出す。
    - 処理失敗時（リトライ可能）: `msg.Nak()` を呼び出し、再送を要求する。
    - 処理失敗時（リトライ不可）: `msg.Term()` を呼び出し、再送を停止する。

## 3. Durability

- **Durable Consumer**: コンシューマーが再起動しても処理状況を引き継げるよう、`Durable` 名を設定すること。

## 4. Idempotency

- NATS JetStreamも重複配信の可能性があるため、アプリケーション側での冪等性チェック（Idempotency Check）は必須である。
- **Registry**: `Registry` パターンを使用し、メッセージハンドラーと冪等性チェックを共通化すること。詳細は [message_handler_pattern.md](file:///home/murasame29/murasame29/rules/message_handler_pattern.md) と [idempotency_pattern.md](file:///home/murasame29/murasame29/rules/idempotency_pattern.md) を参照。
