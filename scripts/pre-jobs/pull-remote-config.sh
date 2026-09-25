#!/usr/bin/env bash
# ==============================================================================
# Hook: pull-remote-config.sh
# Securely pulls configuration files from remote network appliances (DNS, OPNsense)
# ==============================================================================

set -euo pipefail

REMOTE_HOST="${1:-}"
REMOTE_PATH="${2:-}"
LOCAL_TARGET="${3:-}"

if [[ -z "$REMOTE_HOST" || -z "$REMOTE_PATH" || -z "$LOCAL_TARGET" ]]; then
  echo "Usage: $0 <remote_host_alias> <remote_file_path> <local_destination_path>" >&2
  echo "Example: $0 dns /opt/AdGuardHome/AdGuardHome.yaml /srv/backups/dns/AdGuardHome.yaml" >&2
  exit 1
fi

mkdir -p "$(dirname "$LOCAL_TARGET")"

echo "[INFO] Pulling '$REMOTE_PATH' from '$REMOTE_HOST' to '$LOCAL_TARGET'..."

# Pull via SCP with batch mode (no password prompts)
if scp -B -q -p "${REMOTE_HOST}:${REMOTE_PATH}" "$LOCAL_TARGET"; then
  # Secure local file permissions
  chmod 0600 "$LOCAL_TARGET"
  echo "[INFO] Successfully pulled and hardened: $LOCAL_TARGET"
else
  echo "[ERROR] Failed to pull configuration from $REMOTE_HOST:$REMOTE_PATH" >&2
  exit 1
fi

# Verify non-empty file
if [[ ! -s "$LOCAL_TARGET" ]]; then
  echo "[ERROR] Pulled file is empty: $LOCAL_TARGET" >&2
  exit 1
fi
