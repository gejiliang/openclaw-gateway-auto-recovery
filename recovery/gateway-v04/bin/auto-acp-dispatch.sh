#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

REQUEST_FILE="${1:-}"
ensure_recovery_dirs

if [[ -z "$REQUEST_FILE" || ! -f "$REQUEST_FILE" ]]; then
  echo "missing request file" >&2
  exit 1
fi

REQUEST_ROOT="${AUTO_ACP_REQUEST_DIR:-$ROOT_DIR/state/auto-acp}"
RUNS_DIR="$REQUEST_ROOT/runs"
mkdir -p "$RUNS_DIR"
NOW_EPOCH="$($DATE_BIN +%s)"
COOLDOWN="${AUTO_ACP_COOLDOWN_SECONDS:-1800}"
WINDOW="${AUTO_ACP_WINDOW_SECONDS:-21600}"
MAX_RECENT="${AUTO_ACP_MAX_RECENT_ATTEMPTS:-1}"

read_json_field() {
  python3 - "$REQUEST_FILE" "$1" <<'PY'
import json, sys
path = sys.argv[1]
field = sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
cur = data
for part in field.split('.'):
    if isinstance(cur, dict):
        cur = cur.get(part)
    else:
        cur = None
        break
if isinstance(cur, bool):
    print('true' if cur else 'false')
elif cur is None:
    print('')
else:
    print(cur)
PY
}

ENABLED="$(read_json_field autoAcp.enabled)"
ELIGIBLE="$(read_json_field autoAcp.eligible)"
INCIDENT_ID="$(read_json_field incidentId)"
TASK_FILE="$(read_json_field taskFile)"
AGENT_ID="$(read_json_field autoAcp.agentId)"
MODE="$(read_json_field autoAcp.mode)"
THREAD="$(read_json_field autoAcp.thread)"

RUN_RECORD="$RUNS_DIR/${INCIDENT_ID}.json"
LATEST_RUN_EPOCH=""
RECENT_COUNT=0
if [[ -d "$RUNS_DIR" ]]; then
  for f in "$RUNS_DIR"/*.json; do
    [[ -e "$f" ]] || continue
    ts="$(python3 - "$f" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    d = json.load(fh)
print(d.get('createdEpoch',''))
PY
)"
    if [[ -n "$ts" ]]; then
      if (( NOW_EPOCH - ts <= WINDOW )); then
        RECENT_COUNT=$((RECENT_COUNT+1))
      fi
      if [[ -z "$LATEST_RUN_EPOCH" || "$ts" -gt "$LATEST_RUN_EPOCH" ]]; then
        LATEST_RUN_EPOCH="$ts"
      fi
    fi
  done
fi

STATUS="blocked"
REASON="disabled"
if [[ "$ENABLED" != "true" ]]; then
  REASON="auto-acp-disabled"
elif [[ "$ELIGIBLE" != "true" ]]; then
  REASON="request-not-eligible"
elif [[ -f "$RUN_RECORD" ]]; then
  STATUS="skipped"
  REASON="incident-already-requested"
elif [[ -n "$LATEST_RUN_EPOCH" ]] && (( NOW_EPOCH - LATEST_RUN_EPOCH < COOLDOWN )); then
  REASON="cooldown-active"
elif (( RECENT_COUNT >= MAX_RECENT )); then
  REASON="recent-attempt-limit"
elif [[ ! -f "$TASK_FILE" ]]; then
  REASON="missing-task-file"
else
  STATUS="requested"
  REASON="queued-for-operator-or-bridge"
fi

cat > "$RUN_RECORD" <<JSON
{
  "createdAt": $(json_escape "$(timestamp_utc)"),
  "createdEpoch": $NOW_EPOCH,
  "requestFile": $(json_escape "$REQUEST_FILE"),
  "incidentId": $(json_escape "$INCIDENT_ID"),
  "status": $(json_escape "$STATUS"),
  "reason": $(json_escape "$REASON"),
  "agentId": $(json_escape "$AGENT_ID"),
  "mode": $(json_escape "$MODE"),
  "thread": $([[ "$THREAD" == "true" ]] && echo true || echo false),
  "taskFile": $(json_escape "$TASK_FILE")
}
JSON

printf '%s\n' "$RUN_RECORD"
