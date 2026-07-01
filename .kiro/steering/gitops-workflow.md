---
inclusion: auto
description: "GitOps ワークフロー規約。ブランチ命名、コミットメッセージ、Issue/PR テンプレート、gh CLI 活用、コードレビュー、リリースフロー。"
---

# GitOps Workflow

Git を中心としたチーム開発のワークフロー規約。
GitHub CLI（`gh`）を積極的に活用し、ブラウザ操作を最小化する。

## ブランチ戦略

Trunk-Based Development を採用する。`main` が唯一の統合ブランチ。

| ブランチ | 用途 |
|---------|------|
| `main` | 本番リリース。常にデプロイ可能な状態を維持。すべての PR のマージ先 |

- `main` への直接 push は禁止。必ず PR 経由でマージする
- `develop` ブランチは使用しない。作業ブランチは `main` から切り、`main` に戻す
- Feature Flag で未完成機能を隠し、`main` を常にリリース可能に保つ

### 作業ブランチの命名規則

```
{type}/{short-description}
{type}/{issue-number}-{short-description}  # Issue が存在する場合
```

| type | 用途 | 例 |
|------|------|-----|
| `feature` | 新機能 | `feature/user-registration`, `feature/123-user-registration` |
| `fix` | バグ修正 | `fix/login-timeout`, `fix/456-login-timeout` |
| `refactor` | リファクタリング | `refactor/extract-auth-service` |
| `chore` | CI/CD、依存更新、ドキュメント等 | `chore/update-go-version` |

- Issue ドリブンは必須ではない。Issue があれば番号を含めてトレーサビリティを
  上げるが、無くても作業を開始してよい
- 説明部分はケバブケース、英語、簡潔に
- 長すぎるブランチ名は避ける（目安: 50文字以内）

## コミットメッセージ

[Conventional Commits](https://www.conventionalcommits.org/) に準拠する。

```
{type}(scope): {subject}

{body}

{footer}
```

### type

| type | 用途 |
|------|------|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `refactor` | リファクタリング（機能変更なし） |
| `perf` | パフォーマンス改善 |
| `test` | テスト追加・修正 |
| `docs` | ドキュメント |
| `chore` | ビルド、CI、依存更新 |
| `ci` | CI/CD 設定変更 |
| `style` | フォーマット変更（コードの意味に影響しない） |

### ルール

- subject は命令形、英語、小文字始まり、末尾にピリオドを付けない
- subject は50文字以内
- body は「なぜ」を書く。「何を」はコードが語る
- 破壊的変更は `feat!:` または footer に `BREAKING CHANGE:` を記載する
- Issue を閉じる場合は footer に `Closes #123` を記載する

```
feat(user): add email verification flow

Implement email verification to prevent fake account creation.
Verification token expires after 24 hours.

Closes #123
```

## PR タイトル

PR タイトルは日本語で記述する。Conventional Commits の type プレフィックスは維持する。

```
{type}(scope): 日本語の説明
```

例:
- `feat(user): メール認証フローを追加`
- `fix(auth): ログインタイムアウトを修正`
- `chore(newrelic): reboot condition を notify workflow に追加`

## GitHub CLI（gh）の活用

ブラウザ操作の代わりに `gh` コマンドを使用する。

### Issue 操作

```bash
# Issue 作成
gh issue create --title "タイトル" --body "説明" --label "bug" --assignee "@me"

# Issue 一覧
gh issue list --assignee "@me" --state open

# Issue 確認
gh issue view 123
```

### PR 操作

```bash
# PR 作成（テンプレートが自動適用される）
gh pr create --title "feat(user): add email verification" --body-file .github/PULL_REQUEST_TEMPLATE.md --assignee "@me" --reviewer team-lead

# draft PR 作成（WIP）
gh pr create --draft --title "feat(user): add email verification"

# PR 一覧（レビュー待ち）
gh pr list --search "review:required"

# PR レビュー
gh pr review 456 --approve
gh pr review 456 --request-changes --body "修正点を記載"

# PR マージ（squash）
gh pr merge 456 --squash --delete-branch
```

### ブランチ操作

```bash
# Issue からブランチ作成
gh issue develop 123 --name "feature/123-user-registration" --checkout

# リモートブランチの削除
gh pr merge 456 --delete-branch
```

## Issue テンプレート

### Bug Report

```markdown
## 概要
<!-- バグの簡潔な説明 -->

## 再現手順
1.
2.
3.

## 期待する動作
<!-- 本来どう動くべきか -->

## 実際の動作
<!-- 実際に何が起きたか -->

## 環境
- サービス:
- 環境: production / staging / local
- バージョン / コミット:

## ログ・スクリーンショット
<!-- 関連するログやスクリーンショットがあれば添付 -->

## 影響範囲
<!-- ユーザー影響、データ影響など -->
```

### Feature Request

```markdown
## 概要
<!-- 機能の簡潔な説明 -->

## 背景・動機
<!-- なぜこの機能が必要か。解決したい課題 -->

## 提案する解決策
<!-- どう実装するか。技術的なアプローチ -->

## 代替案
<!-- 検討した他のアプローチがあれば -->

## 受け入れ条件
- [ ] 条件1
- [ ] 条件2
- [ ] 条件3

## 影響範囲
<!-- 既存機能への影響、マイグレーションの必要性など -->
```

## PR テンプレート

```markdown
## 概要
<!-- この PR で何を変更したか -->

Closes #<issue-number>  <!-- 対応する Issue がある場合のみ記載。無ければ削除してよい -->

## 変更内容
<!-- 主要な変更点を箇条書きで -->
-
-

## 変更の種類
- [ ] 新機能（feat）
- [ ] バグ修正（fix）
- [ ] リファクタリング（refactor）
- [ ] 破壊的変更（BREAKING CHANGE）
- [ ] ドキュメント（docs）
- [ ] CI/CD（ci）
- [ ] その他（chore）

## テスト
<!-- テストの実施内容 -->
- [ ] ユニットテスト追加 / 更新
- [ ] 既存テストが通ることを確認
- [ ] 手動テスト実施（手順を記載）

## レビュー観点
<!-- レビュアーに特に見てほしいポイント -->

## スクリーンショット / 動作確認
<!-- UI 変更がある場合。API の場合はリクエスト/レスポンス例 -->
```

## コードレビュー

### レビュアーの責務

- 機能要件を満たしているか
- テストが十分か（ハッピーパス + エッジケース）
- セキュリティ上の問題がないか
- パフォーマンスへの影響
- 既存のコーディングルール（steering files）に準拠しているか

### レビューのルール

- PR は小さく保つ。目安: 変更行数 400行以内。大きい場合は分割する
- レビューは 24時間以内に着手する
- Approve / Request Changes を明確にする。コメントだけで放置しない
- nit（些細な指摘）は `nit:` プレフィックスを付けて、ブロッキングでないことを明示する
- 設計に関する大きな議論は PR ではなく Issue や ADR で行う

### マージ戦略

- `main` へのマージ: Squash Merge（コミット履歴をクリーンに保つ）
- マージ後はリモートブランチを削除する

## CI/CD との連携

- PR 作成時に自動で lint / test / build を実行する
- `main` へのマージで自動デプロイ（CD）をトリガーする
- デプロイ後に Smoke Test を自動実行する
- デプロイ結果を Slack / GitHub Deployment Status に通知する

## アンチパターン

- 巨大な PR（レビューが形骸化する）
- コミットメッセージが `fix` や `update` だけ（履歴が追えない）
- `main` への直接 push（レビューなしのデプロイ）
- マージ後にブランチを放置する（ブランチが増殖する）
- レビューコメントを無視してマージする
