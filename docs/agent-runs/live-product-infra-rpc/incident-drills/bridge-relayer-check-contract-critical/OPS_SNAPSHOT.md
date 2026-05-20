# FlowChain Ops Snapshot

Generated: 2026-05-20T11:13:32.9457547Z
Status: failed
Latest height: 101275
Finalized height: 101275
Transaction intake rows: 169
Runtime inbox files: 0

## Findings

- blocked: public-rpc-not-ready - Public RPC is not ready to share.
- blocked: backup-not-ready - State backup is not ready for public operation.
- blocked: bridge-not-ready - Base 8453 bridge readiness is not ready for external funded testing.
- critical: bridge-relayer-check-contract-failed - Bridge relayer one-shot safety check contract is missing or has failed checks.
- blocked: bridge-relayer-not-ready - Bridge relayer one-shot proof is not ready.
- blocked: external-tester-not-shareable - External tester launch is not shareable; local rehearsal, public tester gateway, faucet route, external sharing, and live infra readiness must all pass first.
- blocked: deployment-contract-not-ready - Public deployment contract is not ready.

## Incident Commands

### status
- npm run flowchain:ops:snapshot
- npm run flowchain:service:status
- npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30

### restart
- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:status

### backupRecovery
- npm run flowchain:backup:restore:validate
- npm run flowchain:backup:create
- npm run flowchain:backup:restore:verify

### publicExposure
- npm run flowchain:public-rpc:check
- npm run flowchain:public-rpc:abuse-test
- npm run flowchain:public-rpc:deployment-bundle
- npm run flowchain:public-rpc:deployment:automation
- npm run flowchain:external-tester:packet

### productSurface
- npm run flowchain:dashboard:ui:readiness
- npm run flowchain:tester:evidence:validate
- npm run flowchain:external-tester:packet

### ownerInputs
- npm run flowchain:owner-inputs:validate
- npm run flowchain:owner-inputs
- npm run flowchain:owner-env:readiness

### drills
- npm run flowchain:ops:incident-drill
- npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh

### emergency
- npm run flowchain:emergency:stop-local
- npm run flowchain:bridge:emergency-stop
- npm run flowchain:emergency:export-evidence

### bridgeRelayerLoop
- npm run flowchain:service:status
- npm run flowchain:service:supervisor -- -Once -StartBridgeRelayerLoop
- npm run flowchain:bridge:relayer:loop:validate
- npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop
