#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ensure_recovery_dirs

sample_file="$(sample_file_path port-conflict)"
latest_cli_log="$(latest_cli_file_log)"

{
  printf '# OpenClaw Gateway port conflict sample\n'
  printf 'timestamp_utc=%s\n' "$(timestamp_utc)"
  printf 'service_label=%s\n' "$SERVICE_LABEL"
  printf 'port=%s\n' "$GATEWAY_PORT"

  printf '\n## listener %s\n' "$GATEWAY_PORT"
  "$LSOF_BIN" -nP -iTCP:"$GATEWAY_PORT" 2>&1 || true

  printf '\n## launchctl print %s\n' "$(launchctl_target)"
  "$LAUNCHCTL_BIN" print "$(launchctl_target)" 2>&1 || true

  printf '\n## gateway status --deep\n'
  gateway_cmd status --deep 2>&1 || true

  printf '\n## gateway.err.log tail\n'
  if [[ -f "$GATEWAY_ERR_LOG" ]]; then
    "$TAIL_BIN" -n "$RECOVER_LOG_TAIL_LINES" "$GATEWAY_ERR_LOG" 2>&1 || true
  else
    printf 'missing: %s\n' "$GATEWAY_ERR_LOG"
  fi

  printf '\n## latest cli file log tail\n'
  if [[ -n "$latest_cli_log" ]] && [[ -f "$latest_cli_log" ]]; then
    printf 'path=%s\n' "$latest_cli_log"
    "$TAIL_BIN" -n "$RECOVER_LOG_TAIL_LINES" "$latest_cli_log" 2>&1 || true
  else
    printf 'missing latest cli file log in %s\n' "$CLI_FILE_LOG_DIR"
  fi
} > "$sample_file"

printf '%s\n' "$sample_file"
