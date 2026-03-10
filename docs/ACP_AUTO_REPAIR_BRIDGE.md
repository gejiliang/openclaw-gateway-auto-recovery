# Gateway recovery A+B mode design (2026-03-10)

## Goal
Add both:
- Mode A: stronger explicit handoff after escalation
- Mode B: guarded automatic ACP/Codex invocation after escalation

## Why now
OpenClaw 2026.3.8 proved that recovery-layer drift can create a failure mode where:
- watcher detects failure repeatedly
- bundle generation is possible
- Codex would help
- but current design stops at explicit human-triggered spawn

G requested both the safer handoff improvements and a guarded auto-Codex path.

## Design split

### Mode A — richer explicit handoff
On escalation-worthy outcomes, the recovery layer should automatically:
1. decide escalation
2. generate repair bundle
3. generate ACP launch instructions
4. generate ACP task payload text
5. write a small machine-readable manifest describing bundle + task paths

This keeps manual/operator-triggered repair fast and low-friction.

### Mode B — guarded auto-Codex spawn
On escalation-worthy outcomes, the recovery layer may auto-spawn an ACP Codex run only when all guards pass.

## Guardrails for Mode B
Auto-spawn is allowed only if all are true:
1. terminal state is one of: `failed`, `escalated`, `recoverer-error`, or governed-skip with non-healthy after-state
2. a repair bundle was generated successfully
3. an ACP task file was generated successfully
4. ACP backend looks available enough to attempt a spawn
5. no recent auto-spawn exists within cooldown window
6. per-incident cap not exceeded
7. operator has enabled auto-spawn explicitly in adapter config/env

## Initial implementation policy
- default: disabled
- enable by adapter/env switch only
- one auto-spawn at a time
- one auto-spawn per bundle/incident fingerprint
- cooldown window required
- use one-shot ACP run, not persistent thread, for the first implementation
- default agent: `codex`
- task payload comes from generated `10-acp-task.txt`

## Persistence / artifacts
New files under recovery root:
- `state/auto-acp/` for cooldown + incident markers
- bundle manifest file containing:
  - bundle dir
  - launch instructions path
  - task file path
  - auto-spawn eligibility
  - auto-spawn attempt/result if any

## Why auto-spawn did not happen before
Because v0.3 intentionally stopped at explicit operator-triggered ACP launch. The watcher was not designed to call `sessions_spawn` or any equivalent runtime launcher on its own.

## Implementation shape
1. Add a helper script to finalize escalation artifacts and optionally request auto-spawn.
2. For now, do not call OpenClaw tools from shell scripts directly via hidden internal APIs.
3. Instead, use the supported ACP runtime path where possible; if direct runtime invocation from shell is awkward, phase 1 can still prepare all artifacts plus an auto-spawn request record.
4. If runtime invocation from shell is feasible and stable, wire guarded one-shot auto-spawn.

## Phaseing
- Phase 1: land A completely + land B control plane and guard state
- Phase 2: if shell->ACP runtime call is stable on this host, enable actual auto-spawn path

## Non-goals
- no silent persistent ACP thread sessions yet
- no multiple-agent fanout
- no automatic code-apply permission expansion
- no bypass of recovery governance
