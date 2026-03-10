# Mini Gateway auto-recovery post-upgrade checklist

Use this after any OpenClaw upgrade, dependency refresh, gateway reinstall, launchd regeneration, or manual service-chain change.

## Goal
Confirm that the external Gateway auto-recovery layer still matches current OpenClaw behavior and has not silently drifted.

## Fast mental model
There are two separate launchd jobs:
- main Gateway: `ai.openclaw.gateway`
- external recovery watcher: `ai.openclaw.gateway-recovery-watcher`

The recovery layer must remain external. Do not fold it into the main Gateway LaunchAgent entrypoint.

## 1. Verify both launchd jobs still exist
```bash
launchctl print gui/$UID/ai.openclaw.gateway
launchctl print gui/$UID/ai.openclaw.gateway-recovery-watcher
```
Expect:
- both labels resolvable
- gateway job loaded/running
- watcher job loaded/running

## 2. Verify gateway health contract still matches current OpenClaw output
```bash
openclaw gateway status --no-probe --json
```
Check that the following assumptions are still true:
- `service.loaded == true`
- `service.runtime.status == "running"`
- `service.configAudit.ok == true`
- `extraServices == []`
- listener PID still appears under `port.listeners[*].pid`

If OpenClaw changes any of these JSON fields, `bin/check-gateway.sh` may need adjustment.

## 3. Verify listener PID vs runtime PID logic still works
Compare:
- `service.runtime.pid`
- one of `port.listeners[*].pid`

These must still agree for healthy local Gateway detection.

## 4. Verify the probe-degraded downgrade still makes sense
Run:
```bash
openclaw gateway status --deep --json
openclaw health
```
Current design assumption:
- these may fail or be noisy
- they are auxiliary only
- primary truth is still `status --no-probe --json`

If future OpenClaw makes deep probe perfectly reliable, this design can stay conservative; no urgent change is required.

## 5. Verify main Gateway plist path still matches the recovery wrapper assumption
Current restart wrapper assumption:
- main plist path: `~/Library/LaunchAgents/ai.openclaw.gateway.plist`

Check:
```bash
ls -l ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```
If OpenClaw moves or renames this plist, update:
- `~/.openclaw/recovery/gateway-v04/bin/start-gateway.sh`

## 6. Verify unloaded-service bootstrap path still works
The key edge fixed during production drill was:
- when `ai.openclaw.gateway` has been booted out from launchd,
- `openclaw gateway start` alone may not reload it,
- wrapper must bootstrap the existing plist.

Re-read:
- `bin/start-gateway.sh`

Ensure this logic still matches current launchd/OpenClaw behavior.

## 7. Verify watcher cadence and logs still behave normally
Check:
```bash
tail -n 50 ~/.openclaw/recovery/gateway-v04/logs/watcher.log
tail -n 50 ~/.openclaw/recovery/gateway-v04/logs/recover-events.log
```
Expect:
- watcher periodically logs `healthy; no action`
- no repeated unhealthy loops
- no silent stderr spam unless there is a real failure

## 8. Run a no-risk smoke test
```bash
~/.openclaw/recovery/gateway-v04/bin/check-gateway.sh
~/.openclaw/recovery/gateway-v04/bin/recover-once.sh
```
Expect on healthy system:
- `check-gateway.sh` exits 0
- `recover-once.sh` returns `action=none` and `terminal_state=healthy`

## 9. Optional controlled drill
If the upgrade was meaningful and a maintenance window exists, run one controlled drill:
- stop or bootout the Gateway intentionally
- allow watcher to detect and recover
- confirm `status_after=healthy` and `terminal_state=recovered`

Do not spam drills back-to-back; governance may hit cooldown / attempt-limit by design.

## 10. Record the result
After upgrade verification, update:
- daily memory note
- any rollout doc if behavior changed
- this checklist if OpenClaw changed a contract

## If something broke
Start here:
1. `outputs/gateway-auto-recovery-drill-20260310T0955/final-summary.md`
2. `~/.openclaw/recovery/gateway-v04/RUNBOOK.md`
3. `outputs/gateway-project-index-20260310.md`

Then inspect:
- `results/last-result.json`
- `logs/recover-events.log`
- `logs/watcher.log`
- `logs/watcher.stderr.log`
