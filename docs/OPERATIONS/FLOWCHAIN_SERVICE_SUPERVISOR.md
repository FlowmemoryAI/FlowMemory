# FlowChain Service Supervisor

The service supervisor is the owner-host autorecovery loop for the local/private
FlowChain L1 runtime. It watches the block-producing node and control-plane RPC
service, then restarts both with state preserved when process or freshness gates
fail.

## Run

```powershell
npm run flowchain:service:supervisor -- -IntervalSeconds 30 -MaxRestartAttempts 3
```

By default the supervisor restarts with `-LiveProfile`, `MaxBlocks=0`, the
private control-plane bind `127.0.0.1:8787`, and no bridge relayer loop. Use
`-StartBridgeRelayerLoop` only after the owner bridge inputs are configured.

## Validate

```powershell
npm run flowchain:service:supervisor:validate
```

The validation command starts an isolated service instance under
`devnet/local/service-supervisor-validation/`, kills only that instance's
control-plane process, runs the supervisor once, verifies recovery, and stops
the isolated instance. It does not stop the live owner service.

## Reports

- `service-supervisor-report.json`
- `service-supervisor-status-report.json`
- `service-supervisor-restart-report.json`
- `service-supervisor-validation-report.json`

All reports are redacted by the same no-secret checks used by the rest of the
live infrastructure gate.
