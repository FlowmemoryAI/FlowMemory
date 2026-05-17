# FlowChain Ops Snapshot

Generated: 2026-05-17T13:37:11.4052041Z
Status: failed
Latest height: 55209
Finalized height: 55209

## Findings

- critical: height-not-advancing - Service monitor did not prove advancing block height.
- blocked: public-rpc-not-ready - Public RPC is not ready to share.
- blocked: backup-not-ready - State backup is not ready for public operation.
- blocked: bridge-not-ready - Base 8453 bridge readiness is not ready for external funded testing.
- blocked: bridge-relayer-not-ready - Bridge relayer one-shot proof is not ready.
- blocked: external-tester-not-shareable - External tester packet must remain not-shareable.
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
- npm run flowchain:external-tester:packet

### drills
- npm run flowchain:ops:incident-drill
- npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh

### emergency
- npm run flowchain:emergency:stop-local
- npm run flowchain:bridge:emergency-stop
- npm run flowchain:emergency:export-evidence
