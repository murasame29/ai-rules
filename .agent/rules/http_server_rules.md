# HTTP Server Rules

HTTPサーバーの実装は、以下のルールに従う必要があります。

## 1. Routing & Handlers

- **Standard Library**: Go 1.22以降の `net/http.ServeMux` を使用すること。外部ルーターライブラリ（Chi, Gin, Echoなど）への依存は避けること。
- **Path Values**: パスパラメータの取得には `r.PathValue("key")` を使用すること。
- **Method Handling**: メソッドの制限は `ServeMux` のパターン（例: `POST /users`）で行うこと。

## 2. Request/Response

- **JSON**: リクエストおよびレスポンスのボディはJSONを基本とすること。
- **Problem Details**: エラーレスポンスは RFC 7807 (Problem Details for HTTP APIs) に準拠した `application/problem+json` 形式で返すこと。
- **Status Codes**: 適切なHTTPステータスコードを使用すること（200, 201, 400, 404, 500など）。

## 3. Middleware

以下のミドルウェアを適用すること：
- **Recovery**: パニックからの回復。
- **Logging**: リクエスト/レスポンスのログ記録。
- **Tracing**: OpenTelemetryによる分散トレーシング。
- **Metrics**: Prometheusメトリクスの収集。
- **CORS**: 必要に応じてCORSヘッダーの設定。

## 4. Health Checks

- `/livez`: Liveness Probe（サーバーが稼働しているか）。
- `/readyz`: Readiness Probe（トラフィックを受け入れ可能か、DB接続確認など）。

## 5. Pagination

- リスト取得系のAPIでは、必ずページネーション（`limit`, `offset` またはカーソル）をサポートすること。
- デフォルトの `limit` および `offset` は設定ファイル（環境変数）から読み込むこと。ハードコードしないこと。
