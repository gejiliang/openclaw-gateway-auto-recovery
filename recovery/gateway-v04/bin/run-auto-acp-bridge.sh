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
BRIDGE_LOG_DIR="$REQUEST_ROOT/bridge-logs"
mkdir -p "$RUNS_DIR" "$BRIDGE_LOG_DIR"

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

INCIDENT_ID="$(read_json_field incidentId)"
TASK_FILE="$(read_json_field taskFile)"
AGENT_ID="$(read_json_field autoAcp.agentId)"
RUN_RECORD="$(read_json_field autoAcp.dispatchRecord)"
STATUS="$(read_json_field autoAcp.dispatchStatus)"
MODE="${AUTO_ACP_BRIDGE_MODE:-acpx}"
ACPX_CMD="${AUTO_ACP_ACPX_CMD:-/opt/homebrew/lib/node_modules/openclaw/extensions/acpx/node_modules/.bin/acpx}"
CODEX_CMD="${AUTO_ACP_CODEX_CMD:-codex}"
ACP_CWD="${AUTO_ACP_CWD:-$ROOT_DIR}"
TIMEOUT_SECONDS="${AUTO_ACP_TIMEOUT_SECONDS:-900}"

if [[ "$STATUS" != "requested" ]]; then
  echo "request not runnable: $STATUS" >&2
  exit 1
fi

if [[ ! -f "$TASK_FILE" ]]; then
  echo "missing task file: $TASK_FILE" >&2
  exit 1
fi

LOG_FILE="$BRIDGE_LOG_DIR/${INCIDENT_ID}.log"
OUT_FILE="$BRIDGE_LOG_DIR/${INCIDENT_ID}.out.txt"
ERR_FILE="$BRIDGE_LOG_DIR/${INCIDENT_ID}.err.txt"
RESULT_STATUS="failed"
RESULT_REASON="unsupported-bridge-mode"
TIMEOUT_WRAPPER=""
if [[ -n "${TIMEOUT_BIN:-}" && -x "${TIMEOUT_BIN:-}" ]]; then
  TIMEOUT_WRAPPER="$TIMEOUT_BIN"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_WRAPPER="$(command -v gtimeout)"
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_WRAPPER="$(command -v timeout)"
fi

if [[ "$MODE" == "acpx" ]]; then
  if [[ ! -x "$ACPX_CMD" ]]; then
    RESULT_REASON="missing-acpx-cmd"
  elif [[ "$AGENT_ID" != "codex" ]]; then
    RESULT_REASON="acpx-bridge-currently-codex-only"
  else
    if [[ -n "$TIMEOUT_WRAPPER" ]]; then
      if (cd "$ACP_CWD" && "$TIMEOUT_WRAPPER" "$TIMEOUT_SECONDS" "$ACPX_CMD" codex exec -f "$TASK_FILE") >"$OUT_FILE" 2>"$ERR_FILE"; then
        RESULT_STATUS="completed"
        RESULT_REASON="acpx-exec-ok"
      else
        rc=$?
        if grep -q "Authentication required" "$ERR_FILE" "$OUT_FILE" 2>/dev/null; then
          if (cd "$ACP_CWD" && "$TIMEOUT_WRAPPER" "$TIMEOUT_SECONDS" "$CODEX_CMD" exec --skip-git-repo-check "$(cat "$TASK_FILE")") >"$OUT_FILE" 2>"$ERR_FILE"; then
            RESULT_STATUS="completed"
            RESULT_REASON="codex-fallback-ok-after-acpx-auth"
          else
            rc=$?
            RESULT_STATUS="failed"
            RESULT_REASON="codex-fallback-exit-$rc"
          fi
        else
          RESULT_STATUS="failed"
          RESULT_REASON="acpx-exec-exit-$rc"
        fi
      fi
    else
      if (cd "$ACP_CWD" && "$ACPX_CMD" codex exec -f "$TASK_FILE") >"$OUT_FILE" 2>"$ERR_FILE"; then
        RESULT_STATUS="completed"
        RESULT_REASON="acpx-exec-ok-no-timeout-wrapper"
      else
        rc=$?
        if grep -q "Authentication required" "$ERR_FILE" "$OUT_FILE" 2>/dev/null; then
          if (cd "$ACP_CWD" && "$CODEX_CMD" exec --skip-git-repo-check "$(cat "$TASK_FILE")") >"$OUT_FILE" 2>"$ERR_FILE"; then
            RESULT_STATUS="completed"
            RESULT_REASON="codex-fallback-ok-after-acpx-auth-no-timeout-wrapper"
          else
            rc=$?
            RESULT_STATUS="failed"
            RESULT_REASON="codex-fallback-exit-$rc"
          fi
        else
          RESULT_STATUS="failed"
          RESULT_REASON="acpx-exec-exit-$rc"
        fi
      fi
    fi
  fi
fi

cat > "$LOG_FILE" <<JSON
{
  "createdAt": $(json_escape "$(timestamp_utc)"),
  "requestFile": $(json_escape "$REQUEST_FILE"),
  "runRecord": $(json_escape "$RUN_RECORD"),
  "incidentId": $(json_escape "$INCIDENT_ID"),
  "bridgeMode": $(json_escape "$MODE"),
  "agentId": $(json_escape "$AGENT_ID"),
  "cwd": $(json_escape "$ACP_CWD"),
  "taskFile": $(json_escape "$TASK_FILE"),
  "status": $(json_escape "$RESULT_STATUS"),
  "reason": $(json_escape "$RESULT_REASON"),
  "stdoutFile": $(json_escape "$OUT_FILE"),
  "stderrFile": $(json_escape "$ERR_FILE")
}
JSON

if [[ -n "$RUN_RECORD" && -f "$RUN_RECORD" ]]; then
  python3 - "$RUN_RECORD" "$LOG_FILE" "$RESULT_STATUS" "$RESULT_REASON" <<'PY'
import json, sys
path, log_file, status, reason = sys.argv[1:5]
with open(path, 'r', encoding='utf-8') as f:
    d = json.load(f)
d['bridgeLog'] = log_file
d['bridgeStatus'] = status
d['bridgeReason'] = reason
with open(path, 'w', encoding='utf-8') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
PY
fi

printf '%s\n' "$LOG_FILE"
