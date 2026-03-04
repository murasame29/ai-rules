# AI Rules

Kiro の Steering / Skills として管理する、AI エージェント向けのルール・哲学集。

## 構成

```
.kiro/
├── steering/                              # 自動適用されるルール・哲学
│   ├── architecture-philosophy.md         # システムアーキテクチャ決定原則（Clean Architecture, ADR）
│   ├── gitops-workflow.md                 # GitOps ワークフロー（Trunk-Based, Conventional Commits）
│   ├── golang-rule.md                     # Golang コーディングルール（fileMatch: **/*.go）
│   ├── monitoring-alerting-philosophy.md  # Monitoring & Alerting 哲学（Four Golden Signals, Burn Rate）
│   ├── observability-philosophy.md        # Observability 原則（OTel Semantic Conventions）
│   ├── software-engineering-philosophy.md # ソフトウェア工学哲学（Software Engineering at Google）
│   ├── sre-philosophy.md                  # SRE 哲学（SLI/SLO/Error Budget, Toil, Incident）
│   ├── system-design-patterns.md          # システム設計パターン（同期/非同期, Saga, CQRS）
│   └── testing-philosophy.md              # テスト哲学（t-wada, TDD, Arrange-Act-Assert）
└── skills/                                # 手動で有効化するスキル
    ├── excalidraw-diagrams.md             # Excalidraw MCP ダイアグラム描画
    └── newrelic-alerting.md               # NewRelic Alert/Dashboard/NRQL 実装ガイド
```

## Steering（自動適用）

| ファイル | inclusion | 概要 |
|---------|-----------|------|
| `architecture-philosophy.md` | auto | Clean Architecture、ADR、設計の最上位原則、セキュリティ |
| `gitops-workflow.md` | auto | ブランチ命名、Conventional Commits、Issue/PR テンプレート、gh CLI |
| `golang-rule.md` | fileMatch (`**/*.go`) | Go 固有の Stack・命名・パッケージ構成・エラーハンドリング・テスト・Observability 実装 |
| `monitoring-alerting-philosophy.md` | auto | Four Golden Signals、SLO ベースアラート、Burn Rate、新規サービス初期アラート設計 |
| `observability-philosophy.md` | auto | OTel Semantic Conventions 準拠の Log/Trace/Metrics 属性命名 |
| `software-engineering-philosophy.md` | auto | Hyrum's Law、技術的負債、コードレビュー、CI/CD、大規模変更 |
| `sre-philosophy.md` | auto | SLI/SLO/Error Budget、Toil 削減、インシデント対応、Postmortem |
| `system-design-patterns.md` | auto | 同期/非同期/Job 判断フロー、リトライ、Circuit Breaker、Saga、Queue/DB 選定 |
| `testing-philosophy.md` | auto | t-wada 哲学、TDD、テストサイズ、テストダブル、Arrange-Act-Assert |

## Skills（手動有効化）

| ファイル | 概要 |
|---------|------|
| `excalidraw-diagrams.md` | Excalidraw MCP を使った手書き風ダイアグラム描画 |
| `newrelic-alerting.md` | NewRelic の Alert Condition / NRQL / Dashboard 設計・MCP 連携 |

## 参考文献

- [Site Reliability Engineering](https://sre.google/sre-book/table-of-contents/)
- [The Site Reliability Workbook](https://sre.google/workbook/table-of-contents/)
- [Building Secure and Reliable Systems](https://google.github.io/building-secure-and-reliable-systems/raw/toc.html)
- [The Art of SLOs](https://sre.google/resources/practices-and-processes/art-of-slos/)
- [Software Engineering at Google](https://abseil.io/resources/swe-book/html/toc.html)
- [Practical Monitoring](https://www.oreilly.com/library/view/practical-monitoring/9781491957349/)

## 使用

勝手に使ってください。※宗教的に問題があっても文句は受け付けません