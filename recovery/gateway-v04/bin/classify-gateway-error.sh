#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ensure_recovery_dirs

latest_cli_log="$(latest_cli_file_log)"
haystack=""

append_file_tail() {
  local file_path="$1"
  if [[ -f "$file_path" ]]; then
    haystack+=$'\n'
    haystack+="$("$TAIL_BIN" -n "$RECOVER_LOG_TAIL_LINES" "$file_path" 2>/dev/null || true)"
  fi
}

append_file_tail "$GATEWAY_ERR_LOG"
append_file_tail "$GATEWAY_LOG"
if [[ -n "$latest_cli_log" ]]; then
  append_file_tail "$latest_cli_log"
fi

haystack+=$'\n'
haystack+="$(gateway_cmd status --deep 2>&1 || true)"

haystack_lower="$(printf '%s' "$haystack" | tr '[:upper:]' '[:lower:]')"

if printf '%s\n' "$haystack_lower" | grep -Eq 'eaddrinuse|address already in use|port [0-9]+ is already in use|already listening on ws://|gateway already running locally'; then
  printf 'port-conflict\n'
  exit 0
fi

if printf '%s\n' "$haystack_lower" | grep -Eq 'config validation failed|gateway start blocked: set gateway.mode=local|refusing to bind .* without auth|invalid config|failed to parse config|config .* error'; then
  printf 'config-error\n'
  exit 0
fi

if printf '%s\n' "$haystack_lower" | grep -Eq 'failed to load plugin|cannot find module|module not found|missing dependency|failed to load from'; then
  printf 'plugin-or-dependency\n'
  exit 0
fi

if printf '%s\n' "$haystack_lower" | grep -Eq 'error|exception|fatal|panic'; then
  printf 'generic-runtime-error\n'
  exit 0
fi

printf 'unknown\n'
