#!/usr/bin/env bash
# ==============================================================================
# Script: backup.sh
# Core automated backup runner using Restic and Rclone
# Features: ACID pre/post hooks, guaranteed cleanup traps, array-safe execution
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Load modules
# shellcheck source=/dev/null
source "$LIB_DIR/log.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/notify.sh"

# Execution state
START_TIME=$(date +%s)
LOG_FILE="$(mktemp /tmp/restic-backup-XXXXXX.log)"
export LOG_FILE

SOURCE_DIR=""
TAG=""
CONFIG_FILE=""
DRY_RUN=0
VERBOSE=0
declare -a EXCLUDES=()
declare -a PRE_JOBS=()
declare -a POST_JOBS=()

# ==============================================================================
# Trap & Cleanup Protocol (Guaranteed Post-Job Execution)
# ==============================================================================
cleanup() {
  local exit_code=$?
  # Disable traps during cleanup to prevent recursive execution
  trap - EXIT INT TERM

  # If help was shown or validation exited before parsing, exit cleanly
  if [[ -z "${TAG:-}" || -z "${SOURCE_DIR:-}" ]]; then
    if [[ -f "$LOG_FILE" ]]; then
      rm -f "$LOG_FILE"
    fi
    exit "$exit_code"
  fi

  # 1. Execute all post-jobs regardless of backup outcome
  run_post_jobs "$exit_code"

  # 2. Compute execution metrics
  local end_time
  end_time=$(date +%s)
  local duration="$(( end_time - START_TIME ))s"

  # 3. Notification dispatch
  if (( exit_code == 0 )); then
    log_info "Backup job finished successfully for tag '${TAG:-unknown}' in $duration."
    if [[ "$DRY_RUN" -eq 0 ]]; then
      notify_success "${TAG:-unknown}" "$duration"
    fi
  else
    log_error "Backup job failed for tag '${TAG:-unknown}' with exit code $exit_code after $duration."
    if [[ "$DRY_RUN" -eq 0 ]]; then
      notify_failure "${TAG:-unknown}" "$LOG_FILE"
    fi
  fi

  # 4. Clean up temporary log file
  if [[ -f "$LOG_FILE" ]]; then
    rm -f "$LOG_FILE"
  fi

  exit "$exit_code"
}
trap cleanup EXIT INT TERM

# ==============================================================================
# Helper Functions
# ==============================================================================
show_help() {
  cat << EOF
Usage:
  $(basename "$0") [options] --source <path> --tag <tag>
  $(basename "$0") [options] <source> <tag>

Options:
  -s, --source <path>        Path of file or directory to back up (required)
  -t, --tag <tag>            Backup tag identifier (required)
  -e, --exclude <pattern>    Path or pattern to exclude (repeatable)
      --pre-job <command>    Command to execute before backup (repeatable)
      --post-job <command>   Command to execute after backup (repeatable, guaranteed)
  -n, --dry-run              Simulate backup execution without uploading
  -c, --config <file>        Path to environment configuration file
  -v, --verbose              Enable verbose output (Restic --verbose)
  -h, --help                 Show this help message

Examples:
  $(basename "$0") /opt/docker/apps/caddy caddy
  $(basename "$0") --source /srv/immich --tag immich \\
      --pre-job "/opt/backup/scripts/pre-jobs/stop-container.sh immich_server" \\
      --pre-job "/opt/backup/scripts/pre-jobs/immich-postgresql-dump.sh" \\
      --post-job "/opt/backup/scripts/post-jobs/start-container.sh immich_server"
EOF
}

