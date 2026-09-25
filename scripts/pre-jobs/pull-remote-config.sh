#!/usr/bin/env bash
# ==============================================================================
# Hook: pull-remote-config.sh
# Securely pulls configuration files or directories from remote hosts/appliances
# Features: Recursive copy, mode/timestamp preservation, zero-tamper permissions
# ==============================================================================

set -euo pipefail

REMOTE_HOST="${1:-}"
REMOTE_PATH="${2:-}"
LOCAL_TARGET="${3:-}"

if [[ -z "$REMOTE_HOST" || -z "$REMOTE_PATH" || -z "$LOCAL_TARGET" ]]; then
  echo "Usage: $0 <remote_host_alias> <remote_path> <local_destination_path>" >&2
  echo "Example (single file): $0 dns /opt/AdGuardHome/AdGuardHome.yaml /srv/backups/dns/AdGuardHome.yaml" >&2
  echo "Example (directory):   $0 homeassistant /config /srv/backups/homeassistant/config" >&2
  exit 1
fi

mkdir -p "$(dirname "$LOCAL_TARGET")"

echo "[INFO] Pulling '$REMOTE_PATH' from '$REMOTE_HOST' to '$LOCAL_TARGET'..."

# Pull via SCP with batch mode (-B), quiet (-q), recursive (-r), and preserve attributes (-p)
if scp -B -q -r -p "${REMOTE_HOST}:${REMOTE_PATH}" "$LOCAL_TARGET"; then
  echo "[INFO] Successfully pulled: $LOCAL_TARGET"
else
  echo "[ERROR] Failed to pull configuration from $REMOTE_HOST:$REMOTE_PATH" >&2
  exit 1
fi

# Validation: Verify file or directory is non-empty
if [[ -d "$LOCAL_TARGET" ]]; then
  if [[ -z "$(ls -A "$LOCAL_TARGET" 2>/dev/null)" ]]; then
    echo "[ERROR] Pulled directory is empty: $LOCAL_TARGET" >&2
    exit 1
  fi
elif [[ -f "$LOCAL_TARGET" ]]; then
  if [[ ! -s "$LOCAL_TARGET" ]]; then
    echo "[ERROR] Pulled file is empty: $LOCAL_TARGET" >&2
    exit 1
  fi
else
  echo "[ERROR] Pulled target does not exist: $LOCAL_TARGET" >&2
  exit 1
fi
