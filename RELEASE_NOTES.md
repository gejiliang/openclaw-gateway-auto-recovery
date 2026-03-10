# Release notes

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
