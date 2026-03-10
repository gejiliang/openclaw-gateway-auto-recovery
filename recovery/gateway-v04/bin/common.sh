#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADAPTER_ENV="$ROOT_DIR/adapter.env"

if [[ ! -f "$ADAPTER_ENV" ]]; then
  echo "adapter.env not found: $ADAPTER_ENV" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ADAPTER_ENV"

if [[ "${OPENCLAW_RECOVERY_ALLOW_CLI_OVERRIDE:-0}" == "1" ]] && [[ -n "${OPENCLAW_RECOVERY_TEST_CLI_BIN:-}" ]]; then
  CLI_BIN="$OPENCLAW_RECOVERY_TEST_CLI_BIN"
fi

ensure_recovery_dirs() {
  mkdir -p "$RECOVERY_ROOT" \
    "$ADAPTER_BIN_DIR" \
    "$(dirname "$RESULT_FILE")" \
    "$(dirname "$EVENT_FILE")" \
    "$(dirname "$ATTEMPT_LOG")" \
    "$SAMPLES_DIR" \
    "$(dirname "$LOCK_DIR")"
}

timestamp_utc() {
  "$DATE_BIN" -u +"%Y-%m-%dT%H:%M:%SZ"
}

timestamp_local_slug() {
  "$DATE_BIN" +"%Y%m%dT%H%M%S"
}

json_escape() {
  local value="${1-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "$value"
}

append_note() {
  local note="$1"
  if [[ -z "${NOTES:-}" ]]; then
    NOTES="$note"
  else
    NOTES="$NOTES; $note"
  fi
}

run_openclaw() {
  if [[ -n "${OPENCLAW_PROFILE:-}" ]] && [[ "$OPENCLAW_PROFILE" != "default" ]]; then
    "$CLI_BIN" --profile "$OPENCLAW_PROFILE" "$@"
  else
    "$CLI_BIN" "$@"
  fi
}

gateway_cmd() {
  run_openclaw gateway "$@"
}

latest_cli_file_log() {
  local latest
  latest="$(
    find "$CLI_FILE_LOG_DIR" -maxdepth 1 -type f -name 'openclaw-*.log' 2>/dev/null \
      | LC_ALL=C sort \
      | tail -n 1
  )"
  printf '%s\n' "$latest"
}

sample_file_path() {
  local prefix="$1"
  printf '%s/%s-%s-%s.txt\n' "$SAMPLES_DIR" "$prefix" "$(timestamp_local_slug)" "$$"
}

stat_mtime_epoch() {
  local target="$1"
  "$STAT_BIN" -f %m "$target" 2>/dev/null || "$STAT_BIN" -c %Y "$target" 2>/dev/null || true
}

recovery_uid() {
  id -u
}

launchctl_target() {
  printf 'gui/%s/%s\n' "$(recovery_uid)" "$SERVICE_LABEL"
}
