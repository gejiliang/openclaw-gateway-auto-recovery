# Post-upgrade checklist

After OpenClaw upgrades or launchd/service-chain changes, verify:

1. gateway and watcher jobs still exist
2. `status --no-probe --json` fields still match the health contract
3. runtime PID still matches listener PID
4. deep probe remains auxiliary-only unless you intentionally redesign the health model
5. main Gateway plist path still matches restart wrapper assumptions
6. unloaded-service bootstrap path still works
7. watcher cadence/logging still looks normal
8. one-shot recovery smoke test still behaves correctly on a healthy system
