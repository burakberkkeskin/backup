#!/usr/bin/env bash
# ==============================================================================
# Restic Repository Maintenance Script
# Applies GFS retention policy, prunes unreferenced data, and verifies integrity
# ==============================================================================

set -euo pipefail

# 1. Environment & Credentials Configuration
export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/root/.resticpasswd}"
export RESTIC_REPOSITORY_FILE="${RESTIC_REPOSITORY_FILE:-/root/.resticrepo}"
export PATH="/usr/local/bin:$PATH"
export RCLONE_CONFIG="${RCLONE_CONFIG:-/root/.config/rclone/rclone.conf}"

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Starting Weekly Restic Maintenance ==="

# 2. Apply GFS Retention Policy and Prune Unreferenced Blobs
# Active workloads: keep 7 daily, 4 weekly, 12 monthly snapshots per tag
/usr/bin/restic forget \
  --tag caddy \
  --tag obsidian \
  --tag immich \
  --group-by host,paths,tags \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --prune

# 3. Repository Integrity Verification (Fast check with 1% random data block subset)
/usr/bin/restic check --read-data-subset=1%

# 4. Local Cache Maintenance
/usr/bin/restic cache --cleanup

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Weekly Restic Maintenance Completed Successfully ==="
