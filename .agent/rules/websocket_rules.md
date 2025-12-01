---
trigger: always_on
---

# WebSocket Rules

WebSocketの実装は、以下のルールに従ってください。

## 1. Hub Pattern

- **Hub**: すべてのWebSocket接続を管理する中央ハブを実装すること。
- **Client**: 各WebSocket接続をClientとして表現し、送信チャネル（`Send chan []byte`）を持たせること。

## 2. Lifecycle Management

- **Hub as Application**: HubはサーバードライバーＨＡＮＤＬＥＲライフサイクル管理対象として実装し、`Run(ctx)` と `Shutdown(ctx)` を提供すること。
- **Graceful Shutdown**: シャットダウン時にすべてのクライアント接続を閉じること。

## 3. Connection Management

### Library
- **coder/websocket**: `github.com/coder/websocket` を使用すること（よりアクティブにメンテナンスされている）。
- **Origin Check**: 本番環境では適切なオリジンチェック（CORS）を実装すること。`AcceptOptions`で`InsecureSkipVerify`を`false`に設定すること。

### Read/Write Pumps
- **readPump**: WebSocketからメッセージを読み取り、処理するgoroutine。
- **writePump**: Hubからのブロードキャストをクライアントに送信するgoroutine。
- **Ping/Pong**: 定期的にPingを送信し、接続の生存確認を行うこと（推奨: 54秒間隔）。

## 4. Message Broadcasting

- **Hub経由**: メッセージのブロードキャストはHub経由で行うこと。
- **Non-blocking**: クライアントの送信チャネルがフルの場合、ブロックせずに接続を閉じること。

## 5. Integration with Application Layer

- **Service Reuse**: 既存のApplication層（Service）を再利用すること。
- **Event Broadcasting**: ユーザーイベント（作成、更新、削除など）をWebSocketでブロードキャストする場合、ハンドラーから`BroadcastUserEvent`を呼び出すこと。

## 実装例

### 接続URL
```
ws://localhost:8080/ws
```

### メッセージフォーマット (JSON)

#### クライアント → サーバー
```json
{
  "command": "list_users"
}
```

#### サーバー → クライアント
```json
{
  "type": "user_list",
  "users": [...]
}
```

```json
{
  "type": "user_created",
  "data": { "id": "...", "name": "...", "email": "..." }
}
```

## セキュリティ

- **認証**: 本番環境ではトークンベースの認証を実装すること。
- **レート制限**: 過度にメッセージを送信するクライアントを制限すること。
- **入力検証**: クライアントからのメッセージは必ずバリデーションを行うこと。
