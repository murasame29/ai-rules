---
name: "NewRelic Alerting & Monitoring"
inclusion: manual
description: "NewRelic を使った Alert Condition / Alert Policy / Dashboard / NRQL の設計・実装ガイド。MCP 連携による運用支援を含む。"
keywords:
  - newrelic
  - alert
  - alerting
  - nrql
  - dashboard
  - monitoring
  - apm
  - slo
  - error budget
  - burn rate
  - incident
  - condition
  - policy
---

# NewRelic Alerting & Monitoring Skill

NewRelic を使った Monitoring / Alerting の実装ガイド。
言語非依存の哲学は `monitoring-alerting-philosophy.md` を参照。
SLI/SLO/Error Budget の策定は `sre-philosophy.md` を参照。

## MCP ツール

NewRelic MCP (`new-relic-mcp`) が利用可能。以下のツールで NewRelic の情報を直接取得・操作できる。

### エンティティ・アカウント

| ツール | 用途 |
|--------|------|
| `mcp_list_available_new_relic_accounts` | アクセス可能なアカウント一覧 |
| `mcp_get_entity` | GUID またはパターンでエンティティ検索 |
| `mcp_search_entity_with_tag` | タグでエンティティ検索 |
| `mcp_list_entity_types` | エンティティタイプのカタログ |
| `mcp_list_related_entities` | 関連エンティティの取得 |

### アラート・インシデント

| ツール | 用途 |
|--------|------|
| `mcp_list_alert_policies` | Alert Policy 一覧 |
| `mcp_list_alert_conditions` | Policy 内の Alert Condition 一覧 |
| `mcp_list_recent_issues` | 直近 24 時間の Issue 一覧 |
| `mcp_search_incident` | インシデントイベントの検索 |
| `mcp_generate_alert_insights_report` | Issue の AI 分析レポート |

### メトリクス・分析

| ツール | 用途 |
|--------|------|
| `mcp_execute_nrql_query` | NRQL クエリの実行 |
| `mcp_natural_language_to_nrql_query` | 自然言語 → NRQL 変換・実行 |
| `mcp_analyze_golden_metrics` | Golden Signal メトリクス分析 |
| `mcp_analyze_transactions` | トランザクション分析 |
| `mcp_analyze_entity_logs` | ログのエラーパターン分析 |
| `mcp_analyze_threads` | スレッドメトリクス分析 |
| `mcp_analyze_kafka_metrics` | Kafka メトリクス分析 |
| `mcp_list_entity_error_groups` | Errors Inbox のエラーグループ |
| `mcp_list_garbage_collection_metrics` | GC メトリクス |

### デプロイ・変更

| ツール | 用途 |
|--------|------|
| `mcp_list_change_events` | 変更イベント履歴 |
| `mcp_analyze_deployment_impact` | デプロイ前後のパフォーマンス比較 |
| `mcp_generate_user_impact_report` | エンドユーザー影響分析 |

### ダッシュボード・Synthetic

| ツール | 用途 |
|--------|------|
| `mcp_list_dashboards` | ダッシュボード一覧 |
| `mcp_get_dashboard` | ダッシュボード詳細 |
| `mcp_list_synthetic_monitors` | Synthetic Monitor 一覧 |

### ユーティリティ

| ツール | 用途 |
|--------|------|
| `mcp_convert_time_period_to_epoch_ms` | 自然言語 → epoch ms 変換 |
| `mcp_list_recent_logs` | 直近ログの取得 |

---

## Alert Condition 設計パターン

### SLO ベース Burn Rate Alert（推奨）

NewRelic の SLO 機能または NRQL で Burn Rate アラートを実装する。

#### NRQL による Burn Rate Alert の実装

```sql
-- Availability SLI: エラー率の計算（1時間ウィンドウ）
SELECT
  filter(count(*), WHERE httpResponseCode >= 500) / count(*) AS error_rate
FROM Transaction
WHERE appName = '{service_name}'
SINCE 1 hour ago
```

```sql
-- Burn Rate 計算: SLO 99.9% の場合、14.4x burn rate = エラー率 1.44%
SELECT
  filter(count(*), WHERE httpResponseCode >= 500) / count(*) AS error_rate
FROM Transaction
WHERE appName = '{service_name}'
SINCE 1 hour ago
-- Alert Condition: error_rate > 0.0144 (14.4 * 0.001)
```

#### Page Alert（高速消費: 14.4x / 1時間）

