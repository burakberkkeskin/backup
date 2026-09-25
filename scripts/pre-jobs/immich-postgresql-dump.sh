#!/usr/bin/env bash
# ==============================================================================
# Hook: immich-postgresql-dump.sh
# Dumps Immich PostgreSQL database (with pgvector) to the library backup directory
# ==============================================================================

set -euo pipefail

CONTAINER="${1:-immich_postgres}"
BACKUP_DIR="${2:-/srv/immich/library/backups}"
KEEP_LOCAL="${3:-3}"

if ! docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER}\$"; then
  echo "[ERROR] Immich database container '$CONTAINER' is not running." >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
DUMP_FILE="${BACKUP_DIR}/manual-backup-${TIMESTAMP}.sql.gz"

echo "[INFO] Dumping Immich PostgreSQL database from '$CONTAINER'..."

docker exec "$CONTAINER" pg_dumpall --clean --if-exists --username=postgres | gzip > "$DUMP_FILE"

if [[ -s "$DUMP_FILE" ]]; then
  FILE_SIZE="$(du -h "$DUMP_FILE" | cut -f1)"
  echo "[INFO] Immich database dump created successfully: $DUMP_FILE ($FILE_SIZE)"
else
  echo "[ERROR] Database dump file is empty or was not created: $DUMP_FILE" >&2
  exit 1
fi

# Prune older local sql.gz dumps to prevent unbounded disk growth (keeps last N)
echo "[INFO] Enforcing local dump retention (keep last $KEEP_LOCAL)..."
find "$BACKUP_DIR" -maxdepth 1 -name "manual-backup-*.sql.gz" -type f | sort -r | tail -n +"$(( KEEP_LOCAL + 1 ))" | while read -r old_file; do
  echo "[INFO] Removing old local dump: $old_file"
  rm -f "$old_file"
done
