#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export OPENCLAW_RECOVERY_MODE="manual-one-shot"
exec "$ROOT_DIR/recover-gateway-v042.sh" "$@"
