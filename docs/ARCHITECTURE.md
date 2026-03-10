# Architecture

```text
+---------------------------------------------------+
| launchd                                           |
|                                                   |
|  ai.openclaw.gateway                              |
|    └─ main OpenClaw Gateway service               |
|                                                   |
|  ai.openclaw.gateway-recovery-watcher             |
|    └─ watch-gateway.sh                            |
+--------------------------+------------------------+
                           |
                           | periodic health check
                           v
                 +------------------------+
                 | check-gateway.sh       |
                 |                        |
                 | primary truth:         |
                 | status --no-probe json |
                 | + runtime/listener PID |
                 +-----------+------------+
                             |
                 healthy ----+----> no action
                             |
                             v
                 +------------------------+
                 | recover-once.sh        |
                 |  -> recover-gateway    |
                 +-----------+------------+
                             |
                             v
                 +------------------------+
                 | recovery core          |
                 |                        |
                 | - state collection     |
                 | - classification       |
                 | - cooldown             |
                 | - attempt limit        |
                 | - lock / stale lock    |
                 | - restart / escalate   |
                 +-----------+------------+
                             |
                             v
                 +------------------------+
                 | start/stop wrappers     |
                 |                        |
                 | special edge:          |
                 | bootstrap plist if     |
                 | gateway was booted out |
                 +-----------+------------+
                             |
                             v
                 +------------------------+
                 | result + logs          |
                 |                        |
                 | last-result.json       |
                 | recover-events.log     |
                 | watcher.log            |
                 +------------------------+
```

## Design summary
- Recovery is external to the main Gateway service chain.
- Health truth is conservative and avoids over-trusting noisy probes.
- Restart behavior is governed to avoid repeated restart storms.
- Result/log outputs are first-class so failures are inspectable instead of mystical.