```
NRQL Alert Condition:
  SELECT filter(count(*), WHERE httpResponseCode >= 500) / count(*)
  FROM Transaction
  WHERE appName = '{service_name}'

  Threshold: above 0.0144 for at least 5 minutes
  Priority: Critical
```

#### Page Alert（中速消費: 6x / 6時間）

```
NRQL Alert Condition:
  SELECT filter(count(*), WHERE httpResponseCode >= 500) / count(*)
  FROM Transaction
  WHERE appName = '{service_name}'
  SINCE 6 hours ago

  Threshold: above 0.006 for at least 30 minutes
  Priority: Critical
```

#### Ticket Alert（低速消費: 1x / 3日）

```
NRQL Alert Condition:
  SELECT filter(count(*), WHERE httpResponseCode >= 500) / count(*)
  FROM Transaction
  WHERE appName = '{service_name}'
  SINCE 3 days ago

  Threshold: above 0.001 for at least 6 hours
  Priority: Warning
```

### Latency SLO Alert

```sql
-- Latency SLI: 閾値以内に応答したリクエストの割合
SELECT
  filter(count(*), WHERE duration < {threshold_sec}) / count(*) AS fast_ratio
FROM Transaction
WHERE appName = '{service_name}'
SINCE 1 hour ago
-- Alert: fast_ratio < (1 - 14.4 * (1 - SLO))
```

### 静的閾値 Alert（Phase 1 / SLO 未策定時）

```
-- High Error Rate
NRQL: SELECT percentage(count(*), WHERE httpResponseCode >= 500) FROM Transaction WHERE appName = '{service_name}'
Threshold: above 5 for at least 5 minutes
Priority: Critical

-- High Latency (p99)
NRQL: SELECT percentile(duration, 99) FROM Transaction WHERE appName = '{service_name}'
Threshold: above {threshold_sec} for at least 5 minutes
Priority: Critical

-- Service Down (Synthetic)
Type: Synthetic Monitor Failure
Threshold: fails for 2 consecutive checks
Priority: Critical
```

---

## Alert Policy の構成

### 推奨構成

サービスごとに以下の Policy を作成する:

```
{service_name} - SLO Alerts (Page)
  ├── Availability Burn Rate 14.4x / 1h
  ├── Availability Burn Rate 6x / 6h
  ├── Latency Burn Rate 14.4x / 1h
  └── Latency Burn Rate 6x / 6h

{service_name} - SLO Alerts (Ticket)
  ├── Availability Burn Rate 1x / 3d
  └── Latency Burn Rate 1x / 3d

{service_name} - Infrastructure Alerts
  ├── CPU > 90% for 10 min
  ├── Memory > 85% for 10 min
  ├── Disk > 80% for 10 min
  └── Container Restart Count > 3 in 5 min

{service_name} - Business Alerts
  └── {カスタム業務アラート}
```

### Incident Preference

- Page Policy: `By condition and signal`（条件ごとに個別インシデント）
- Ticket Policy: `By policy`（Policy 単位で集約）

### Notification Channel

| 重大度 | 通知先 |
|--------|--------|
| Critical (Page) | PagerDuty + Slack #alerts-critical |
| Warning (Ticket) | Slack #alerts-warning + Ticket 自動作成 |
| Info | Slack #alerts-info のみ |

---

## NRQL チートシート

### 基本パターン

```sql
-- エラー率
SELECT percentage(count(*), WHERE httpResponseCode >= 500)
FROM Transaction WHERE appName = '{service_name}' SINCE 1 hour ago

-- レイテンシ分布
SELECT percentile(duration, 50, 95, 99)
FROM Transaction WHERE appName = '{service_name}' SINCE 1 hour ago

-- スループット
SELECT rate(count(*), 1 minute) AS rpm
FROM Transaction WHERE appName = '{service_name}' SINCE 1 hour ago TIMESERIES

-- エラー内訳
SELECT count(*) FROM TransactionError
WHERE appName = '{service_name}' SINCE 1 hour ago FACET error.class, error.message

-- デプロイ前後比較
SELECT average(duration), percentage(count(*), WHERE httpResponseCode >= 500)
FROM Transaction WHERE appName = '{service_name}'
SINCE 2 hours ago COMPARE WITH 1 day ago TIMESERIES
```

### SLO 関連

