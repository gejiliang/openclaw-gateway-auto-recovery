# OpenClaw Gateway Recovery v0.4.x for Mini

This directory is the live Mini production recovery framework for
Gateway v0.4.x governance.

Current status:
- Recovery directory is present on disk and is now in active production use as an external recovery layer
- Manual one-shot validation succeeded
- Synthetic recovered-state closure succeeded
- Separate automated watcher is enabled via launchd: `ai.openclaw.gateway-recovery-watcher`
- Main Gateway LaunchAgent remains separate and unchanged: `ai.openclaw.gateway`
- End-to-end controlled production drill has succeeded

Contents:
- `adapter.env`: Mini-specific paths, port, service label, and recovery output locations
- `recover-gateway-v042.sh`: config-driven recovery core with cooldown, attempt limit, lock-skip, collector/classifier tolerance, and escalation branches
- `bin/*.sh`: Mini adapter scripts, watcher entry, manual one-shot entry, and ACP escalation helpers
- `logs/`: event log + attempt log destination
- `results/`: recovery result JSON destination
- `samples/`: collected state / port conflict evidence
- `locks/`: lockdir root for the mkdir-based recovery lock
- `escalations/`: generated ACP repair bundles for failed/escalated recovery events

Important boundaries:
- Do not repoint the live Gateway LaunchAgent at this directory.
- Do not replace the current running Gateway entrypoint with `recover-once.sh`.
- Prefer a separate watcher LaunchAgent over any in-process Gateway entrypoint swap.

Operating model:
1. Gateway itself remains managed by `ai.openclaw.gateway` / `openclaw gateway start|stop`.
2. `bin/recover-once.sh` remains the manual one-shot recovery entry.
3. `bin/watch-gateway.sh` is the periodic external watcher entry used by the separate `ai.openclaw.gateway-recovery-watcher` LaunchAgent.
4. Keep the watcher independent from the main Gateway service chain so rollback stays trivial.

Recommended verification now:
- `bin/status-gateway.sh`
- review `adapter.env`
- confirm `launchctl print gui/$UID/ai.openclaw.gateway`
- confirm `launchctl print gui/$UID/ai.openclaw.gateway-recovery-watcher`
- confirm `openclaw gateway status --json`
- inspect `results/last-result.json`
- inspect `logs/recover-events.log` and `logs/watcher.log`

Important 2026.3.8 compatibility note:
- older recovery logic depended on `openclaw gateway status --no-probe --json`
- OpenClaw 2026.3.8 removed or changed that contract for this path
- recovery scripts must capture JSON from stdout only and treat stderr warnings separately
- if post-upgrade behavior looks wrong, suspect recovery-layer CLI drift before assuming the Gateway binary itself is broken

Important known fix:
- `bin/start-gateway.sh` must bootstrap `~/Library/LaunchAgents/ai.openclaw.gateway.plist` when the main gateway service has been booted out from launchd. This was the key unloaded-service edge exposed by the first end-to-end drill.

ACP escalation / explicit ACP spawn status:
- `bin/should-escalate.sh` determines whether a recovery result should hand off to ACP/Codex
- `bin/generate-acp-repair-bundle.sh` creates a structured escalation bundle under `escalations/<timestamp>/`
- `bin/launch-acp-repair.sh` generates a near-zero-friction ACP launch instruction file for a chosen bundle
- `bin/prepare-acp-task.sh` prepares task payload text for explicit OpenClaw ACP runtime spawn
- `bin/finalize-acp-handoff.sh` now prepares the full A-mode handoff package automatically for escalation-worthy outcomes
- `bin/auto-acp-dispatch.sh` adds guarded B-mode dispatch control (cooldown, dedup, rolling-window limits)
- default posture remains conservative: auto-ACP is off unless `AUTO_ACP_ENABLED=1`
- current implementation supports automatic preparation + guarded dispatch records
- current bridge strategy is now explicitly: acpx first, then direct `codex exec` fallback on `Authentication required`
- this fallback is not theoretical; it was validated in the test environment and is now part of the operational design boundary

Companion docs:
- `POST_UPGRADE_CHECKLIST.md` — run after OpenClaw upgrades or launchd/service-chain changes
- `OPERATIONS.md` — day-2 operations and incident handling SOP
- workspace rollup: `outputs/gateway-acp-handoff-rollup-20260310.md` — phase summary for v0.2/v0.3 ACP handoff work