run_pre_jobs() {
  if (( ${#PRE_JOBS[@]} == 0 )); then
    return 0
  fi

  log_info "Executing ${#PRE_JOBS[@]} pre-backup job(s)..."
  for job in "${PRE_JOBS[@]}"; do
    log_info "Running pre-job: $job"
    if ! bash -c "$job"; then
      log_error "Pre-job failed: $job"
      return 1
    fi
    log_info "Pre-job finished successfully: $job"
  done
}

run_post_jobs() {
  local previous_exit="$1"

  if (( ${#POST_JOBS[@]} == 0 )); then
    return 0
  fi

  log_info "Executing ${#POST_JOBS[@]} post-backup job(s)..."
  for job in "${POST_JOBS[@]}"; do
    log_info "Running post-job: $job"
    if ! bash -c "$job"; then
      log_warn "Post-job returned non-zero exit code: $job"
    else
      log_info "Post-job finished successfully: $job"
    fi
  done
}

# ==============================================================================
# Argument Parsing
# ==============================================================================
parse_args() {
  local -a positional=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--source)
        [[ $# -ge 2 ]] || { log_error "Option '$1' requires an argument."; exit 1; }
        SOURCE_DIR="$2"
        shift 2
        ;;
      -t|--tag)
        [[ $# -ge 2 ]] || { log_error "Option '$1' requires an argument."; exit 1; }
        TAG="$2"
        shift 2
        ;;
      -e|--exclude)
        [[ $# -ge 2 ]] || { log_error "Option '$1' requires an argument."; exit 1; }
        EXCLUDES+=("$2")
        shift 2
        ;;
      --pre-job)
        [[ $# -ge 2 ]] || { log_error "Option '$1' requires an argument."; exit 1; }
        PRE_JOBS+=("$2")
        shift 2
        ;;
      --post-job)
        [[ $# -ge 2 ]] || { log_error "Option '$1' requires an argument."; exit 1; }
        POST_JOBS+=("$2")
        shift 2
        ;;
      -c|--config)
        [[ $# -ge 2 ]] || { log_error "Option '$1' requires an argument."; exit 1; }
        CONFIG_FILE="$2"
        shift 2
        ;;
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        # Positional arguments fallback (<source> <tag>)
        positional+=("$1")
        shift
        ;;
    esac
  done

  # Populate from positional if not provided via flags
  if [[ -z "$SOURCE_DIR" && ${#positional[@]} -ge 1 ]]; then
    SOURCE_DIR="${positional[0]}"
  fi
  if [[ -z "$TAG" && ${#positional[@]} -ge 2 ]]; then
    TAG="${positional[1]}"
  fi

  # Validate mandatory parameters
  if [[ -z "$SOURCE_DIR" ]]; then
    log_error "Missing required parameter: source directory. See --help."
    exit 1
  fi
  if [[ -z "$TAG" ]]; then
    log_error "Missing required parameter: tag identifier. See --help."
    exit 1
  fi
  if [[ ! -e "$SOURCE_DIR" ]]; then
    log_error "Source target does not exist: $SOURCE_DIR"
    exit 1
  fi
}

# ==============================================================================
# Main Backup Execution
# ==============================================================================
main() {
  parse_args "$@"

  # Load configurations and validate runtime
  load_config "$CONFIG_FILE"
  validate_dependencies
  validate_credentials

  log_info "Initiating backup | Tag: '$TAG' | Source: '$SOURCE_DIR' | Dry-run: $DRY_RUN"

  # 1. Execute Pre-Jobs (Exit aborts to cleanup trap)
  run_pre_jobs

  # 2. Build Restic Command Safely via Native Array
  local -a cmd=("restic" "backup" "--tag" "$TAG")

  if (( VERBOSE == 1 )); then
    cmd+=("--verbose")
  fi

  if (( DRY_RUN == 1 )); then
    cmd+=("--dry-run")
  fi

  for pattern in "${EXCLUDES[@]}"; do
    cmd+=("--exclude" "$pattern")
  done

  cmd+=("$SOURCE_DIR")

  log_debug "Executing command: ${cmd[*]}"

  # 3. Run Restic (Output is recorded in $LOG_FILE and echoed to console)
  if "${cmd[@]}"; then
    log_info "Restic snapshot completed successfully for: $SOURCE_DIR"
  else
    local rc=$?
    log_error "Restic command failed with exit code: $rc"
    exit "$rc"
  fi
}

main "$@"
