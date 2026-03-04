---
inclusion: auto
description: "言語非依存のObservability原則。OTel Semantic Conventionsに準拠したLog/Trace/Metricsの属性命名、構造化ログ、NewRelic/Datadog対応。"
---

# Observability Philosophy

言語非依存の Observability 原則。Log / Trace / Metrics の出し方を統一する。
OpenTelemetry Semantic Conventions を基準とし、NewRelic・Datadog で正しくパースされる構造化を行う。

## 三本柱の役割

| シグナル | 目的 | 問いに答える |
|----------|------|-------------|
| Log | イベントの詳細記録 | 何が起きたか？ |
| Trace | リクエストの因果関係 | どこで遅い／失敗したか？ |
| Metrics | 集計された数値 | 今どういう状態か？ |

- 3つのシグナルは相互に関連付ける（Correlation）。trace_id でログとトレースを紐付ける
- ログだけで調査しない。トレースで全体像を掴み、ログで詳細を確認する

## Logging

### 基本原則

- 構造化ログ（JSON）を必須とする。プレーンテキストログは禁止
- ログメッセージ（body）は固定文字列にする。変数は属性（key-value）で渡す
- ログレベルを正しく使い分ける。レベルの乱用はノイズを生む
- 本番環境では INFO 以上を出力する。DEBUG は開発・トラブルシュート時のみ

### ログレベルの定義

| Level | 用途 | 例 |
|-------|------|-----|
| ERROR | 即座に対応が必要な障害 | DB接続失敗、外部API 5xx、パニック回復 |
| WARN | 異常だが処理は継続できる | リトライ発生、レート制限接近、非推奨API使用 |
| INFO | 正常な業務イベント | サーバー起動/停止、リクエスト処理完了、ジョブ完了 |
| DEBUG | 開発時の詳細情報 | 変数の中間値、SQL クエリ、外部APIリクエスト/レスポンス |

- ERROR を出したら、アラートが飛ぶ前提で書く。本当に対応が必要な時だけ使う
- 「念のため ERROR」は禁止。判断に迷ったら WARN にする

### 構造化ログの標準属性

OpenTelemetry Semantic Conventions + NewRelic/Datadog の予約属性に準拠する。
JSON ログの属性名は以下を標準とする。

#### 必須属性（すべてのログに含める）

| 属性名 | 説明 | 例 |
|--------|------|-----|
| `timestamp` | ISO 8601 / RFC 3339 形式 | `"2025-01-15T09:30:00.123Z"` |
| `level` | ログレベル（大文字） | `"INFO"`, `"ERROR"` |
| `message` | 固定文字列のログメッセージ | `"request completed"` |
| `service.name` | サービス名 | `"user-api"` |
| `service.version` | デプロイバージョン | `"1.2.3"` |
| `environment` | 環境名 | `"production"`, `"staging"` |

#### トレース相関属性（リクエストスコープのログに含める）

| 属性名 | 説明 |
|--------|------|
| `trace_id` | OpenTelemetry Trace ID（32文字 hex） |
| `span_id` | OpenTelemetry Span ID（16文字 hex） |
| `request_id` | アプリケーション発行のリクエストID |

- NewRelic: `trace.id`, `span.id` として自動マッピングされる
- Datadog: `dd.trace_id`, `dd.span_id` として自動マッピングされる
- OTel Collector 経由で送信する場合は自動付与される。アプリ側で明示的に埋める場合は上記属性名を使う

#### エラー属性（ERROR / WARN ログに含める）

| 属性名 | 説明 | 例 |
|--------|------|-----|
| `error.type` | エラーの種類 | `"NotFoundError"`, `"TimeoutError"` |
| `error.message` | エラーメッセージ | `"user not found"` |
| `error.stack_trace` | スタックトレース（ERROR のみ） | 複数行文字列 |

#### HTTP リクエスト属性（OTel Semantic Conventions stable）

| 属性名 | 説明 | 例 |
|--------|------|-----|
| `http.request.method` | HTTPメソッド | `"GET"`, `"POST"` |
| `http.response.status_code` | レスポンスステータスコード | `200`, `404` |
| `url.path` | リクエストパス | `"/api/v1/users"` |
| `http.route` | ルートパターン | `"/api/v1/users/{id}"` |
| `server.address` | サーバーホスト名 | `"api.example.com"` |
| `server.port` | サーバーポート | `8080` |
| `network.protocol.version` | HTTPバージョン | `"1.1"`, `"2"` |
| `user_agent.original` | User-Agent ヘッダー | `"Mozilla/5.0..."` |
| `client.address` | クライアントIP | `"192.168.1.1"` |
| `http.request.body.size` | リクエストボディサイズ（bytes） | `1234` |
| `http.response.body.size` | レスポンスボディサイズ（bytes） | `5678` |

#### DB 属性（OTel Semantic Conventions stable）

| 属性名 | 説明 | 例 |
|--------|------|-----|
| `db.system` | DB種別 | `"postgresql"`, `"mysql"` |
| `db.namespace` | データベース名 | `"myapp_production"` |
| `db.operation.name` | 操作名 | `"SELECT"`, `"INSERT"` |
| `db.query.text` | クエリ文（パラメータはマスク） | `"SELECT * FROM users WHERE id = $1"` |

#### カスタム業務属性

業務固有の属性はドメインプレフィックスを付けて名前空間を分ける:

| プレフィックス | 用途 | 例 |
|---------------|------|-----|
| `user.*` | ユーザー関連 | `user.id`, `user.role` |
| `order.*` | 注文関連 | `order.id`, `order.total` |
| `device.*` | デバイス関連 | `device.id`, `device.type` |

