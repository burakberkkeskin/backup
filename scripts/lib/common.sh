#!/usr/bin/env bash
# ==============================================================================
# Library: Common Utilities & Configuration Loader
# Handles environment setup, configuration parsing, and dependency validation
# ==============================================================================

# Ensure standard system binary paths are available
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

# Load configuration file if present
load_config() {
  local config_file="${1:-}"

  # Search standard configuration paths if not explicitly passed
  if [[ -z "$config_file" ]]; then
    local candidates=(
      "${BACKUP_CONFIG_FILE:-}"
      "/etc/backup/config.env"
      "/root/.backup_env"
      "$(dirname "${BASH_SOURCE[0]}")/../config.env"
    )
    for candidate in "${candidates[@]}"; do
      if [[ -n "$candidate" && -f "$candidate" && -r "$candidate" ]]; then
        config_file="$candidate"
        break
      fi
    done
  fi

  if [[ -n "$config_file" && -f "$config_file" ]]; then
    if [[ -r "$config_file" ]]; then
      log_debug "Loading configuration from: $config_file"
      # Source safely: only export variables, skip execution
      set -a
      # shellcheck source=/dev/null
      source "$config_file"
      set +a
    else
      log_warn "Configuration file exists but is not readable: $config_file"
    fi
  fi

  # Apply default fallbacks for unconfigured variables
  export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/root/.resticpasswd}"
  export RESTIC_REPOSITORY_FILE="${RESTIC_REPOSITORY_FILE:-/root/.resticrepo}"
  export RCLONE_CONFIG="${RCLONE_CONFIG:-/root/.config/rclone/rclone.conf}"
  export NTFY_CONFIG_FILE="${NTFY_CONFIG_FILE:-/root/.backup_ntfy_url}"

  # Fallback: Read NTFY_URL from dedicated file if not set in environment
  if [[ -z "${NTFY_URL:-}" && -f "$NTFY_CONFIG_FILE" && -r "$NTFY_CONFIG_FILE" ]]; then
    NTFY_URL="$(cat "$NTFY_CONFIG_FILE" 2>/dev/null || true)"
    export NTFY_URL
  fi
}

# Validate required CLI binaries
validate_dependencies() {
  local -a missing=()
  local -a required=("restic" "rclone")

  for binary in "${required[@]}"; do
    if ! command -v "$binary" >/dev/null 2>&1; then
      missing+=("$binary")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    log_error "Missing required executable dependencies: ${missing[*]}"
    return 1
  fi
  log_debug "All required dependencies verified: ${required[*]}"
  return 0
}

# Validate Restic and Rclone credentials
validate_credentials() {
  local has_error=0

  if [[ ! -f "$RESTIC_PASSWORD_FILE" || ! -r "$RESTIC_PASSWORD_FILE" ]]; then
    log_error "Restic password file not found or unreadable: $RESTIC_PASSWORD_FILE"
    has_error=1
  fi

  if [[ ! -f "$RESTIC_REPOSITORY_FILE" || ! -r "$RESTIC_REPOSITORY_FILE" ]]; then
    log_error "Restic repository file not found or unreadable: $RESTIC_REPOSITORY_FILE"
    has_error=1
  fi

  if [[ ! -f "$RCLONE_CONFIG" || ! -r "$RCLONE_CONFIG" ]]; then
    log_error "Rclone configuration file not found or unreadable: $RCLONE_CONFIG"
    has_error=1
  fi

  return "$has_error"
}
