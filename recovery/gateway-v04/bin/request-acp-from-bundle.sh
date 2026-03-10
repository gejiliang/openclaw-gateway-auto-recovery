#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

BUNDLE_DIR="${1:-}"
ensure_recovery_dirs

if [[ -z "$BUNDLE_DIR" || ! -d "$BUNDLE_DIR" ]]; then
  echo "usage: request-acp-from-bundle.sh <bundle-dir>" >&2
  exit 1
fi

LAUNCH_FILE="$($SCRIPT_DIR/launch-acp-repair.sh "$BUNDLE_DIR")"
TASK_FILE="$($SCRIPT_DIR/prepare-acp-task.sh "$BUNDLE_DIR")"
REQUEST_ROOT="${AUTO_ACP_REQUEST_DIR:-$ROOT_DIR/state/auto-acp}"
mkdir -p "$REQUEST_ROOT/requests"
INCIDENT_ID="$(sha256_text "$BUNDLE_DIR" | cut -c1-16)"
REQUEST_FILE="$REQUEST_ROOT/requests/$(timestamp_local_slug)-bundle-${INCIDENT_ID}.json"

cat > "$REQUEST_FILE" <<JSON
{
  "createdAt": $(json_escape "$(timestamp_utc)"),
  "source": "bundle-replay",
  "bundleDir": $(json_escape "$BUNDLE_DIR"),
  "launchInstructions": $(json_escape "$LAUNCH_FILE"),
  "taskFile": $(json_escape "$TASK_FILE"),
  "incidentId": $(json_escape "$INCIDENT_ID"),
  "autoAcp": {
    "enabled": $([[ "${AUTO_ACP_ENABLED:-0}" == "1" ]] && echo true || echo false),
    "eligible": $([[ "${AUTO_ACP_ENABLED:-0}" == "1" ]] && echo true || echo false),
    "reason": $(json_escape "$([[ "${AUTO_ACP_ENABLED:-0}" == "1" ]] && echo eligible || echo disabled)"),
    "agentId": $(json_escape "${AUTO_ACP_AGENT_ID:-codex}"),
    "mode": $(json_escape "${AUTO_ACP_MODE:-run}"),
    "thread": $([[ "${AUTO_ACP_THREAD:-0}" == "1" ]] && echo true || echo false)
  }
}
JSON

DISPATCH_RECORD=""
BRIDGE_LOG=""
if [[ "${AUTO_ACP_ENABLED:-0}" == "1" ]]; then
  DISPATCH_RECORD="$($SCRIPT_DIR/auto-acp-dispatch.sh "$REQUEST_FILE")"
  if [[ -f "$DISPATCH_RECORD" ]]; then
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

printf '%s\n' "$REQUEST_FILE"
