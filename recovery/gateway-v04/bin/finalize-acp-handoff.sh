#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

RESULT_PATH="${1:-$RESULT_FILE}"
ensure_recovery_dirs

if [[ ! -f "$RESULT_PATH" ]]; then
  echo "missing result file: $RESULT_PATH" >&2
  exit 1
fi

ESCALATION_DECISION="$($SCRIPT_DIR/should-escalate.sh "$RESULT_PATH" 2>/dev/null || echo no-escalation)"
if [[ "$ESCALATION_DECISION" != "escalate" ]]; then
  echo "no-escalation"
  exit 0
fi

BUNDLE_DIR="$($SCRIPT_DIR/generate-acp-repair-bundle.sh)"
LAUNCH_FILE="$($SCRIPT_DIR/launch-acp-repair.sh "$BUNDLE_DIR")"
TASK_FILE="$($SCRIPT_DIR/prepare-acp-task.sh "$BUNDLE_DIR")"

INCIDENT_FINGERPRINT="$(python3 - "$RESULT_PATH" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, 'r', encoding='utf-8') as f:
    d = json.load(f)
parts = [
  d.get('terminal_state',''),
  d.get('classification',''),
  d.get('action',''),
  d.get('status_after',''),
  d.get('notes','')
]
print('|'.join(parts))
PY
)"
INCIDENT_ID="$(sha256_text "$INCIDENT_FINGERPRINT" | cut -c1-16)"
REQUEST_ROOT="${AUTO_ACP_REQUEST_DIR:-$ROOT_DIR/state/auto-acp}"
mkdir -p "$REQUEST_ROOT/requests" "$REQUEST_ROOT/runs"
REQUEST_FILE="$REQUEST_ROOT/requests/$(timestamp_local_slug)-${INCIDENT_ID}.json"
LATEST_FILE="$REQUEST_ROOT/latest-request.json"

AUTO_ENABLED="${AUTO_ACP_ENABLED:-0}"
AUTO_ELIGIBLE="false"
AUTO_REASON="disabled"
if [[ "$AUTO_ENABLED" == "1" ]]; then
  AUTO_ELIGIBLE="true"
  AUTO_REASON="eligible"
fi

cat > "$REQUEST_FILE" <<JSON
{
  "createdAt": $(json_escape "$(timestamp_utc)"),
  "resultPath": $(json_escape "$RESULT_PATH"),
  "bundleDir": $(json_escape "$BUNDLE_DIR"),
  "launchInstructions": $(json_escape "$LAUNCH_FILE"),
  "taskFile": $(json_escape "$TASK_FILE"),
  "incidentId": $(json_escape "$INCIDENT_ID"),
  "autoAcp": {
    "enabled": $([[ "$AUTO_ENABLED" == "1" ]] && echo true || echo false),
    "eligible": $AUTO_ELIGIBLE,
    "reason": $(json_escape "$AUTO_REASON"),
    "agentId": $(json_escape "${AUTO_ACP_AGENT_ID:-codex}"),
    "mode": $(json_escape "${AUTO_ACP_MODE:-run}"),
    "thread": $([[ "${AUTO_ACP_THREAD:-0}" == "1" ]] && echo true || echo false)
  }
}
JSON
cp "$REQUEST_FILE" "$LATEST_FILE"

DISPATCH_RECORD=""
if [[ "$AUTO_ENABLED" == "1" ]]; then
  DISPATCH_RECORD="$($SCRIPT_DIR/auto-acp-dispatch.sh "$REQUEST_FILE" 2>/dev/null || true)"
fi

BRIDGE_LOG=""
if [[ -n "$DISPATCH_RECORD" && -f "$DISPATCH_RECORD" ]]; then
  python3 - "$REQUEST_FILE" "$DISPATCH_RECORD" <<'PY'
import json, sys
req_path, dispatch_path = sys.argv[1], sys.argv[2]
with open(req_path, 'r', encoding='utf-8') as f:
    req = json.load(f)
with open(dispatch_path, 'r', encoding='utf-8') as f:
    dispatch = json.load(f)
req['autoAcp']['dispatchRecord'] = dispatch_path
req['autoAcp']['dispatchStatus'] = dispatch.get('status')
req['autoAcp']['dispatchReason'] = dispatch.get('reason')
with open(req_path, 'w', encoding='utf-8') as f:
    json.dump(req, f, indent=2)
    f.write('\n')
PY

  DISPATCH_STATUS="$(python3 - "$DISPATCH_RECORD" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    d = json.load(f)
print(d.get('status',''))
PY
)"
  if [[ "$DISPATCH_STATUS" == "requested" ]]; then
    BRIDGE_LOG="$($SCRIPT_DIR/run-auto-acp-bridge.sh "$REQUEST_FILE" 2>/dev/null || true)"
  fi
fi

if [[ -n "$BRIDGE_LOG" && -f "$BRIDGE_LOG" ]]; then
  python3 - "$REQUEST_FILE" "$BRIDGE_LOG" <<'PY'
import json, sys
req_path, bridge_log = sys.argv[1], sys.argv[2]
with open(req_path, 'r', encoding='utf-8') as f:
    req = json.load(f)
with open(bridge_log, 'r', encoding='utf-8') as f:
    bridge = json.load(f)
req['autoAcp']['bridgeLog'] = bridge_log
req['autoAcp']['bridgeStatus'] = bridge.get('status')
req['autoAcp']['bridgeReason'] = bridge.get('reason')
with open(req_path, 'w', encoding='utf-8') as f:
    json.dump(req, f, indent=2)
    f.write('\n')
PY
fi

MANIFEST_FILE="$BUNDLE_DIR/11-handoff-manifest.json"
cp "$REQUEST_FILE" "$MANIFEST_FILE"

echo "$REQUEST_FILE"
