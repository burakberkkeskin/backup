#!/usr/bin/env bash
# ==============================================================================
# Hook: postgresql-dump.sh
# Performs consistent PostgreSQL database dumps prior to backup
# ==============================================================================

set -euo pipefail

CONTAINER="${1:-}"
OUTPUT_PATH="${2:-}"
DB_USER="${3:-postgres}"
DB_NAME="${4:-}"

if [[ -z "$CONTAINER" || -z "$OUTPUT_PATH" ]]; then
  echo "Usage: $0 <container_name> <output_file_or_dir> [db_user] [db_name]" >&2
  echo "Example: $0 authentik_postgres /srv/backups/authentik.sql.gz" >&2
  exit 1
fi

# Ensure target directory exists
if [[ -d "$OUTPUT_PATH" ]]; then
  TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
  TARGET_FILE="${OUTPUT_PATH%/}/${CONTAINER}-${TIMESTAMP}.sql.gz"
else
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  TARGET_FILE="$OUTPUT_PATH"
fi

echo "[INFO] Starting PostgreSQL dump for container '$CONTAINER'..."

# If specific database is requested, use pg_dump; otherwise dumpall
if [[ -n "$DB_NAME" ]]; then
  docker exec "$CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$TARGET_FILE"
else
  docker exec "$CONTAINER" pg_dumpall -U "$DB_USER" --clean --if-exists | gzip > "$TARGET_FILE"
fi

# Verify generated archive
if [[ -s "$TARGET_FILE" ]]; then
  FILE_SIZE="$(du -h "$TARGET_FILE" | cut -f1)"
  echo "[INFO] PostgreSQL dump completed successfully: $TARGET_FILE ($FILE_SIZE)"
else
  echo "[ERROR] Dump file is empty or missing: $TARGET_FILE" >&2
  exit 1
fi