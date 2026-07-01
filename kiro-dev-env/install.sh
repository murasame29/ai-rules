#!/usr/bin/env bash
# Kiro dev environment installer
# 前提: docker, docker compose, uvx, npx, python3, systemd(user) が使えること
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== 1. Qdrant のセットアップ ==="
mkdir -p "$HOME/qdrant"/{storage,snapshots,backups,config,scripts}
cp "$SCRIPT_DIR/qdrant/docker-compose.yml" "$HOME/qdrant/docker-compose.yml"
cp "$SCRIPT_DIR/qdrant/config/config.yaml" "$HOME/qdrant/config/config.yaml"
cp "$SCRIPT_DIR/qdrant/scripts/backup.sh" "$HOME/qdrant/scripts/backup.sh"
chmod +x "$HOME/qdrant/scripts/backup.sh"

echo "Qdrant コンテナを起動します"
(cd "$HOME/qdrant" && docker compose up -d)

echo "=== 2. systemd バックアップタイマーのセットアップ ==="
mkdir -p "$HOME/.config/systemd/user"
sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/systemd/qdrant-backup.service.template" \
  > "$HOME/.config/systemd/user/qdrant-backup.service"
cp "$SCRIPT_DIR/systemd/qdrant-backup.timer" "$HOME/.config/systemd/user/qdrant-backup.timer"

systemctl --user daemon-reload
systemctl --user enable --now qdrant-backup.timer

echo "ログアウト後もタイマーを動かすには linger を有効化してください:"
echo "  sudo loginctl enable-linger \$USER"

echo "=== 3. Kiro steering ファイルの配置 ==="
# steering の本体はリポジトリ直下の .kiro/steering/ を正とする
mkdir -p "$HOME/.kiro/steering"
cp "$REPO_ROOT/.kiro/steering/"*.md "$HOME/.kiro/steering/"

if [ -d "$REPO_ROOT/.kiro/skills" ]; then
  mkdir -p "$HOME/.kiro/skills"
  cp "$REPO_ROOT/.kiro/skills/"*.md "$HOME/.kiro/skills/" 2>/dev/null || true
fi

echo "=== 4. Kiro MCP 設定 ==="
MCP_TARGET="$HOME/.kiro/settings/mcp.json"
mkdir -p "$HOME/.kiro/settings"
if [ -f "$MCP_TARGET" ]; then
  echo "既存の $MCP_TARGET が見つかりました。上書きせず、参考用に以下へ出力します:"
  echo "  $HOME/.kiro/settings/mcp.json.generated"
  OUT="$HOME/.kiro/settings/mcp.json.generated"
else
  OUT="$MCP_TARGET"
fi

QDRANT_USER="${QDRANT_USER:-$USER}"
NEW_RELIC_API_KEY="${NEW_RELIC_API_KEY:-CHANGE_ME}"

sed \
  -e "s|\${QDRANT_USER}|$QDRANT_USER|g" \
  -e "s|\${NEW_RELIC_API_KEY}|$NEW_RELIC_API_KEY|g" \
  "$SCRIPT_DIR/kiro/mcp.json.template" > "$OUT"

echo
echo "=== 完了 ==="
echo "Qdrant:   http://localhost:6333/dashboard"
echo "MCP設定:  $OUT"
echo "必要なら NEW_RELIC_API_KEY を実際の値に書き換えてください。"
