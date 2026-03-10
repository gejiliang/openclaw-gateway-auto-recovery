#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

LAUNCH_TARGET="$(launchctl_target)"
LAUNCH_DOMAIN="gui/$(recovery_uid)"
PLIST_PATH="$HOME/Library/LaunchAgents/${SERVICE_LABEL}.plist"

if "$LAUNCHCTL_BIN" print "$LAUNCH_TARGET" >/dev/null 2>&1; then
  gateway_cmd start
  exit 0
fi

if [[ ! -f "$PLIST_PATH" ]]; then
  printf 'gateway launchd plist not found: %s\n' "$PLIST_PATH" >&2
  exit 1
fi

"$LAUNCHCTL_BIN" bootstrap "$LAUNCH_DOMAIN" "$PLIST_PATH"
