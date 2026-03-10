# Production case study (sanitized)

## Summary
This reference project was extracted from a real production rollout of an external auto-recovery layer for OpenClaw Gateway.

## What was proven in production
- healthy state produced no recovery action
- external watcher could detect an unhealthy Gateway
- one-shot recovery core could restart the Gateway and return it to healthy
- result and event logs provided a usable audit trail

## Most important real-world bug
The first end-to-end production drill exposed an unloaded-service edge:
- the watcher detected failure correctly
- the recovery core invoked restart correctly
- but the restart wrapper failed when the main Gateway service had been booted out from launchd

In that state, `openclaw gateway start` alone was insufficient because the service was no longer loaded.

## Production-safe fix
The restart wrapper was updated so that:
- if the Gateway service is still present in launchd, use `openclaw gateway start`
- if the Gateway service is absent, bootstrap the existing LaunchAgent plist first

## Why this matters
This is exactly the kind of edge that makes recovery systems look complete on paper but fail in the field. The fix was small, but the drill was what made it visible.

## Remaining lessons
- keep recovery external to the main Gateway service chain
- prefer conservative health truth over noisy probes
- keep governance in place so repeated failures do not turn recovery into a fork bomb with opinions
