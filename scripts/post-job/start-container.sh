#!/usr/bin/env bash
# ==============================================================================
# Hook: start-container.sh
# Reliably starts a Docker container after backup completion
# ==============================================================================

set -euo pipefail

CONTAINER="${1:-}"

if [[ -z "$CONTAINER" ]]; then
  echo "[ERROR] Container name is required. Usage: $0 <container_name>" >&2
  exit 1
fi

if ! docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER}\$"; then
  echo "[ERROR] Container '$CONTAINER' does not exist." >&2
  exit 1
fi

if docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER}\$"; then
  echo "[INFO] Container '$CONTAINER' is already running."
  exit 0
fi

echo "[INFO] Starting container '$CONTAINER'..."
if docker start "$CONTAINER" >/dev/null; then
  echo "[INFO] Container '$CONTAINER' started successfully."
else
  echo "[ERROR] Failed to start container '$CONTAINER'." >&2
  exit 1
fi