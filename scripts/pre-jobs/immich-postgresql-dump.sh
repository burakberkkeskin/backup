#!/usr/bin/env bash
# ==============================================================================
# Immich Database Dump Compatibility Wrapper
# Forwards execution to the unified atomic postgresql-dump.sh hook
# Static Target: /srv/immich/library/backups/immich-database.sql.gz
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_FILE="${1:-/srv/immich/library/backups/immich-database.sql.gz}"

exec "$SCRIPT_DIR/postgresql-dump.sh" "immich_postgres" "$TARGET_FILE" "postgres"