```sql
-- Availability SLI（28日間）
SELECT filter(count(*), WHERE httpResponseCode < 500) / count(*) * 100 AS availability
FROM Transaction WHERE appName = '{service_name}' SINCE 28 days ago

-- Error Budget 残量
SELECT 100 - (filter(count(*), WHERE httpResponseCode >= 500) / count(*) * 100 / (100 - {SLO})) * 100
  AS error_budget_remaining_pct
FROM Transaction WHERE appName = '{service_name}' SINCE 28 days ago

-- Burn Rate（直近1時間）
SELECT (filter(count(*), WHERE httpResponseCode >= 500) / count(*)) / (1 - {SLO}/100)
  AS burn_rate
FROM Transaction WHERE appName = '{service_name}' SINCE 1 hour ago
```

### 依存サービス

```sql
-- 外部サービスのレイテンシ・エラー率
SELECT average(duration), percentage(count(*), WHERE httpResponseCode >= 500)
FROM ExternalService WHERE appName = '{service_name}' SINCE 1 hour ago FACET externalHost

-- DB クエリのスロークエリ
SELECT average(duration), count(*)
FROM DatabaseQuery WHERE appName = '{service_name}' AND duration > 1
SINCE 1 hour ago FACET databaseCallName LIMIT 20
```

---

## Dashboard テンプレート

### Service Overview Dashboard

以下のウィジェットを含む:

1. SLO 達成状況（Billboard: Availability %, Latency p99）
2. Error Budget 残量（Billboard: % remaining）
3. Four Golden Signals（Timeseries: Latency p50/p95/p99, Throughput, Error Rate, Saturation）
4. デプロイマーカー（Timeline: Change Events）
5. エラー内訳（Table: Top errors by class and message）
6. 依存サービスの状態（Table: External service latency and error rate）

### Debug Dashboard

1. トランザクション別レイテンシ（Timeseries: FACET name）
2. エラー詳細（Table: TransactionError with stack trace）
3. インフラメトリクス（Timeseries: CPU, Memory, Disk, Network）
4. ログストリーム（Log table: filtered by severity >= WARN）
5. JVM / Runtime メトリクス（Timeseries: GC, Heap, Goroutines）

---

## 運用ワークフロー

### インシデント対応時の MCP 活用

```
1. アラート受信
   → mcp_list_recent_issues で Issue 確認
   → mcp_generate_alert_insights_report で AI 分析

2. 影響範囲の特定
   → mcp_get_entity でエンティティ情報取得
   → mcp_analyze_golden_metrics で Golden Signal 確認
   → mcp_list_related_entities で依存関係マップ

3. 根本原因の調査
   → mcp_analyze_transactions でスロー/エラートランザクション特定
   → mcp_analyze_entity_logs でログパターン分析
   → mcp_list_change_events でデプロイ・変更履歴確認
   → mcp_analyze_deployment_impact でデプロイ影響分析

4. 影響評価
   → mcp_generate_user_impact_report でユーザー影響レポート
```

### 定期レビュー（月次）

```
1. SLO 達成状況の確認
   → NRQL で Availability / Latency SLI を集計
   → Error Budget 消費パターンを分析

2. アラート品質の確認
   → mcp_list_alert_policies で全 Policy 確認
   → mcp_search_incident で過去のインシデント傾向分析
   → 対応不要だったアラートを特定し、チューニング

3. ダッシュボードの確認
   → mcp_list_dashboards で全ダッシュボード確認
   → 使われていないダッシュボードを整理
```

---

## NewRelic 固有の注意点

### NRQL の制約

- `SINCE` の最大範囲はデータ保持期間に依存する（デフォルト: Transaction 8日、Metric 13ヶ月）
- `TIMESERIES` のバケット数には上限がある（最大 366）
- サブクエリは限定的。複雑な計算は複数のウィジェットに分割する
- `FACET` のカーディナリティが高すぎるとパフォーマンスが劣化する

### Alert Condition のベストプラクティス

- `Sliding window aggregation` を使って短期スパイクによる誤検知を減らす
- `Loss of signal` を設定して、データが来なくなった場合の挙動を定義する
- `Evaluation offset` でデータ収集の遅延を考慮する（通常 1〜3 分）
- `Fill data gaps` は `None` を推奨（ゼロ埋めは誤検知の原因）

### Synthetic Monitoring

- 主要な CUJ に対して Synthetic Monitor を設定する
- Scripted Browser / API Test で E2E のユーザージャーニーを監視する
- 複数ロケーションから実行し、リージョン固有の問題を検知する
- Synthetic の失敗は Black-Box Monitoring として Page アラートに接続する
