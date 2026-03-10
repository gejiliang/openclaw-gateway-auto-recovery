#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ensure_recovery_dirs

STATUS_CHECK_ATTEMPTS="${STATUS_CHECK_ATTEMPTS:-3}"
STATUS_CHECK_SLEEP_SECONDS="${STATUS_CHECK_SLEEP_SECONDS:-2}"

status_output=""
deep_output=""
health_output=""
probe_degraded=0
failure_reason=""

attempt=1
while (( attempt <= STATUS_CHECK_ATTEMPTS )); do
  status_output=""
  deep_output=""
  health_output=""
  probe_degraded=0
  failure_reason=""

  if ! status_output="$(gateway_status_json)"; then
    failure_reason="status_no_probe_failed"
  else
    primary_rc=0
    python3 - "$status_output" <<'PY' || primary_rc=$?
import json, sys

raw = sys.argv[1]
try:
    payload = json.loads(raw)
except Exception:
    sys.exit(10)

service = payload.get('service') or {}
runtime = service.get('runtime') or {}
config_audit = service.get('configAudit') or {}
extra_services = payload.get('extraServices') or []
port = payload.get('port') or {}
listeners = port.get('listeners') or []

runtime_pid = runtime.get('pid')
listener_pids = [item.get('pid') for item in listeners if item.get('pid') is not None]
pid_match = runtime_pid is not None and runtime_pid in listener_pids

ok = (
    service.get('loaded') is True and
    runtime.get('status') == 'running' and
    config_audit.get('ok') is True and
    extra_services == [] and
    pid_match
)

sys.exit(0 if ok else 20)
PY
    if (( primary_rc != 0 )); then
      if (( primary_rc == 10 )); then
        failure_reason="status_no_probe_invalid_json"
      else
        failure_reason="primary_health_conditions_failed"
      fi
    fi
  fi

  if [[ -z "$failure_reason" ]]; then
    if ! deep_output="$(gateway_status_deep_json)"; then
      probe_degraded=1
    else
      deep_rc=0
      python3 - "$deep_output" <<'PY' || deep_rc=$?
import json, sys
raw = sys.argv[1]
try:
    payload = json.loads(raw)
except Exception:
    sys.exit(1)
rpc = payload.get('rpc') or {}
sys.exit(0 if rpc.get('ok') is True else 1)
PY
      if (( deep_rc != 0 )); then
        probe_degraded=1
      fi
    fi

    if ! health_output="$(run_openclaw health 2>&1)"; then
      probe_degraded=1
    fi

    if (( probe_degraded )); then
      append_note "probe_degraded"
    fi

    exit 0
  fi

  if (( attempt < STATUS_CHECK_ATTEMPTS )); then
    sleep "$STATUS_CHECK_SLEEP_SECONDS"
  fi
  ((attempt++))
done

printf 'gateway primary health check failed: %s\n' "$failure_reason" >&2
if [[ -n "$status_output" ]]; then
  printf '%s\n' "$status_output" >&2
fi
if [[ -n "$deep_output" ]]; then
  printf '%s\n' "$deep_output" >&2
fi
if [[ -n "$health_output" ]]; then
  printf '%s\n' "$health_output" >&2
fi
exit 1
