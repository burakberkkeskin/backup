#!/usr/bin/env bash
# ==============================================================================
# Library: Logging Module
# Provides structured, leveled, timestamped logging with optional color support
# ==============================================================================

# Default log level if not explicitly provided
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Color codes (only applied if connected to a terminal)
if [[ -t 1 ]]; then
  COLOR_DEBUG="\033[0;36m"   # Cyan
  COLOR_INFO="\033[0;32m"    # Green
  COLOR_WARN="\033[0;33m"    # Yellow
  COLOR_ERROR="\033[0;31m"   # Red
  COLOR_RESET="\033[0m"
else
  COLOR_DEBUG=""
  COLOR_INFO=""
  COLOR_WARN=""
  COLOR_ERROR=""
  COLOR_RESET=""
fi

# Map log level names to integer priorities
_log_priority() {
  case "$1" in
    DEBUG) echo 0 ;;
    INFO)  echo 1 ;;
    WARN)  echo 2 ;;
    ERROR) echo 3 ;;
    *)     echo 1 ;;
  esac
}

# Core logging function
log_message() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  local current_prio
  current_prio="$(_log_priority "$LOG_LEVEL")"
  local target_prio
  target_prio="$(_log_priority "$level")"

  if (( target_prio >= current_prio )); then
    local color=""
    case "$level" in
      DEBUG) color="$COLOR_DEBUG" ;;
      INFO)  color="$COLOR_INFO" ;;
      WARN)  color="$COLOR_WARN" ;;
      ERROR) color="$COLOR_ERROR" ;;
    esac

    # Formatted terminal string with color
    local formatted_console="${color}${timestamp} [${level}] ${message}${COLOR_RESET}"
    # Plain string without color for file logging
    local formatted_plain="${timestamp} [${level}] ${message}"

    if [[ "$level" == "ERROR" ]]; then
      echo -e "$formatted_console" >&2
    else
      echo -e "$formatted_console"
    fi

    # Append to log file if LOG_FILE environment variable is defined
    if [[ -n "${LOG_FILE:-}" ]]; then
      echo "$formatted_plain" >> "$LOG_FILE" 2>/dev/null || true
    fi
  fi
}

log_debug() { log_message "DEBUG" "$@"; }
log_info()  { log_message "INFO"  "$@"; }
log_warn()  { log_message "WARN"  "$@"; }
log_error() { log_message "ERROR" "$@"; }
