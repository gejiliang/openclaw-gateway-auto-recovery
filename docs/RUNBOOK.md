# Runbook

This repository contains a sanitized reference version of a live external recovery layer for OpenClaw Gateway.

## Operating model
- Main Gateway remains managed by its normal LaunchAgent.
- Recovery remains external.
- A separate watcher periodically checks health and triggers one-shot recovery when needed.

## Key behaviors
- healthy => no action
- failed + restart-eligible => attempt recovery
- repeated failures => cooldown / rolling attempt governance
- config / port-conflict style cases => escalate or collect evidence instead of blindly restarting

## Important known edge
If the main Gateway service has been booted out from launchd, a restart wrapper may need to bootstrap the existing plist instead of only calling `openclaw gateway start`.

This edge was critical in the original production drill.

## Files to read next
- `OPERATIONS.md`
- `POST_UPGRADE_CHECKLIST.md`
