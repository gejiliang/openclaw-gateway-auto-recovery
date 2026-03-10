# Mode B — target-local repair (pragmatic path)

## Summary
Mode B is the target-local ACP/Codex repair path.

In the ideal model, the target host would run the full ACP/Codex adapter chain locally. In practice, a pragmatic local Codex wrapper can be enough to make the mode usable before every adapter bridge is perfect.

## What was proven in a real Dev/Test VM
On `lab-openclaw` (`10.0.0.8`):
- local `acpx@0.1.15` was installed in an isolated project-local path
- local `codex` CLI was installed and authenticated
- direct local `codex exec --skip-git-repo-check ...` worked
- `acpx -> codex` bridging still had issues
- a pragmatic local Codex wrapper was used to consume a real repair bundle
- local Codex produced a valid minimal fix
- the fix was applied directly on the target host and verified

## Practical lesson
Mode B does not need to wait for perfect `acpx -> codex` adapter behavior to be useful.

If local Codex works and bundle/task generation works, a local wrapper can be an acceptable real-world bridge.

## Recommended readiness for Mode B
- local Node/npm/npx
- local Codex installed
- local Codex authenticated
- local repair bundle generation path
- local write/backup permissions for the repair target

## Current recommendation
Treat this as a pragmatic execution backend for target-local repair.
Do not over-productize it too early. If the local wrapper is enough for the real scenario, use it.
