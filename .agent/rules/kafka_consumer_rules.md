# Kafka Consumer Rules

Apache Kafka コンシューマーの実装は、以下のルールに従う必要があります。

## 1. Consumer Group

- **Group ID**: スケーラビリティ確保のため、必ずコンシューマーグループ（`GroupID`）を設定すること。
- **Rebalancing**: リバランス発生時の挙動を理解し、適切にハンドリングすること（`segmentio/kafka-go` などのライブラリが抽象化している場合も意識する）。

## 2. Offset Management

- **Start Offset**: 新規コンシューマーグループの開始オフセット（`StartOffset`）は、**設定ファイル（環境変数）から変更可能にすること**。
    - デフォルトは `FirstOffset`（最も古いメッセージから）とし、読み飛ばしを防ぐこと。
    - 必要に応じて `LastOffset`（最新のみ）を選択できるようにする。
- **Commit**: メッセージ処理完了後にオフセットをコミットすること。自動コミット（Auto Commit）を使用する場合は、処理失敗時の挙動に注意すること（処理前にコミットされるとデータロストになる）。明示的なコミットが推奨される。

## 3. Batch Processing

- **Min/Max Bytes**: スループット向上のため、`MinBytes` と `MaxBytes` を適切に設定し、バッチ受信を活用すること。

## 4. Idempotency

- Kafkaも「At-Least-Once」配信が基本であるため、アプリケーション側での冪等性チェック（Idempotency Check）は必須である。
- **Registry**: `Registry` パターンを使用し、メッセージハンドラーと冪等性チェックを共通化すること。詳細は [message_handler_pattern.md](file:///home/murasame29/murasame29/rules/message_handler_pattern.md) と [idempotency_pattern.md](file:///home/murasame29/murasame29/rules/idempotency_pattern.md) を参照。
