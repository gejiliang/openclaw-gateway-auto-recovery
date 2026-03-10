# Operations

## Normal checks
- `openclaw gateway status --no-probe --json`
- `bin/check-gateway.sh`
- `launchctl print gui/$UID/<gateway-label>`
- `launchctl print gui/$UID/<watcher-label>`

## Logs to inspect
- watcher log
- watcher stderr/stdout
- recovery result JSON
- recovery events log
- main Gateway logs

## If watcher did not recover
1. confirm current gateway state
2. inspect recovery result/logs
3. run one-shot recovery once if needed
4. inspect wrapper behavior for unloaded-service launchd path

## Governance reminder
Cooldown and rolling attempt limits are deliberate. Repeated drill loops can trigger governed skips by design.
