#!/usr/bin/env bash
# ==============================================================================
# Hook: vaultwarden-pre-job.sh (SQLite Safe Online Snapshot)
# Uses SQLite .backup API to safely snapshot live databases without locking
# ==============================================================================

set -euo pipefail

DB_FILE="${1:-/srv/vaultwarden/vw-data/db.sqlite3}"
TARGET_BACKUP="${2:-${DB_FILE}.backup}"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "[ERROR] 'sqlite3' CLI utility is not installed. Run: apt install -y sqlite3" >&2
  exit 1
fi

if [[ ! -f "$DB_FILE" ]]; then
  echo "[ERROR] SQLite database file not found: $DB_FILE" >&2
  exit 1
fi

echo "[INFO] Performing atomic SQLite online backup: $DB_FILE -> $TARGET_BACKUP"

if sqlite3 "$DB_FILE" ".backup '$TARGET_BACKUP'"; then
  chmod 0600 "$TARGET_BACKUP"
  echo "[INFO] SQLite online backup completed successfully: $TARGET_BACKUP"
else
  echo "[ERROR] SQLite online backup failed." >&2
  exit 1
fi
