# v0.2.0 — ACP handoff and explicit spawn helpers

This update extends the original external Gateway auto-recovery reference with a layered ACP escalation path.

## Added
- `bin/should-escalate.sh`
- `bin/generate-acp-repair-bundle.sh`
- `bin/launch-acp-repair.sh`
- `bin/prepare-acp-task.sh`
- `docs/ACP_HANDOFF.md`

## What this enables
- decide whether a recovery outcome should escalate
- generate a structured ACP repair bundle
- generate ACP launch instructions for a bundle
- prepare ACP task payload text from a bundle
- support explicit operator-triggered ACP Codex runtime spawn

## Validation
- local Mini-side generation path verified
- Dev/Test VM (`lab-openclaw` / `10.0.0.8`) verified for:
  - escalation decision
  - repair bundle generation
  - ACP task preparation
  - explicit ACP Codex runtime spawn acceptance

## Important boundary
This release still intentionally avoids silent watcher-triggered ACP auto-spawn. ACP launch remains an explicit operator action.
