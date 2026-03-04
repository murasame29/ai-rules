---
inclusion: auto
description: "SRE の哲学と実践原則。リスク管理、SLI/SLO/Error Budget、Toil 削減、インシデント対応、Postmortem、Capacity Planning。Google SRE Book / Workbook / Building Secure and Reliable Systems / Art of SLOs に基づく。"
---

# SRE Philosophy

Google SRE Book、SRE Workbook、Building Secure and Reliable Systems に基づく
Site Reliability Engineering の哲学と実践原則。

参考文献:
- [Site Reliability Engineering](https://sre.google/sre-book/table-of-contents/)
- [The Site Reliability Workbook](https://sre.google/workbook/table-of-contents/)
- [Building Secure and Reliable Systems](https://google.github.io/building-secure-and-reliable-systems/raw/toc.html)
- [The Art of SLOs](https://sre.google/resources/practices-and-processes/art-of-slos/) — Google CRE チームによる SLO 策定ワークショップ

## 根幹の哲学

### 信頼性はビジネスの機能である

- 100% の可用性は目指さない。過剰な信頼性はイノベーションの速度を犠牲にする
- ユーザーが 99% の信頼性のネットワーク上にいるなら、99.999% と 99.99% の差は体感できない
- 信頼性の目標はビジネスが許容できるリスクと一致させる。「十分に信頼できるが、それ以上ではない」
- 可用性目標は最小値であると同時に最大値でもある。超過は機能追加や技術的負債の返済に使う

### ソフトウェアエンジニアリングで運用問題を解く

- SRE はソフトウェアエンジニアリングのアプローチで運用の問題を解決する
- 手作業の繰り返し（Toil）をコードで自動化し、サブリニアにスケールする運用を実現する
- SRE の時間の少なくとも 50% はエンジニアリングプロジェクトに充てる。残りが運用作業

### Hope is not a strategy

- 「うまくいくだろう」は戦略ではない。障害は必ず起きる前提で設計する
- 障害を防ぐだけでなく、障害からの回復速度（MTTR）を最適化する
- すべての障害は学習の機会。Blame-free な文化で根本原因を追求する

## SLI / SLO / Error Budget

参考: [The Art of SLOs](https://sre.google/resources/practices-and-processes/art-of-slos/) — Google CRE チームによるワークショップ資料。
SLO 策定の実践的手法はこのワークショップの哲学に基づく。

### SLO 策定のステップ

ビジネスインパクト順に以下を繰り返す:

1. CUJ（Critical User Journey）を特定し、ビジネスインパクトでスタックランクする
2. SLI Menu から SLI Specification を選択する
3. SLI Specification を SLI Implementation に詳細化する
4. ユーザージャーニーを歩き、カバレッジのギャップを確認する
5. 過去の実績またはビジネス要件に基づいて SLO 目標値を設定する
6. Error Budget Policy を策定する

### CUJ（Critical User Journey）

ユーザーが単一の目標を達成するための一連のインタラクション。
UX リサーチの「ユーザージャーニー」を借用した概念。

- サービスの SLI は、ユーザーがそのサービスを使って目標を達成する際のインタラクションを測定しなければならない
- CUJ をビジネスインパクト順にスタックランクし、上位から SLI/SLO を策定する
- 収益に直結するジャーニー（購入、課金）は最優先
- ユーザーがジャーニーを完了前に自発的に離脱するケースも列挙し、測定対象を明確にする

### SLI（Service Level Indicator）

#### SLI Equation（SLI 方程式）

すべての SLI は以下の統一形式で表現する:

```
SLI = 有効なイベントのうち良好だったものの割合
    = Good Events / Valid Events
```

この形式の利点:
- SLI は常に 0%〜100% の範囲に収まる（0% = 全滅、100% = 完全）
- 統一形式により共通ツール（アラート、Error Budget 計算、レポート）を構築できる
- イベントを Error Budget から除外するには: 分子に含める（Good に分類）か、分母から除外する（Invalid に分類）

#### SLI Specification と SLI Implementation の区別

- SLI Specification: ユーザー期待の形式的な記述（「何を測るか」）
- SLI Implementation: 測定方法の具体的な実装（「どう測るか」）
- 1つの Specification に対して複数の Implementation が存在しうる。それぞれ Pros/Cons がある

#### SLI Menu（SLI の種類）

| カテゴリ | 対象 | SLI Specification | 例 |
|---------|------|-------------------|-----|
| Availability（可用性） | Request/Response | 有効なリクエストのうち正常に処理された割合 | HTTP 2xx/3xx の割合 |
| Latency（レイテンシ） | Request/Response | 有効なリクエストのうち閾値より速く処理された割合 | 100ms 以内に応答した割合 |
| Quality（品質） | Request/Response | 有効なリクエストのうち品質劣化なく処理された割合 | 全バックエンド応答を含むレスポンスの割合 |
| Freshness（鮮度） | Data Processing | 有効なデータのうち閾値より新しく更新された割合 | 5分以内に更新されたレコードの割合 |
| Coverage（カバレッジ） | Data Processing | 有効なデータのうち正常に処理された割合 | 処理成功レコード / 入力レコード |
| Correctness（正確性） | Data Processing | 有効なデータのうち正しい出力を生成した割合 | Golden データとの一致率 |
| Throughput（スループット） | Data Processing | データ処理レートが閾値を超えている時間の割合 | bytes/sec が基準を超えている秒数の割合 |

- Latency / Quality / Throughput はスペクトラムであり、複数の閾値で SLO を設定することが有効
  - 例: Latency → 99% < 100ms（ロングテール）+ 90% < 50ms（ベースライン）
- Correctness の検証方法は、出力生成とは独立した方法でなければならない（同じバグを見逃すため）

#### SLI の測定方法（ユーザーに近い順）

| 方法 | 利点 | 欠点 |
|------|------|------|
| Client Instrumentation | ユーザー体験の最も正確な測定。CDN 等サードパーティの信頼性も計測可能 | ログ取り込み遅延。運用アラートには不向き。ユーザー同意が必要 |
| Synthetic Clients（Probers） | マルチリクエストジャーニー全体を測定可能。インフラ外からの測定 | 合成リクエストによる近似。高信頼性目標には高頻度プローブが必要 |
| Front-end Infrastructure Metrics | 既存メトリクスを活用でき最小工数。ユーザーに最も近いインフラ測定点 | データ処理 SLI には不向き。複雑な要件に対応不可 |
| Application Server Metrics | 新規メトリクス追加が高速・低コスト。複雑なロジックをコード化可能 | サーバーに到達しないリクエストは見えない |
| Logs Processing | 既存ログを遡及的に処理可能。セッション ID で複雑なジャーニーを再構成可能 | サーバーに到達しないリクエストは見えない。処理遅延あり |

原則: SLI はユーザーに可能な限り近い場所で測定する。

### SLO（Service Level Objective）

SLI に対する目標値と測定ウィンドウの組み合わせ。チームの行動を決定する基準。

#### SLO の構成要素

```
SLO = SLI + 目標値 + 測定ウィンドウ

例: 過去28日間のホームページリクエストの 99% が 100ms 以内に応答すること
```

#### SLO 目標値の決め方

2つのアプローチがあり、最終的に収束させる:

1. Achievable SLO（達成可能な SLO）
   - 過去のパフォーマンスデータに基づいて設定する
   - 「現在のシステムが実際に達成しているレベル」
   - 現実的だが、ユーザー期待と乖離している可能性がある

2. Aspirational SLO（目指すべき SLO）
   - ビジネス要件とユーザー期待に基づいて設定する
   - 「ユーザーが満足するために必要なレベル」
   - 現在のシステムでは達成できない可能性がある

- 初期は Achievable SLO から始め、段階的に Aspirational SLO に近づける
- 両者のギャップが信頼性改善の投資判断材料になる
- SLO は固定値ではない。定期的に見直し、ユーザー期待とシステム実態に合わせて調整する

#### SLO ドキュメントテンプレート

```markdown
# SLO Document: {サービス名}

## User Journey: {ジャーニー名}

### SLI Type: {Availability / Latency / Quality / ...}

### SLI Specification
{有効なイベントのうち良好だったものの割合の記述}

### SLI Implementation
- 方法: {測定方法の具体的な記述}
- Pros: {利点}
- Cons: {欠点}

### SLO
- 目標値: {X%}
- 測定ウィンドウ: {28日間 rolling}

### Error Budget
- 予算: {1 - SLO目標値}
- 28日間の許容エラー量: {具体的な時間 or エラー数}
```

#### Outage Math（停止時間の数学）

SLO 目標値が許容する停止時間の目安:

| 信頼性 | 年間許容停止 | 四半期許容停止 | 28日間許容停止 |
|--------|------------|--------------|--------------|
| 99%    | 3日15時間  | 21時間36分   | 6時間43分    |
| 99.5%  | 1日19時間  | 10時間48分   | 3時間21分    |
| 99.9%  | 8時間45分  | 2時間9分     | 40分19秒     |
| 99.95% | 4時間22分  | 1時間4分     | 20分10秒     |
| 99.99% | 52分33秒   | 12分57秒     | 4分1秒       |

- ユーザーが 99% の信頼性のネットワーク上にいるなら、99.999% と 99.99% の差は体感できない
- 100% のエラーが一定時間続く場合と、低率のエラーが長時間続く場合では、同じ Error Budget 消費でもユーザー影響が異なる

### Error Budget

SLO の裏返し。「許容される障害の量」を明示的に定義する。

```
Error Budget = 1 - SLO
例: SLO 99.9% → Error Budget = 0.1% = 28日間で約40分の停止相当
```

- Error Budget が残っている → リスクを取って新機能をリリースできる
- Error Budget を使い切った → 信頼性改善にフォーカスする（機能リリースを抑制）
- Error Budget は開発チームと運用チームの「共通通貨」。イノベーション速度と信頼性のトレードオフを客観的に解決する

### Error Budget Policy

Error Budget の消費状況に応じたアクションを事前に合意する文書。
経営層の後ろ盾がなければ機能しない。

#### Error Budget Policy テンプレート

```markdown
# Error Budget Policy: {サービス名}

## 前提
- SLO: {目標値}
- 測定ウィンドウ: {28日間 rolling}
- 承認者: {プロダクトオーナー、エンジニアリングマネージャー}

## 通常状態（Error Budget 残量 > 50%）
- 通常の開発・リリースサイクルを継続
- 新機能のリリースを許可

## 警告状態（Error Budget 残量 25%〜50%）
- リリース頻度を低減（週次 → 隔週）
- 高リスクな変更（DB マイグレーション等）を延期
- 信頼性改善タスクの優先度を上げる

## 危険状態（Error Budget 残量 < 25%）
- 信頼性に直接寄与しない変更のリリースを凍結
- 全エンジニアリングリソースを信頼性改善に集中
- 根本原因の Postmortem を実施

## 枯渇状態（Error Budget = 0%）
- 全リリースを凍結（緊急のセキュリティ修正を除く）
- インシデント対応体制に移行
- 経営層へのエスカレーション
- Error Budget が回復するまで凍結を継続
```

### SLO ベースのアラート（Burn Rate Alert）

従来の閾値ベースアラートではなく、Error Budget の消費速度（Burn Rate）に基づいてアラートする。
Burn Rate の詳細な概念、Multi-window Multi-burn-rate アラートの設計パラメータ、
新規サービスの初期アラート設計は `monitoring-alerting-philosophy.md` を参照。

```
Burn Rate = 実際のエラー率 / SLO が許容するエラー率
Burn Rate 1x = SLO ちょうどのペース。ウィンドウ終了時に Error Budget がゼロになる
```

- SLO ベースのアラートは静的閾値（CPU > 80% 等）より優れている。ユーザー影響と直接相関するため
- Multi-window, Multi-burn-rate アラートを推奨（詳細は `monitoring-alerting-philosophy.md`）

### SLO の継続的見直しサイクル

SLO は一度設定して終わりではない。定期的に見直す。

- 四半期ごとに SLO を振り返る:
  - Error Budget の消費パターンを分析する
  - SLO が厳しすぎる（常に余裕がある）場合は引き上げを検討する
  - SLO が緩すぎる（ユーザーから不満が出ている）場合は引き下げを検討する
- 新しい CUJ が追加されたら SLI/SLO を追加する
- 使われなくなった CUJ の SLI/SLO は廃止する
- SLO の変更は関係者（プロダクト、開発、運用、経営）の合意を得る

## Toil の削減

### Toil の定義

以下の特性を持つ作業が Toil:

- 手動（Manual）: 人間が手を動かす必要がある
- 繰り返し（Repetitive）: 同じ作業を何度も行う
- 自動化可能（Automatable）: 機械でも同じ結果を出せる
- 戦術的（Tactical）: 割り込み駆動で、戦略的ではない
- 永続的な価値がない（No enduring value）: 作業後もサービスの状態が変わらない
- サービス成長に比例（O(n)）: サービスが大きくなるほど作業量が増える

### Toil 削減の原則

- Toil を 50% 以下に保つ。残りの時間でエンジニアリングプロジェクトを行う
- Toil を計測する。何にどれだけ時間を使っているかを可視化する
- 最も頻度が高い Toil から自動化する（ROI が最大）
- 「人間がやるべき判断」と「機械がやるべき作業」を分離する
- Toil を放置すると 100% に膨張する。意識的に削減し続ける

## インシデント対応

### インシデント管理の構造

| 役割 | 責任 |
|------|------|
| Incident Commander（IC） | 全体の指揮。意思決定、リソース配分 |
| Operations Lead | 技術的な対応の実行 |
| Communications Lead | ステークホルダーへの情報発信 |
| Planning Lead | 長期化した場合のリソース計画 |

- 役割を明確に分離する。1人が複数の役割を兼ねない（小規模インシデントを除く）
- インシデントの重大度（Severity）を定義し、対応レベルを段階的に設定する
- コミュニケーションチャネルを事前に決めておく（Slack チャネル、War Room 等）

### 対応の原則

- まず影響を緩和する（Mitigate）。根本原因の調査は後
- 変更をロールバックできるなら、まずロールバックする
- 「何が起きているか」を定期的に共有する。沈黙は不安を生む
- 対応者の交代（Handover）を計画する。疲労した状態での判断は危険

## Postmortem（障害振り返り）

### Blame-free Postmortem

- 個人を責めない。システムと仕組みの改善に集中する
- 「誰がミスしたか」ではなく「なぜシステムがミスを許したか」を問う
- Postmortem を書くことは罰ではない。学習と改善の機会

### Postmortem の構成

```markdown
# Postmortem: {インシデントタイトル}

## 概要
影響範囲、期間、重大度の要約。

## タイムライン
時系列でイベントを記録。検知、対応、緩和、解決の各ポイント。

## 根本原因
なぜこのインシデントが発生したか。5 Whys で深掘りする。

## 影響
ユーザー影響（影響ユーザー数、エラー率、ダウンタイム）。
ビジネス影響（売上、SLO 消費量）。

## 教訓
うまくいったこと / うまくいかなかったこと / 幸運だったこと。

## アクションアイテム
具体的な改善タスク。担当者と期限を明記。
```

- すべての重大インシデントで Postmortem を書く
- アクションアイテムは必ず追跡する。書いて終わりにしない
- Postmortem を組織全体で共有し、他チームの学びにする

## Capacity Planning

- 需要予測に基づいてリソースを事前に確保する
- 有機的成長（自然なトラフィック増加）と非有機的成長（新機能リリース、マーケティング施策）を分けて予測する
- 負荷テストで限界を把握する。「いつ壊れるか」を知っておく
- N+1 冗長性を確保する。1つのコンポーネントが失われても処理能力を維持する

## リリースエンジニアリング

- リリースは自動化する。手動リリースは Toil であり、ヒューマンエラーの温床
- Canary リリースで段階的にロールアウトする。全ユーザーに一度に展開しない
- ロールバックを常に可能にする。ロールバックできないリリースは危険
- リリースの頻度を上げる。小さなリリースはリスクが小さい
- 設定変更もコードと同じプロセス（レビュー、テスト、段階的ロールアウト）で管理する

## レジリエンス設計

Building Secure and Reliable Systems に基づく設計原則。

### Defense in Depth（多層防御）

- 単一の防御層に依存しない。複数の層で防御する
- 1つの層が突破されても、次の層で食い止める

### Blast Radius の制御

- 障害の影響範囲を限定する設計にする
- 役割分離（Role Separation）: 権限を分散する
- 場所分離（Location Separation）: 地理的に分散する
- 時間分離（Time Separation）: 段階的にロールアウトする

### Failure Domain

- 障害ドメインを明確に定義する。1つのドメインの障害が他に波及しない設計
- 冗長性を確保する。ただし冗長性のコストとリスクのバランスを取る

### 継続的検証

- 本番環境で定期的に障害をシミュレーションする（Chaos Engineering / DiRT）
- 災害復旧計画を定期的にテストする。テストしていない計画は計画ではない
- Game Day / Tabletop Exercise で対応手順を訓練する

## On-Call

アラート設計の哲学（Actionable / Intelligence / Urgency / Novel）、
アラートの分類・通知先・Runbook は `monitoring-alerting-philosophy.md` を参照。

- On-Call ローテーションは最低2人以上で回す
- On-Call 中のアラート対応は 5分以内に Acknowledge する
- On-Call 後は十分な休息を取る。疲労は判断力を低下させる
- On-Call の負荷が高すぎる場合は、サービスの信頼性改善にフォーカスする（根本対処）

## Simplicity

- シンプルさは信頼性の前提条件。複雑なシステムは予測不能な障害を起こす
- 「必要十分」を追求する。機能を追加する前に、本当に必要か問う
- 使われていないコード、設定、機能は積極的に削除する
- 依存関係を最小化する。依存が増えるほど障害の連鎖リスクが高まる

## アンチパターン

- SLO なしで運用する（何を守るべきか分からない）
- アラートが多すぎて全部無視する（アラート疲れ）
- Postmortem を書かない、または書いてもアクションアイテムを追跡しない
- Toil を「仕方ない」と受け入れる（自動化の機会を逃す）
- 障害を個人の責任にする（学習の機会を失う）
- 本番環境でテストしない（障害復旧手順が機能するか分からない）
- On-Call を1人で回す（燃え尽きる）
