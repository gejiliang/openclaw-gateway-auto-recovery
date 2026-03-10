#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="${1:-}"
OUT_FILE="${2:-}"

if [[ -z "$BUNDLE_DIR" ]]; then
  echo "usage: prepare-acp-task.sh <bundle-dir> [out-file]" >&2
  exit 1
fi

if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "bundle dir not found: $BUNDLE_DIR" >&2
  exit 1
fi

PROMPT_FILE="$BUNDLE_DIR/08-acp-prompt.md"
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "missing prompt file: $PROMPT_FILE" >&2
  exit 1
fi

TMP_OUT="${OUT_FILE:-$BUNDLE_DIR/10-acp-task.txt}"

cat > "$TMP_OUT" <<EOF
You are working on a Gateway repair task.

Read and use the repair bundle at:
$BUNDLE_DIR

Start by reading these files from the bundle:
- 01-last-result.json
- 02-recover-events.log
- 03-watcher.log
- 04-watcher.stderr.log
- 05-gateway-status.json
- 06-launchctl-gateway.txt
- 07-launchctl-watcher.txt
- 08-acp-prompt.md

Then follow the instructions in 08-acp-prompt.md exactly.

Deliver:
1. root cause
2. smallest safe patch
3. verification commands run
4. final outcome
EOF

printf '%s\n' "$TMP_OUT"
