#!/usr/bin/env bash
# ==============================================================================
# Legacy Compatibility Shim: ntfy-backup-notifications.sh
# Bridges legacy function calls to the new modular notify.sh library
# ==============================================================================

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_LIB_DIR/notify.sh"

sendSuccessNotification() {
  notify_success "${TAG:-unknown}" "${DURATION:-0s}"
}

sendFailureNotification() {
  notify_failure "${TAG:-unknown}" "${LOG_FILE:-}"
}