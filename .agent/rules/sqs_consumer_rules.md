# SQS Consumer Rules

AWS SQS (Simple Queue Service) コンシューマーの実装は、以下のルールに従う必要があります。

## 1. Message Processing

- **Long Polling**: メッセージ受信時はロングポーリング（`WaitTimeSeconds > 0`）を使用し、APIコール数を削減すること。
- **Visibility Timeout**: メッセージ処理に時間がかかる場合は、可視性タイムアウトを適切に設定すること。処理中にタイムアウトしそうな場合は延長を検討すること。
- **Deletion**: メッセージ処理が成功した場合にのみ、明示的にメッセージを削除（`DeleteMessage`）すること。

## 2. Concurrency

- **Worker Pool**: `errgroup` やセマフォを使用して、並行処理数を制御すること（`WorkerCount` 設定）。
- **Graceful Shutdown**: シャットダウン時は、現在処理中のメッセージが完了するまで待機すること。新規メッセージの受信は停止すること。

## 3. Error Handling

- **DLQ (Dead Letter Queue)**: 処理に失敗し、リトライ回数を超えたメッセージはDLQに送られるよう、AWS側でRedrive Policyを設定すること。アプリケーション側ではエラーログを出力し、メッセージを削除しない（リトライさせる）こと。

## 4. Idempotency

- **Deduplication**: SQSは「At-Least-Once」配信であるため、同一メッセージが複数回届く可能性がある。必ずアプリケーション側で冪等性（Idempotency）を担保すること。
- **Registry**: `Registry` パターンを使用し、メッセージタイプごとのハンドラーと冪等性チェックを共通化すること。詳細は [message_handler_pattern.md](file:///home/murasame29/murasame29/rules/message_handler_pattern.md) と [idempotency_pattern.md](file:///home/murasame29/murasame29/rules/idempotency_pattern.md) を参照。
