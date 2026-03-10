#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

LAUNCH_TARGET="$(launchctl_target)"
LAUNCH_DOMAIN="gui/$(recovery_uid)"
PLIST_PATH="$HOME/Library/LaunchAgents/${SERVICE_LABEL}.plist"
START_WAIT_ATTEMPTS="${START_WAIT_ATTEMPTS:-30}"
START_WAIT_SLEEP_SECONDS="${START_WAIT_SLEEP_SECONDS:-2}"

gateway_service_loaded_and_running() {
  local status_output=""

  status_output="$(gateway_status_json 2>/dev/null)" || return 1

  python3 - "$status_output" <<'PY'
import json
import sys

try:
    payload = json.loads(sys.argv[1])
except Exception:
    sys.exit(1)

service = payload.get("service") or {}
runtime = service.get("runtime") or {}

ok = (
    service.get("loaded") is True and
    runtime.get("status") == "running"
)

sys.exit(0 if ok else 1)
PY
}

wait_for_gateway_service() {
  local attempt=1

  while (( attempt <= START_WAIT_ATTEMPTS )); do
    if gateway_service_loaded_and_running; then
      return 0
    fi

    if (( attempt < START_WAIT_ATTEMPTS )); then
      sleep "$START_WAIT_SLEEP_SECONDS"
    fi
    ((attempt++))
  done

  printf 'gateway service did not report loaded/running after start\n' >&2
  gateway_status_json || true
  return 1
}

if "$LAUNCHCTL_BIN" print "$LAUNCH_TARGET" >/dev/null 2>&1; then
  start_rc=0
  gateway_cmd start || start_rc=$?
  wait_for_gateway_service && exit 0
  exit "$start_rc"
fi

if [[ ! -f "$PLIST_PATH" ]]; then
  printf 'gateway launchd plist not found: %s\n' "$PLIST_PATH" >&2
  exit 1
fi

"$LAUNCHCTL_BIN" bootstrap "$LAUNCH_DOMAIN" "$PLIST_PATH"
wait_for_gateway_service
