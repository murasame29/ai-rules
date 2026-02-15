# AGENTS.md

このファイルは、AIエージェントがプロジェクトのルール、アーキテクチャ、コーディング規約を理解するためのインデックスです。

---

## 📚 ドキュメント構成

```
docs/
├── adr/                    # Architecture Decision Records
├── backend/
│   └── AGENTS.md           # バックエンド実装ルール
├── script/
│   └── AGENTS.md           # スクリプト・CLI関連ルール
└── shared/
    ├── SECURITY.md         # セキュリティガイドライン
    └── STYLEGUIDE.md       # コーディングスタイルガイド
```

---

## 🔗 ドキュメントリンク

### Backend
- [Backend AGENTS.md](docs/backend/AGENTS.md) - サーバーサイド実装ルール
  - Configuration / DI / HTTP Server / Middleware
  - RDB Handling / Message Handler / Queue Consumers
  - WebSocket

### Script
- [Script AGENTS.md](docs/script/AGENTS.md) - CLI・スクリプト関連ルール
  - CLI設計 / Makefile規約 / シェルスクリプト

### Shared (共通)
- [STYLEGUIDE.md](docs/shared/STYLEGUIDE.md) - コーディングスタイルガイド
  - Golang Coding Rules / 命名規則 / Communication Rules
- [SECURITY.md](docs/shared/SECURITY.md) - セキュリティガイドライン
  - 認証・認可 / シークレット管理 / 入力バリデーション

### ADR (Architecture Decision Records)
- [docs/adr/](docs/adr/) - アーキテクチャ決定記録
  - 重要な設計判断とその理由を記録

---

## 🏗️ Architecture Overview

このプロジェクトは **Clean Architecture (Hexagonal Architecture)** に基づいて設計されています。

### 依存関係ルール
```
Infrastructure → Application → Model
```
外側の層は内側の層に依存しますが、逆は許されません。

| 層 | 役割 | 例 |
|----|------|-----|
| Model (内側) | ビジネスルール、エンティティ | `internal/model/` |
| Application (中間) | ユースケース | `internal/application/` |
| Infrastructure (外側) | 実装詳細 | `internal/infrastructure/` |

### ディレクトリ構造
```
cmd/           # エントリポイント
internal/
├── model/          # ドメインエンティティ、インターフェース
├── application/    # ユースケース実装
├── infrastructure/ # DB, HTTP, Queue実装
└── config/         # 設定
pkg/           # 共有ライブラリ
```

---

## 📖 クイックリファレンス

詳細は各ドキュメントを参照してください。

| カテゴリ | ドキュメント |
|---------|-------------|
| Goコーディング規約 | [STYLEGUIDE.md](docs/shared/STYLEGUIDE.md) |
| サーバー実装 | [Backend AGENTS.md](docs/backend/AGENTS.md) |
| セキュリティ | [SECURITY.md](docs/shared/SECURITY.md) |
| スクリプト | [Script AGENTS.md](docs/script/AGENTS.md) |
