#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ensure_recovery_dirs

ESCALATIONS_DIR="$ROOT_DIR/escalations"
mkdir -p "$ESCALATIONS_DIR"
BUNDLE_DIR="$ESCALATIONS_DIR/$(timestamp_local_slug)"
mkdir -p "$BUNDLE_DIR"

cp "$RESULT_FILE" "$BUNDLE_DIR/01-last-result.json" 2>/dev/null || printf '{}' > "$BUNDLE_DIR/01-last-result.json"
"$TAIL_BIN" -n 200 "$EVENT_FILE" > "$BUNDLE_DIR/02-recover-events.log" 2>/dev/null || true
"$TAIL_BIN" -n 200 "$ROOT_DIR/logs/watcher.log" > "$BUNDLE_DIR/03-watcher.log" 2>/dev/null || true
"$TAIL_BIN" -n 200 "$ROOT_DIR/logs/watcher.stderr.log" > "$BUNDLE_DIR/04-watcher.stderr.log" 2>/dev/null || true
gateway_cmd status --no-probe --json > "$BUNDLE_DIR/05-gateway-status.json" 2>&1 || true
"$LAUNCHCTL_BIN" print "$(launchctl_target)" > "$BUNDLE_DIR/06-launchctl-gateway.txt" 2>&1 || true
"$LAUNCHCTL_BIN" print "gui/$(recovery_uid)/ai.openclaw.gateway-recovery-watcher" > "$BUNDLE_DIR/07-launchctl-watcher.txt" 2>&1 || true

cat > "$BUNDLE_DIR/08-acp-prompt.md" <<EOF
You are diagnosing a failed or escalated Gateway recovery event.

Goal:
- determine why automatic recovery did not return the local OpenClaw Gateway to healthy state
- make the smallest safe fix
- verify recovery success

Boundaries:
- do not replace the main Gateway LaunchAgent entrypoint
- do not disable auth or weaken bind/security settings
- prefer minimal, reversible changes
- respect existing cooldown/attempt governance unless the bug is in that governance

Read these bundle files first:
- 01-last-result.json
- 02-recover-events.log
- 03-watcher.log
- 04-watcher.stderr.log
- 05-gateway-status.json
- 06-launchctl-gateway.txt
- 07-launchctl-watcher.txt

Deliver:
1. root cause
2. smallest safe patch
3. verification commands run
4. final outcome
EOF

python3 - "$BUNDLE_DIR" <<'PY' > "$BUNDLE_DIR/bundle-summary.json"
import json, os, sys
bundle = sys.argv[1]
summary = {
  "bundleDir": bundle,
  "createdAt": os.path.basename(bundle),
  "files": sorted(os.listdir(bundle)),
  "purpose": "Gateway ACP repair escalation bundle"
}
print(json.dumps(summary, indent=2))
PY

printf '%s\n' "$BUNDLE_DIR"
