#!/usr/bin/env bash
# ==============================================================================
# Script: backup-recovery-codes.sh
# Encrypted, dedicated backup runner for sensitive 2FA recovery codes
# Targets: Dedicated recovery-codes Restic repository (rclone:gdrive:recovery-codes)
# Features:
#   - Interactive mode: prompts for app name & multi-line codes (zero shell history leak)
#   - Non-interactive mode: supports arguments or stdin pipe
#   - Ephemeral or persistent local storage options
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${RECOVERY_CODES_BASE_DIR:-/opt/backup/recovery-codes}"

# Credentials & repository pointers
export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-/root/.resticpasswd}"
export RESTIC_REPOSITORY_FILE="${RECOVERY_CODES_RESTIC_REPOSITORY_FILE:-/root/.recovery-codes-resticrepo}"
export RCLONE_CONFIG="${RCLONE_CONFIG:-/root/.config/rclone/rclone.conf}"
export PATH="/usr/local/bin:$PATH"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }

# Pre-flight environment checks
validate_env() {
  if [[ ! -f "$RESTIC_REPOSITORY_FILE" ]]; then
    log_error "Recovery codes repository pointer file not found: $RESTIC_REPOSITORY_FILE"
    exit 1
  fi

  if [[ ! -f "$RESTIC_PASSWORD_FILE" ]]; then
    log_error "Restic password file not found: $RESTIC_PASSWORD_FILE"
    exit 1
  fi

  if ! command -v restic >/dev/null 2>&1; then
    log_error "restic binary not found in PATH."
    exit 1
  fi
}

sanitize_name() {
  local input="$1"
  # Convert to lowercase, replace spaces/dots with hyphens, remove invalid chars
  echo "$input" | tr '[:upper:]' '[:lower:]' | tr ' .' '-' | sed 's/[^a-z0-9_-]//g'
}

show_help() {
  cat << EOF
Usage:
  Interactive Mode:
    $(basename "$0")

  Non-Interactive Mode:
    $(basename "$0") <app_name> <file_path> [--keep-local]
    $(basename "$0") <app_name> -           [--keep-local] (Read from stdin)

Examples:
  # Interactive prompt (Safe: no codes saved in shell history)
  $(basename "$0")

  # Backup from an existing file
  $(basename "$0") github /tmp/github-recovery.txt

  # Backup via stdin pipe
  cat bitwarden.txt | $(basename "$0") bitwarden -
EOF
}

main() {
  # Parse arguments
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
  fi

  validate_env

  local app_name=""
  local source_input=""
  local keep_local=0
  local is_interactive=0

  if [[ $# -eq 0 ]]; then
    is_interactive=1
  else
    app_name="$(sanitize_name "$1")"
    source_input="${2:-}"
    if [[ "${3:-}" == "--keep-local" ]]; then
      keep_local=1
    fi
  fi

  # Interactive prompts if no arguments provided
  if (( is_interactive == 1 )); then
    echo -e "${BLUE}======================================================${NC}"
    echo -e "${BLUE}  Interactive 2FA Recovery Codes Backup Runner        ${NC}"
    echo -e "${BLUE}======================================================${NC}"
    
    while [[ -z "$app_name" ]]; do
      read -rp "Enter application / service name (e.g. proton, github, zoho): " raw_name
      app_name="$(sanitize_name "$raw_name")"
      if [[ -z "$app_name" ]]; then
        log_warn "Application name cannot be empty."
      fi
    done
  fi

  # Prepare target directories
  local target_dir="$BASE_DIR/$app_name"
  local target_file="$target_dir/${app_name}.txt"
  mkdir -p "$target_dir"
  chmod 0700 "$target_dir"

  # Capture content
  if (( is_interactive == 1 )); then
    echo
    echo -e "${YELLOW}Paste recovery codes below. Press [Ctrl+D] on a new line when done:${NC}"
    echo -e "${BLUE}------------------------------------------------------${NC}"
    cat > "$target_file"
    echo -e "${BLUE}------------------------------------------------------${NC}"
  elif [[ "$source_input" == "-" ]]; then
    cat > "$target_file"
  elif [[ -f "$source_input" ]]; then
    cp -p "$source_input" "$target_file"
  else
    log_error "Source file not found: $source_input"
    exit 1
  fi

  # Verify non-empty file
  if [[ ! -s "$target_file" ]]; then
    log_error "No recovery codes provided; target file is empty. Aborting."
    rm -f "$target_file"
    exit 1
  fi

  chmod 0600 "$target_file"
  local code_lines
  code_lines=$(wc -l < "$target_file" | tr -d ' ')
  log_info "Captured $code_lines line(s) of recovery codes for '$app_name'."

  # Execute Restic Backup
  log_info "Initiating offsite backup to dedicated recovery-codes repository..."
  if restic backup --tag "$app_name" "$target_dir"; then
    log_ok "Snapshot successfully saved for '$app_name'."
  else
    log_error "Restic backup failed for '$app_name'."
    exit 1
  fi

  # Local cleanup handling
  if (( is_interactive == 1 )); then
    echo
    read -rp "Do you want to securely wipe the local plaintext copy? [Y/n]: " wipe_choice
    wipe_choice="${wipe_choice:-Y}"
    if [[ "$wipe_choice" =~ ^[Yy]$ ]]; then
      rm -f "$target_file"
      rmdir "$target_dir" 2>/dev/null || true
      log_ok "Local plaintext copy wiped. Zero local footprint."
    else
      log_info "Local copy preserved at: $target_file"
    fi
  elif (( keep_local == 0 )); then
    rm -f "$target_file"
    rmdir "$target_dir" 2>/dev/null || true
    log_info "Local plaintext copy cleaned up."
  else
    log_info "Local copy preserved at: $target_file"
  fi

  echo
  log_ok "All operations finished successfully."
}

main "$@"
