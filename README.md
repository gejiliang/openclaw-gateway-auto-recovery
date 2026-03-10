# OpenClaw Gateway External Auto-Recovery

A sanitized reference implementation of an external auto-recovery layer for a local OpenClaw Gateway.

This repository captures the practical shape of a production-tested design: separate watcher, conservative health truth, restart governance, and day-2 operations docs.

## Why this exists
The goal is not to make Gateway immortal. The goal is to make local Gateway failures recoverable with:
- explicit health checks
- restart governance
- separate watcher logic
- auditable results and logs
- minimal coupling to the main Gateway LaunchAgent

## Design principles
- Keep recovery **external** to the main Gateway service chain.
- Do not replace the main Gateway LaunchAgent entrypoint with the recovery wrapper.
- Prefer conservative restart behavior with cooldown / rolling attempt limits.
- Treat `status --no-probe --json` as the primary health truth when deep probes are noisy.

## Repository layout
- `recovery/gateway-v04/`
  - reference recovery implementation
- `docs/`
  - runbook, operations, upgrade checklist, project notes
- `examples/`
  - example LaunchAgent plist and sanitized examples

## Core components
- `recover-gateway-v042.sh`
  - recovery core with governance, lock handling, classification, and result logging
- `bin/watch-gateway.sh`
  - separate periodic watcher entry
- `bin/check-gateway.sh`
  - primary health check
- `bin/start-gateway.sh` / `bin/stop-gateway.sh`
  - restart wrappers

## Health model
Primary truth is based on:
- `openclaw gateway status --no-probe --json`
- `service.loaded == true`
- `service.runtime.status == "running"`
- `service.configAudit.ok == true`
- `extraServices == []`
- listener PID matches runtime PID

Deep probe output and `openclaw health` are treated as auxiliary signals only.

## What this project intentionally does not do
- It does not patch OpenClaw itself.
- It does not change auth/bind behavior.
- It does not merge recovery into the main Gateway LaunchAgent.
- It does not claim every failure mode is safely auto-recoverable.

## Production note
This repository is a sanitized reference extracted from a real production rollout and drill. Host-specific paths, private config, tokens, and raw operational artifacts were intentionally excluded.

## Repo blurb templates
Need a short description for GitHub, social sharing, or internal forwarding? See `docs/REPO_BLURBS.md`.

## Start here
1. Read `docs/RUNBOOK.md`
2. Read `docs/ARCHITECTURE.md`
3. Read `docs/OPERATIONS.md`
4. Read `docs/POST_UPGRADE_CHECKLIST.md`
5. Optional Chinese overview: `docs/README.zh-CN.md`
6. Copy `recovery/gateway-v04/adapter.env.example` to your own local `adapter.env`
7. Review all host-specific paths before enabling anything
