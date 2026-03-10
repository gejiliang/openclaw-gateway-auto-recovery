#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

BUNDLE_DIR="${1:-}"
ACP_AGENT_ID="${ACP_AGENT_ID:-codex}"

if [[ -z "$BUNDLE_DIR" ]]; then
  echo "usage: launch-acp-repair.sh <bundle-dir>" >&2
  exit 1
fi

if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "bundle dir not found: $BUNDLE_DIR" >&2
  exit 1
fi

PROMPT_FILE="$BUNDLE_DIR/08-acp-prompt.md"
MANIFEST_FILE="$BUNDLE_DIR/09-acp-launch-instructions.md"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "missing prompt file: $PROMPT_FILE" >&2
  exit 1
fi

cat > "$MANIFEST_FILE" <<EOF
# ACP launch instructions

## Recommended OpenClaw ACP session spawn
Use an ACP harness session with:
- runtime: acp
- agentId: $ACP_AGENT_ID
- mode: run (or session if you want persistence)

## Suggested task payload
Read the repair bundle at:
$BUNDLE_DIR

Then follow the prompt in:
$PROMPT_FILE

Required bundle files:
- 01-last-result.json
- 02-recover-events.log
- 03-watcher.log
- 04-watcher.stderr.log
- 05-gateway-status.json
- 06-launchctl-gateway.txt
- 07-launchctl-watcher.txt
- 08-acp-prompt.md

## Suggested human/agent action
Spawn an ACP Codex session and attach this bundle directory as context.
EOF

printf '%s\n' "$MANIFEST_FILE"
