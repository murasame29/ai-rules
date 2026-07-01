# kiro-dev-env

Kiro + Qdrant memory の開発環境構成管理。新規環境で `./install.sh` を実行すると
以下が一括セットアップされる。

steering / skills 本体はリポジトリ直下の `.kiro/steering/` `.kiro/skills/` を
正として管理し、`install.sh` はそこからコピーする（`kiro-dev-env` 配下には
steering の複製を持たない）。

## 構成物

| ディレクトリ | 内容 |
|---|---|
| `qdrant/` | Qdrant の docker-compose、config.yaml、バックアップスクリプト |
| `systemd/` | バックアップ用 systemd user timer/service (テンプレート) |
| `kiro/mcp.json.template` | ユーザーレベル MCP 設定テンプレート |
| `workspaces/` | ワークスペース単位の MCP 設定例（ドメイン分離用） |

## 前提

- docker, docker compose
- uvx (`pip install uv` または https://docs.astral.sh/uv/getting-started/installation/)
- npx (Node.js)
- python3
- systemd (WSL2 の場合は `/etc/wsl.conf` に `[boot] systemd=true` が必要)

## セットアップ

```bash
git clone https://github.com/murasame29/ai-rules.git
cd ai-rules/kiro-dev-env

# 必要なら環境変数を指定
export QDRANT_USER=yourname
export NEW_RELIC_API_KEY=xxxxx

./install.sh
```

`~/.kiro/settings/mcp.json` が既に存在する場合は上書きせず、
`~/.kiro/settings/mcp.json.generated` に出力するので、差分を見て手動で反映する。

## ログアウト後もバックアップタイマーを動かす

```bash
sudo loginctl enable-linger $USER
```

## ワークスペース単位のドメイン分離

`workspaces/` 以下にワークスペースごとの `.kiro/settings/mcp.json` サンプルを置いている。
新しいプロジェクトを追加する場合は `mcp.json.workspace-template` をコピーし、
`__QDRANT_USER__` と `__DOMAIN__` を置き換えて、対象ワークスペースの
`.kiro/settings/mcp.json` に配置する。

コレクション設計:

- `<user>-memory`: ユーザーレベルのデフォルト（ワークスペース固有設定が無い場所）
- `<user>-common`: 全ワークスペース共通の知見
- `<user>-<domain>`: ワークスペース固有の知見（例: `murasame29-optfit`）

Qdrant 自体のバックエンド分離（Redis/Elasticsearch等への切替）は検討したが、
公式 `mcp-server-qdrant` はファイル/DBバックエンドの抽象化を提供していないため、
現状は Qdrant 固定。埋め込みも OpenAI/Bedrock ではなく `fastembed` によるローカル
生成とし、外部API依存・費用が発生しない構成にしている。
