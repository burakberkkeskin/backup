#!/usr/bin/env bash
# ==============================================================================
# Library: Notification Module
# Dispatches backup status events to ntfy, generic webhooks, and healthchecks
# ==============================================================================

# Send notification for successful backup
notify_success() {
  local tag="${1:-unknown}"
  local duration="${2:-0s}"
  local host
  host="$(hostname -s 2>/dev/null || echo "host")"

  # 1. NTFY Dispatch
  if [[ -n "${NTFY_URL:-}" ]]; then
    local title="Backup Succeeded: $tag"
    local message="Host: $host | Tag: $tag | Duration: $duration | Status: OK"
    curl -fsS -m 10 \
      -H "Title: $title" \
      -H "Tags: white_check_mark,package" \
      -H "Priority: default" \
      -d "$message" \
      "$NTFY_URL" >/dev/null 2>&1 || log_warn "Failed to send success notification to ntfy"
  fi

  # 2. Generic JSON Webhook Dispatch
  if [[ -n "${WEBHOOK_URL:-}" ]]; then
    local payload
    payload=$(printf '{"status":"success","tag":"%s","host":"%s","duration":"%s","timestamp":"%s"}' \
      "$tag" "$host" "$duration" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')")
    curl -fsS -m 10 \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$WEBHOOK_URL" >/dev/null 2>&1 || log_warn "Failed to send success webhook"
  fi

  # 3. Dead-Man's Snitch / Heartbeat Ping (Uptime Kuma / Healthchecks.io)
  if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
    curl -fsS -m 10 --retry 3 "$HEALTHCHECK_URL" >/dev/null 2>&1 || log_warn "Failed to ping healthcheck service"
  fi
}

# Send notification for failed backup
notify_failure() {
  local tag="${1:-unknown}"
  local error_details="${2:-Backup process failed. Inspect logs.}"
  local host
  host="$(hostname -s 2>/dev/null || echo "host")"

  # Trim error details if reading from a file
  if [[ -f "$error_details" ]]; then
    error_details="$(tail -n 20 "$error_details" 2>/dev/null || echo "Log unreadable")"
  fi

  # 1. NTFY Dispatch
  if [[ -n "${NTFY_URL:-}" ]]; then
    local title="❌ Backup Failed: $tag"
    local message="Host: $host | Tag: $tag"$'\n\n'"Recent Errors:"$'\n'"$error_details"
    curl -fsS -m 10 \
      -H "Title: $title" \
      -H "Tags: x,rotating_light" \
      -H "Priority: urgent" \
      -d "$message" \
      "$NTFY_URL" >/dev/null 2>&1 || log_warn "Failed to send failure notification to ntfy"
  fi

  # 2. Generic JSON Webhook Dispatch
  if [[ -n "${WEBHOOK_URL:-}" ]]; then
    local escaped_errors
    escaped_errors="$(echo "$error_details" | tr '\n' ' ' | sed 's/"/\\"/g')"
    local payload
    payload=$(printf '{"status":"failure","tag":"%s","host":"%s","error":"%s","timestamp":"%s"}' \
      "$tag" "$host" "$escaped_errors" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')")
    curl -fsS -m 10 \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$WEBHOOK_URL" >/dev/null 2>&1 || log_warn "Failed to send failure webhook"
  fi

  # 3. Dead-Man's Snitch / Heartbeat Ping (Healthchecks.io failure signal)
  if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
    curl -fsS -m 10 --retry 2 "${HEALTHCHECK_URL%/}/fail" >/dev/null 2>&1 || true
  fi
}
