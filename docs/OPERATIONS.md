# Mini Gateway auto-recovery operations SOP

## What this system is
An external recovery layer for the local OpenClaw Gateway on Mini.

It consists of:
- main Gateway LaunchAgent: `ai.openclaw.gateway`
- separate watcher LaunchAgent: `ai.openclaw.gateway-recovery-watcher`
- recovery scripts under `~/.openclaw/recovery/gateway-v04`

## What not to do
- Do not replace the main Gateway LaunchAgent entrypoint with the recovery wrapper.
- Do not merge watcher behavior into the Gateway job.
- Do not disable auth or alter bind mode as a shortcut for recovery.
- Do not panic-restart repeatedly; governance exists for a reason.

## Normal health checks
```bash
openclaw gateway status --json
~/.openclaw/recovery/gateway-v04/bin/check-gateway.sh
launchctl print gui/$UID/ai.openclaw.gateway
launchctl print gui/$UID/ai.openclaw.gateway-recovery-watcher
```

Compatibility note after OpenClaw 2026.3.8:
- do not assume `--no-probe` remains valid on future versions
- recovery JSON checks should prefer stdout-only capture and keep stderr warnings out of the JSON parse path
- if watcher suddenly begins false unhealthy loops after an upgrade, check CLI contract drift first

## Important logs
- watcher:
  - `~/.openclaw/recovery/gateway-v04/logs/watcher.log`
  - `~/.openclaw/recovery/gateway-v04/logs/watcher.stderr.log`
  - `~/.openclaw/recovery/gateway-v04/logs/watcher.stdout.log`
- recovery core:
  - `~/.openclaw/recovery/gateway-v04/logs/recover-events.log`
  - `~/.openclaw/recovery/gateway-v04/results/last-result.json`
- main Gateway:
  - `~/.openclaw/logs/gateway.log`
  - `~/.openclaw/logs/gateway.err.log`

## Healthy-state expectation
- gateway loaded/running
- watcher loaded/running
- watcher periodically records `healthy; no action`
- latest result is either historical recovered state or healthy/no-op state

## Manual one-shot recovery
```bash
~/.openclaw/recovery/gateway-v04/bin/recover-once.sh
```
Use when:
- diagnosing behavior
- validating after maintenance
- performing a no-risk smoke test on a healthy system

## If Gateway is down and watcher did not recover it
1. Check current state:
```bash
openclaw gateway status --json
launchctl print gui/$UID/ai.openclaw.gateway
launchctl print gui/$UID/ai.openclaw.gateway-recovery-watcher
```
2. Read recovery evidence:
```bash
cat ~/.openclaw/recovery/gateway-v04/results/last-result.json
tail -n 100 ~/.openclaw/recovery/gateway-v04/logs/recover-events.log
tail -n 100 ~/.openclaw/recovery/gateway-v04/logs/watcher.log
tail -n 100 ~/.openclaw/recovery/gateway-v04/logs/watcher.stderr.log
```
3. If needed, run manual one-shot recovery once.
4. If the issue appears code-related, first check whether the latest result should escalate:
```bash
~/.openclaw/recovery/gateway-v04/bin/should-escalate.sh
```
5. If escalation is appropriate, generate an ACP repair bundle:
```bash
~/.openclaw/recovery/gateway-v04/bin/generate-acp-repair-bundle.sh
```
6. Use the generated bundle directory as the handoff package for Codex/ACP. The bundle contains logs, current status, launchd state, an ACP-ready prompt markdown file, and a handoff manifest.
7. If you want a single helper to prepare all handoff artifacts, run:
```bash
~/.openclaw/recovery/gateway-v04/bin/finalize-acp-handoff.sh
```
This will generate:
- repair bundle
- ACP launch instructions
- ACP task payload text
- `11-handoff-manifest.json`
- optional guarded auto-ACP request/dispatch record when enabled
8. If you want a cleaner ACP handoff entry from an existing bundle, generate ACP launch instructions from the bundle:
```bash
~/.openclaw/recovery/gateway-v04/bin/launch-acp-repair.sh <bundle-dir>
```
9. For explicit ACP runtime spawn, first prepare task text from the bundle:
```bash
~/.openclaw/recovery/gateway-v04/bin/prepare-acp-task.sh <bundle-dir>
```
Then launch an ACP Codex run from OpenClaw with that task text as the payload.

10. For guarded automatic bridge execution, current policy is:
- try `acpx codex exec` first
- if execution fails with `Authentication required`, fallback to direct local Codex:
```bash
codex exec --skip-git-repo-check "$(cat <task-file>)"
```
This fallback was validated in the test environment and is now part of the supported operational path.

Important boundary:
- failed or escalated recovery now automatically prepares bundle + launch instructions + ACP task payload + handoff manifest
- optional auto-ACP request/dispatch control now exists behind adapter flags
- default behavior is still conservative unless `AUTO_ACP_ENABLED=1`
- current implementation records guarded auto-ACP dispatch intent with cooldown/dedup governance
- bridge execution policy is now: try `acpx` first; if stderr/stdout indicates `Authentication required`, automatically fallback to direct local `codex exec --skip-git-repo-check`
- fully silent shell-side ACP runtime spawn remains intentionally bounded to this guarded bridge design rather than pretending OpenClaw tool-runtime calls are available inside shell scripts
9. Legacy fallback prompt still exists here if needed:
- `outputs/gateway-auto-recovery-drill-20260310T0955/codex-fallback-prompt.md`

## If you need to disable watcher temporarily
```bash
launchctl bootout gui/$UID/ai.openclaw.gateway-recovery-watcher
```
Re-enable:
```bash
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/ai.openclaw.gateway-recovery-watcher.plist
launchctl enable gui/$UID/ai.openclaw.gateway-recovery-watcher
launchctl kickstart -k gui/$UID/ai.openclaw.gateway-recovery-watcher
```

## If you need to verify main unloaded-service recovery edge
The known special case is when the main Gateway service has been booted out from launchd. In that path, `bin/start-gateway.sh` must bootstrap `~/Library/LaunchAgents/ai.openclaw.gateway.plist`.

If this edge breaks again, inspect:
- `bin/start-gateway.sh`
- launchd plist path
- `openclaw gateway start` behavior on current version

## Governance reminder
Cooldown and rolling attempt limits are intentional. During repeated drills or repeated failures, governed-skip results are not automatically bugs.

## Env-backed provider reminder
If Gateway or its recovery path depends on env-backed secrets, validation is not complete just because the current interactive shell can see them.

You must also verify the real restart/bootstrap path can resolve the secret.

A production example was `KIMI_API_KEY`:
- shell-visible env alone was not enough
- the LaunchAgent / launchd bootstrap path also had to inherit or recover the variable
- startup wrappers may need a small runtime-secret recovery step before restarting Gateway
