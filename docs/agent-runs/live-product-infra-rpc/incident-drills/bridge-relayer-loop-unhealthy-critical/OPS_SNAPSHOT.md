# FlowChain Ops Snapshot

Generated: 2026-05-20T09:57:50.3734642Z
Status: failed
Latest height: 100638
Finalized height: 100638
Transaction intake rows: 169
Runtime inbox files: 0

## Findings

- critical: bridge-relayer-loop-unhealthy - Bridge relayer loop is running without fresh no-secret/no-broadcast health evidence.
- blocked: public-rpc-not-ready - Public RPC is not ready to share.
- blocked: backup-not-ready - State backup is not ready for public operation.
- blocked: bridge-not-ready - Base 8453 bridge readiness is not ready for external funded testing.
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
