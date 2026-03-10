#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ensure_recovery_dirs

WATCHER_LOG="$ROOT_DIR/logs/watcher.log"
CHECK_TS="$(timestamp_utc)"

if "$SCRIPT_DIR/check-gateway.sh" >/dev/null 2>&1; then
  printf '%s [gateway-watch] healthy; no action\n' "$CHECK_TS" >> "$WATCHER_LOG"
  exit 0
fi

printf '%s [gateway-watch] unhealthy detected; invoking recover-once\n' "$CHECK_TS" | tee -a "$WATCHER_LOG" >> "$EVENT_FILE"
"$SCRIPT_DIR/recover-once.sh" >> "$WATCHER_LOG" 2>&1
