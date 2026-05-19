# FlowChain Service Supervisor

The service supervisor is the owner-host autorecovery loop for the local/private
FlowChain L1 runtime. It watches the block-producing node, control-plane RPC
service, and, when explicitly enabled, the bridge relayer loop, then restarts
the live service with state preserved when process or freshness gates fail.

## Run

```powershell
npm run flowchain:service:supervisor -- -IntervalSeconds 30 -MaxRestartAttempts 3
```

By default the supervisor restarts with `-LiveProfile`, `MaxBlocks=0`, the
private control-plane bind `127.0.0.1:8787`, and no bridge relayer loop. Use
`-StartBridgeRelayerLoop` only after the owner bridge inputs are configured.
When that switch is present, a stopped, mismatched, or unhealthy relayer loop is
treated as a restart reason and the supervisor waits briefly after restart for a
fresh no-secret/no-broadcast relayer health report.

## Validate

```powershell
npm run flowchain:service:supervisor:validate
```

The validation command starts an isolated service instance under
`devnet/local/service-supervisor-validation/`, kills only that instance's
control-plane process, runs the supervisor once, verifies recovery, then repeats
the proof with `-StartBridgeRelayerLoop` by killing only that isolated relayer
loop and proving supervisor recovery. It does not stop the live owner service.

## Install On Windows Owner Host

Use the Windows install planner before creating any persistent OS task:

```powershell
npm run flowchain:service:install:windows -- -Action Plan
npm run flowchain:service:install:validate
```

The validation command runs the install plan, the bridge-relayer opt-in plan, a
read-only status check, and an absent-task uninstall no-op check. It refuses to
remove a pre-existing validation task.

After the plan and validation pass, the owner host can register the supervisor
as a Windows Scheduled Task at startup and logon:

```powershell
npm run flowchain:service:install:windows -- -Action Install
npm run flowchain:service:install:windows -- -Action Status
```

Rollback removes only the scheduled task registration:

```powershell
npm run flowchain:service:install:windows -- -Action Uninstall
```

The default task uses `-TriggerMode Both`, starts the live-profile supervisor,
and does not enable the bridge relayer loop. Add `-StartBridgeRelayerLoop` only
after the bridge owner inputs and pilot guardrails pass.

## Reports

- `service-supervisor-report.json`
- `service-supervisor-status-report.json`
- `service-supervisor-restart-report.json`
- `service-supervisor-validation-report.json`
- `service-install-windows-report.json`
- `service-install-windows-status-report.json`
- `service-install-windows-uninstall-absent-report.json`
- `service-install-validation-report.json`

All reports are redacted by the same no-secret checks used by the rest of the
live infrastructure gate.
