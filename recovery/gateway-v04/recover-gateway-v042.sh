#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/bin/common.sh"

ensure_recovery_dirs

ACTION="none"
NOTES=""
PORT_CONFLICT_FILE=""
STATUS_BEFORE="unknown"
STATUS_AFTER="unknown"
CLASSIFICATION="unknown"
STATE_FILE=""
STATE_COLLECTION_OK=true
CLASSIFICATION_OK=true
LOCK_ACQUIRED=false
RECOVERER_ERROR=""
TERMINAL_STATE="pending"

COOLDOWN_SECONDS="${RECOVER_COOLDOWN_SECONDS:-60}"
MAX_RECENT_ATTEMPTS="${RECOVER_MAX_RECENT_ATTEMPTS:-3}"
WINDOW_SECONDS="${RECOVER_WINDOW_SECONDS:-300}"
LOCK_STALE_SECONDS="${RECOVER_LOCK_STALE_SECONDS:-600}"

if [[ "${OPENCLAW_RECOVERY_ALLOW_GOVERNANCE_OVERRIDE:-0}" == "1" ]]; then
  COOLDOWN_SECONDS="${OPENCLAW_RECOVERY_TEST_COOLDOWN_SECONDS:-$COOLDOWN_SECONDS}"
  MAX_RECENT_ATTEMPTS="${OPENCLAW_RECOVERY_TEST_MAX_RECENT_ATTEMPTS:-$MAX_RECENT_ATTEMPTS}"
  WINDOW_SECONDS="${OPENCLAW_RECOVERY_TEST_WINDOW_SECONDS:-$WINDOW_SECONDS}"
fi

LOCK_OWNER_FILE="$LOCK_DIR/owner.json"
now_epoch="$("$DATE_BIN" +%s)"

read_owner_number() {
  local key="$1"
  [[ -f "$LOCK_OWNER_FILE" ]] || return 0
  sed -n "s/.*\"$key\":[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "$LOCK_OWNER_FILE" | head -n 1
}

write_lock_owner() {
  cat > "$LOCK_OWNER_FILE" <<JSON
{
  "pid": $$,
  "created_at": $(json_escape "$(timestamp_utc)"),
  "created_epoch": $now_epoch,
  "service_label": $(json_escape "$SERVICE_LABEL"),
  "port": $GATEWAY_PORT,
  "profile": $(json_escape "$OPENCLAW_PROFILE"),
  "hostname": $(json_escape "$($HOSTNAME_BIN)"),
  "user": $(json_escape "$USER"),
  "recover_script": $(json_escape "$ROOT_DIR/recover-gateway-v042.sh")
}
JSON
}

release_lock() {
  if [[ "$LOCK_ACQUIRED" != true ]]; then
    return 0
  fi
  rm -f "$LOCK_OWNER_FILE" 2>/dev/null || true
  rmdir "$LOCK_DIR" 2>/dev/null || rm -rf "$LOCK_DIR" 2>/dev/null || true
  LOCK_ACQUIRED=false
}

acquire_lock() {
  local owner_pid dir_epoch reclaim_reason=""

  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_ACQUIRED=true
    write_lock_owner
    return 0
  fi

  owner_pid="$(read_owner_number pid)"
  if [[ -n "$owner_pid" ]] && kill -0 "$owner_pid" 2>/dev/null; then
    return 1
  fi

  if [[ -n "$owner_pid" ]]; then
    reclaim_reason="dead-owner"
  else
    dir_epoch="$(stat_mtime_epoch "$LOCK_DIR")"
    if [[ -n "$dir_epoch" ]] && (( now_epoch - dir_epoch > LOCK_STALE_SECONDS )); then
      reclaim_reason="stale-lockdir"
    fi
  fi

  if [[ -n "$reclaim_reason" ]]; then
    rm -f "$LOCK_OWNER_FILE" 2>/dev/null || true
    rmdir "$LOCK_DIR" 2>/dev/null || rm -rf "$LOCK_DIR" 2>/dev/null || true
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      LOCK_ACQUIRED=true
      write_lock_owner
      append_note "reclaimed stale recovery lock ($reclaim_reason)"
      return 0
    fi
  fi

  return 1
}

write_result() {
  cat > "$RESULT_FILE" <<JSON
{
  "timestamp": $(json_escape "$(timestamp_utc)"),
  "status_before": $(json_escape "$STATUS_BEFORE"),
  "classification": $(json_escape "$CLASSIFICATION"),
  "classification_ok": $CLASSIFICATION_OK,
  "action": $(json_escape "$ACTION"),
  "status_after": $(json_escape "$STATUS_AFTER"),
  "terminal_state": $(json_escape "$TERMINAL_STATE"),
  "state_file": $(json_escape "$STATE_FILE"),
  "state_collection_ok": $STATE_COLLECTION_OK,
  "port_conflict_file": $(json_escape "$PORT_CONFLICT_FILE"),
  "notes": $(json_escape "$NOTES"),
  "cooldown_seconds": $COOLDOWN_SECONDS,
  "max_recent_attempts": $MAX_RECENT_ATTEMPTS,
  "window_seconds": $WINDOW_SECONDS,
  "recent_attempts": ${recent_attempts:-0},
  "lock_acquired": $LOCK_ACQUIRED,
  "recoverer_error": $(json_escape "$RECOVERER_ERROR")
}
JSON
}

