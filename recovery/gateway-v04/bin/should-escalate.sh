#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

RESULT_PATH="${1:-$RESULT_FILE}"

if [[ ! -f "$RESULT_PATH" ]]; then
  echo "missing-result"
  exit 1
fi

python3 - "$RESULT_PATH" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
term = data.get('terminal_state')
action = data.get('action')
status_after = data.get('status_after')

if term in ('failed', 'escalated', 'recoverer-error'):
    print('escalate')
    sys.exit(0)

if term == 'governed-skip' and status_after != 'healthy':
    print('escalate')
    sys.exit(0)

print('no-escalation')
PY
