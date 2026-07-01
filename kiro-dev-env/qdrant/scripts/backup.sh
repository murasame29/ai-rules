#!/usr/bin/env bash
set -euo pipefail

QDRANT_URL="http://localhost:6333"
SNAPSHOT_DIR="${HOME}/qdrant/snapshots"
BACKUP_DIR="${HOME}/qdrant/backups"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

collections=$(curl -s "${QDRANT_URL}/collections" | python3 -c "import json,sys; print('\n'.join(c['name'] for c in json.load(sys.stdin)['result']['collections']))")

if [ -z "$collections" ]; then
  echo "$(date -Iseconds) no collections to back up"
  exit 0
fi

for name in $collections; do
  echo "$(date -Iseconds) snapshotting collection: $name"
  resp=$(curl -s -X POST "${QDRANT_URL}/collections/${name}/snapshots")
  snap_name=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['name'])")

  mkdir -p "${BACKUP_DIR}/${name}"
  cp "${SNAPSHOT_DIR}/${name}/${snap_name}" "${BACKUP_DIR}/${name}/${TIMESTAMP}_${snap_name}"
  echo "$(date -Iseconds) copied to ${BACKUP_DIR}/${name}/${TIMESTAMP}_${snap_name}"
done

# 古いバックアップとQdrant内スナップショットの間引き（保持期間超過分を削除）
find "$BACKUP_DIR" -type f -name "*.snapshot" -mtime "+${RETENTION_DAYS}" -delete
for name in $collections; do
  find "${SNAPSHOT_DIR}/${name}" -type f -name "*.snapshot" -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true
done

echo "$(date -Iseconds) backup done"