### ログ出力の JSON 例

```json
{
  "timestamp": "2025-01-15T09:30:00.123Z",
  "level": "INFO",
  "message": "request completed",
  "service.name": "user-api",
  "service.version": "1.2.3",
  "environment": "production",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "http.request.method": "GET",
  "http.route": "/api/v1/users/{id}",
  "http.response.status_code": 200,
  "duration_ms": 45.2,
  "user.id": "usr_abc123"
}
```

```json
{
  "timestamp": "2025-01-15T09:30:01.456Z",
  "level": "ERROR",
  "message": "failed to fetch user",
  "service.name": "user-api",
  "service.version": "1.2.3",
  "environment": "production",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "error.type": "NotFoundError",
  "error.message": "user not found: usr_xyz789",
  "user.id": "usr_xyz789"
}
```

### ログのアンチパターン

- メッセージに変数を埋め込む（`"user abc123 created"` → パースしにくい）
- 機密情報をログに出す（パスワード、トークン、個人情報）
- 1リクエストで大量のログを出す（ループ内でのログ出力）
- エラーを握りつぶす（catch して何もログに出さない）
- 同じエラーを複数層で重複ログ出力する（handler と service の両方で ERROR）

## Tracing

### 基本原則

- OpenTelemetry SDK を使用する。ベンダー固有の SDK は使わない
- すべての外部通信（HTTP, gRPC, DB, Queue）にスパンを作成する
- スパン名は低カーディナリティにする（`GET /users/{id}` ○、`GET /users/abc123` ✕）
- エラー発生時は `span.RecordError(err)` + `span.SetStatus(codes.Error, ...)` を設定する

### スパンの命名規則

| 種類 | 命名パターン | 例 |
|------|-------------|-----|
| HTTP Server | `{METHOD} {route}` | `GET /api/v1/users/{id}` |
| HTTP Client | `{METHOD}` | `POST` |
| DB | `{operation} {table}` | `SELECT users` |
| Queue Producer | `{queue} publish` | `user-events publish` |
| Queue Consumer | `{queue} process` | `user-events process` |
| Internal | `{package}.{function}` | `user.Service.Create` |

### スパン属性

OTel Semantic Conventions に従う。ログの HTTP / DB 属性と同じ属性名を使用する。
これにより、トレースとログの属性名が統一され、相関検索が容易になる。

### Context Propagation

- W3C Trace Context（`traceparent` / `tracestate` ヘッダー）を使用する
- サービス間通信では必ず Context を伝播する
- 非同期処理（Queue 経由）でも、メッセージヘッダーに Trace Context を埋め込む

## Metrics

### 基本原則

- OpenTelemetry Metrics SDK を使用する
- メトリクス名は OTel Semantic Conventions に従う
- Prometheus 形式でエクスポートする（`/metrics` エンドポイント）

### 標準メトリクス

すべてのサービスで以下のメトリクスを収集する:

#### HTTP Server

| メトリクス名 | 種類 | 説明 |
|-------------|------|------|
| `http.server.request.duration` | Histogram | リクエスト処理時間（秒） |
| `http.server.active_requests` | UpDownCounter | 処理中のリクエスト数 |
| `http.server.request.body.size` | Histogram | リクエストボディサイズ |
| `http.server.response.body.size` | Histogram | レスポンスボディサイズ |

#### Runtime

| メトリクス名 | 種類 | 説明 |
|-------------|------|------|
| `process.runtime.{lang}.goroutines` | Gauge | goroutine 数（Go） |
| `process.runtime.{lang}.mem.heap_alloc` | Gauge | ヒープ使用量 |
| `process.runtime.{lang}.gc.pause_total` | Counter | GC 停止時間累計 |

#### カスタム業務メトリクス

業務固有のメトリクスはドメインプレフィックスを付ける:

```
app.user.registration.count      (Counter)
app.order.processing.duration    (Histogram)
app.queue.message.lag            (Gauge)
```

### メトリクスの命名規則

- 小文字、ドット区切り（`http.server.request.duration`）
- 単位はメトリクス名に含めない（メタデータで指定する）
- Counter は累積値。Rate は可視化ツール側で計算する

## Resource Attributes

すべてのテレメトリ（Log / Trace / Metrics）に共通で付与する Resource 属性:

| 属性名 | 説明 | 例 |
|--------|------|-----|
| `service.name` | サービス名 | `"user-api"` |
| `service.version` | バージョン | `"1.2.3"` |
| `deployment.environment.name` | 環境名 | `"production"` |
| `host.name` | ホスト名 | `"ip-10-0-1-42"` |
| `cloud.provider` | クラウドプロバイダ | `"aws"` |
| `cloud.region` | リージョン | `"ap-northeast-1"` |

- NewRelic: `service`, `environment` タグとして自動マッピングされる
- Datadog: Unified Service Tagging（`env`, `service`, `version`）に対応する

## Observability のアンチパターン

- ログだけに頼る（トレースなしでは分散システムの問題を追えない）
- すべてをトレースする（内部の軽い関数までスパンを作るとオーバーヘッドが大きい）
- メトリクスのカーディナリティ爆発（ユーザーIDをラベルに入れない）
- アラートなしの Observability（見るだけでは意味がない。異常検知 → アラート → 対応のフローを作る。アラート設計は `monitoring-alerting-philosophy.md` 参照）
- 本番とステージングで異なる Observability 設定（同じ設定で動かし、環境ラベルで分ける）
