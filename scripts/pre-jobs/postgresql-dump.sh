#!/usr/bin/env bash
# ==============================================================================
# Hook: postgresql-dump.sh
# Performs atomic, safe online PostgreSQL dumps to a static file path
# Target: Single static file per service; versioning and retention handled by Restic
# ==============================================================================

set -euo pipefail

CONTAINER="${1:-}"
TARGET_FILE="${2:-}"
DB_USER="${3:-postgres}"
DB_NAME="${4:-}"

if [[ -z "$CONTAINER" || -z "$TARGET_FILE" ]]; then
  echo "Usage: $0 <container_name> <static_target_file.sql.gz> [db_user] [db_name]" >&2
  echo "Example: $0 immich_postgres /srv/immich/library/backups/immich-database.sql.gz" >&2
  echo "Example: $0 authentik_postgres /srv/backups/authentik/authentik-database.sql.gz" >&2
  exit 1
fi

# Ensure target directory exists
mkdir -p "$(dirname "$TARGET_FILE")"

# Validate container is active
if ! docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER}\$"; then
  echo "[ERROR] Database container '$CONTAINER' is not running." >&2
  exit 1
fi

# Atomic write staging file
TMP_FILE="${TARGET_FILE}.tmp.$$"

cleanup_tmp() {
  if [[ -f "$TMP_FILE" ]]; then
    rm -f "$TMP_FILE"
  fi
}
trap cleanup_tmp EXIT INT TERM

echo "[INFO] Starting atomic PostgreSQL dump for '$CONTAINER'..."

# Execute dump to temporary staging file
if [[ -n "$DB_NAME" ]]; then
  docker exec "$CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$TMP_FILE"
else
  docker exec "$CONTAINER" pg_dumpall -U "$DB_USER" --clean --if-exists | gzip > "$TMP_FILE"
fi

# Verify non-empty staging file
if [[ ! -s "$TMP_FILE" ]]; then
  echo "[ERROR] Database dump failed; staging file is missing or empty." >&2
  exit 1
fi

# Secure permissions and commit atomically
chmod 0600 "$TMP_FILE"
mv -f "$TMP_FILE" "$TARGET_FILE"

FILE_SIZE="$(du -h "$TARGET_FILE" | cut -f1)"
echo "[INFO] Atomic PostgreSQL dump completed successfully: $TARGET_FILE ($FILE_SIZE)"