log_summary() {
  local summary
  summary="[gateway-recover] before=$STATUS_BEFORE class=$CLASSIFICATION class_ok=$CLASSIFICATION_OK action=$ACTION after=$STATUS_AFTER terminal=$TERMINAL_STATE recent_attempts=${recent_attempts:-0} lock=$LOCK_ACQUIRED notes=$NOTES recoverer_error=$RECOVERER_ERROR"
  printf '%s %s\n' "$(timestamp_utc)" "$summary" | tee -a "$EVENT_FILE"
}

on_unexpected_error() {
  local exit_code="$1"
  RECOVERER_ERROR="unexpected-script-error:$exit_code"
  if [[ "$ACTION" == "none" ]]; then
    ACTION="recoverer-error"
  fi
  if [[ "$STATUS_AFTER" == "unknown" ]]; then
    STATUS_AFTER="$STATUS_BEFORE"
  fi
  append_note "recoverer encountered unexpected error"
  TERMINAL_STATE="recoverer-error"
  write_result
  log_summary
  release_lock
  exit "$exit_code"
}

trap 'on_unexpected_error $?' ERR
trap 'release_lock' EXIT

if ! acquire_lock; then
  LOCK_ACQUIRED=false
  STATUS_BEFORE="unknown"
  STATUS_AFTER="unknown"
  ACTION="lock-skip"
  NOTES="another recovery instance is already running; skipped duplicate trigger"
  TERMINAL_STATE="governed-skip"
  write_result
  log_summary
  cat "$RESULT_FILE"
  exit 0
fi

if "$ADAPTER_BIN_DIR/check-gateway.sh" >/dev/null 2>&1; then
  STATUS_BEFORE="healthy"
else
  STATUS_BEFORE="failed"
fi

if STATE_FILE="$("$ADAPTER_BIN_DIR/collect-gateway-state.sh" 2>/dev/null)"; then
  STATE_COLLECTION_OK=true
else
  STATE_COLLECTION_OK=false
  STATE_FILE=""
  append_note "state collection failed"
fi

if CLASSIFICATION="$("$ADAPTER_BIN_DIR/classify-gateway-error.sh" 2>/dev/null)"; then
  CLASSIFICATION_OK=true
else
  CLASSIFICATION_OK=false
  CLASSIFICATION="unknown"
  append_note "classification failed"
fi

touch "$ATTEMPT_LOG"
last_attempt_epoch="$(tail -n 1 "$ATTEMPT_LOG" 2>/dev/null | cut -d' ' -f1 || true)"
recent_attempts="$(awk -v now="$now_epoch" -v win="$WINDOW_SECONDS" '{ if (now-$1 <= win) c++ } END { print c+0 }' "$ATTEMPT_LOG" 2>/dev/null || echo 0)"

if [[ "$STATUS_BEFORE" == "failed" ]]; then
  if [[ -n "$last_attempt_epoch" ]] && (( now_epoch - last_attempt_epoch < COOLDOWN_SECONDS )); then
    ACTION="cooldown-skip"
    append_note "cooldown active; restart skipped"
    TERMINAL_STATE="governed-skip"
  elif (( recent_attempts >= MAX_RECENT_ATTEMPTS )); then
    ACTION="attempt-limit-skip"
    append_note "too many recovery attempts in rolling window; restart skipped"
    TERMINAL_STATE="governed-skip"
  else
    printf '%s recover-attempt\n' "$now_epoch" >> "$ATTEMPT_LOG"
    case "$CLASSIFICATION" in
      config-error)
        ACTION="escalate"
        append_note "config error detected; restart skipped"
        TERMINAL_STATE="escalated"
        ;;
      port-conflict)
        ACTION="collect-and-escalate"
        if PORT_CONFLICT_FILE="$("$ADAPTER_BIN_DIR/collect-port-conflict.sh" 2>/dev/null)"; then :; else
          PORT_CONFLICT_FILE=""
          append_note "port conflict collection failed"
        fi
        append_note "port conflict detected; collected conflict state; restart skipped"
        TERMINAL_STATE="escalated"
        ;;
      plugin-or-dependency)
        ACTION="restart"
        append_note "plugin/dependency issue detected; restart attempted as conservative fallback"
        "$ADAPTER_BIN_DIR/stop-gateway.sh" || true
        "$ADAPTER_BIN_DIR/start-gateway.sh"
        ;;
      generic-runtime-error|unknown)
        ACTION="restart"
        append_note "runtime/unknown error; restart attempted"
        "$ADAPTER_BIN_DIR/stop-gateway.sh" || true
        "$ADAPTER_BIN_DIR/start-gateway.sh"
        ;;
      *)
        ACTION="escalate"
        append_note "unrecognized classification '$CLASSIFICATION'; restart skipped"
        TERMINAL_STATE="escalated"
        ;;
    esac
  fi
else
  TERMINAL_STATE="healthy"
fi

if "$ADAPTER_BIN_DIR/check-gateway.sh" >/dev/null 2>&1; then
  STATUS_AFTER="healthy"
else
  STATUS_AFTER="failed"
fi

if [[ "$TERMINAL_STATE" == "pending" ]]; then
  if [[ "$STATUS_AFTER" == "healthy" ]]; then
    TERMINAL_STATE="recovered"
  else
    TERMINAL_STATE="failed"
  fi
fi

write_result
log_summary
cat "$RESULT_FILE"

if [[ "$ACTION" == "lock-skip" ]]; then
  exit 0
fi
if [[ "$STATUS_AFTER" != "healthy" ]]; then
  exit 1
fi
