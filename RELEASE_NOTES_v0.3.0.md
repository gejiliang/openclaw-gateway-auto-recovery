# v0.3.0 — pragmatic Mode B local repair path

This release clarifies and documents the next practical step after the ACP handoff / explicit spawn helpers: a usable target-local repair path.

## Added
- `docs/MODE_B_LOCAL_REPAIR.md`

## Updated
- `README.md`
- `docs/ACP_HANDOFF.md`

## What this release means

The repository now documents a pragmatic version of **Mode B**:
- target-local repair on the affected host
- local Codex as a practical execution backend
- no requirement to wait for perfect `acpx -> codex` bridge behavior before the workflow becomes useful

## Key message

If local Codex works, local authentication is prepared, and repair-bundle/task generation works, then target-local repair is already operationally meaningful.

That is different from claiming that every adapter bridge is perfect.
The point of this release is realism over architecture cosplay.

## Validation basis

Documented from the real Dev/Test VM path (`lab-openclaw` / `10.0.0.8`):
- local `acpx` installed in project-local path
- local `codex` installed and authenticated
- direct local `codex exec --skip-git-repo-check` succeeded
- `acpx -> codex` bridging was still imperfect
- pragmatic local wrapper path still consumed a real repair bundle and produced a valid minimal fix

## Important boundary

This release still does **not** claim:
- silent watcher-triggered hidden coding-agent execution
- fully automatic repair governance beyond the documented recovery boundary
- universal adapter perfection

It does claim something more useful:
- the target-local repair path is practical enough to use when prepared intentionally
