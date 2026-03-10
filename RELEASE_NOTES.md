# Release notes

## v0.3.0 — pragmatic Mode B local repair path

This release clarifies and documents the next practical step after the ACP handoff / explicit spawn helpers: a usable target-local repair path.

### Added
- `docs/MODE_B_LOCAL_REPAIR.md`

### Updated
- `README.md`
- `docs/ACP_HANDOFF.md`

### What this release means
- documents a practical Mode B target-local repair path
- treats local Codex as a valid execution backend when intentionally prepared
- avoids pretending imperfect adapter bridges make the whole design unusable

### Important boundary
- still no silent watcher-triggered hidden coding-agent execution
- still no claim of universal adapter perfection
- still keeps recovery governance separate from repair-agent governance

## v0.1.0 — initial public reference release

This initial release contains a sanitized reference implementation of an external auto-recovery layer for OpenClaw Gateway.

### Included
- reference recovery core
- separate watcher entry
- health-check logic
- restart wrapper handling for unloaded-service launchd edge
- operations doc
- post-upgrade checklist
- sanitized production case study

### Excluded on purpose
- private config
- tokens / auth material
- raw production logs
- personal host-specific rollout artifacts

### Recommended GitHub repo description
External auto-recovery reference for local OpenClaw Gateway: health checks, watcher loop, restart governance, and operations docs.
