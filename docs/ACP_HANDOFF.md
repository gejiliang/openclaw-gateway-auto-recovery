# ACP handoff and explicit spawn

## Overview
This project now supports a layered escalation path on top of the base Gateway recovery line.

## v0.2 — ACP handoff bundle layer
Added helpers:
- `bin/should-escalate.sh`
- `bin/generate-acp-repair-bundle.sh`
- `bin/launch-acp-repair.sh`

Purpose:
- decide when recovery failure should escalate
- package evidence and prompt materials into a structured repair bundle
- generate a near-zero-friction ACP launch instruction file

## v0.3 — explicit ACP runtime spawn layer
Added helper:
- `bin/prepare-acp-task.sh`

Purpose:
- convert a repair bundle into ACP task payload text
- support explicit operator-triggered ACP runtime spawn

## Current boundary
Supported:
- automatic recovery
- structured ACP escalation bundle generation
- explicit operator-triggered ACP runtime spawn
- guarded automatic bridge execution
- pragmatic target-local repair via local Codex fallback when direct adapter bridging hits auth-context mismatch

Intentionally avoided:
- silent watcher-triggered ACP session spawn without governance
- hidden OpenClaw tool-runtime calls from shell scripts pretending to be first-class tools

## Recommended operator flow
1. let governed recovery run first
2. if needed, run `bin/should-escalate.sh`
3. if escalation is appropriate, run `bin/generate-acp-repair-bundle.sh`
4. optionally run `bin/launch-acp-repair.sh <bundle-dir>`
5. run `bin/prepare-acp-task.sh <bundle-dir>`
6. explicitly launch an ACP Codex session using the prepared task text

## Test-environment validation
The same ACP handoff layers were validated in a Dev/Test VM (a Dev/Test VM), including explicit ACP Codex runtime spawn acceptance.
