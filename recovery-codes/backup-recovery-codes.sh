#!/usr/bin/env bash
# ==============================================================================
# Script: backup-recovery-codes.sh
# Encrypted, dedicated backup runner for sensitive recovery codes & 2FA tokens
# Targets: recovery-codes dedicated repository pointer
# ==============================================================================

set -euo pipefail

TARGET_DIR="${1:-}"
TAG="${2:-recovery-codes}"

if [[ -z "$TARGET_DIR" ]]; then
  echo "Usage: $0 <directory_path> [tag]" >&2
  echo "Example: $0 /root/recovery-codes recovery-codes" >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "[ERROR] Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

# Credentials & repository pointers
export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/root/.resticpasswd}"
export RESTIC_REPOSITORY_FILE="${RECOVERY_CODES_RESTIC_REPOSITORY_FILE:-/root/.recovery-codes-resticrepo}"
export RCLONE_CONFIG="${RCLONE_CONFIG:-/root/.config/rclone/rclone.conf}"
export PATH="/usr/local/bin:$PATH"

if [[ ! -f "$RESTIC_REPOSITORY_FILE" ]]; then
  echo "[ERROR] Recovery codes repository file not found: $RESTIC_REPOSITORY_FILE" >&2
  exit 1
fi

echo "[INFO] Starting dedicated recovery-codes backup for: $TARGET_DIR (tag: $TAG)"

restic --verbose backup --tag "$TAG" "$TARGET_DIR"

echo "[INFO] Recovery codes backup completed successfully."
