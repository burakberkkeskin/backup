#!/usr/bin/env bash
# ==============================================================================
# Hook: stop-container.sh
# Gracefully stops a Docker container prior to backup
# ==============================================================================

set -euo pipefail

CONTAINER="${1:-}"

if [[ -z "$CONTAINER" ]]; then
  echo "[ERROR] Container name is required. Usage: $0 <container_name> [timeout_seconds]" >&2
  exit 1
fi

TIMEOUT="${2:-30}"

if ! docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER}\$"; then
  echo "[INFO] Container '$CONTAINER' is not currently running. Skipping stop."
  exit 0
fi

echo "[INFO] Gracefully stopping container '$CONTAINER' (timeout: ${TIMEOUT}s)..."
if docker stop -t "$TIMEOUT" "$CONTAINER" >/dev/null; then
  echo "[INFO] Container '$CONTAINER' stopped successfully."
else
  echo "[ERROR] Failed to stop container '$CONTAINER'." >&2
  exit 1
fi