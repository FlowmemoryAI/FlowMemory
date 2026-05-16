# FlowChain Ops Snapshot

Generated: 2026-05-16T09:50:32.7527125Z
Status: failed
Latest height: 34458
Finalized height: 34458

## Findings

- critical: service-status-not-passed - FlowChain service status is not passed.
- critical: control-plane-not-running - The control-plane RPC service is not running.
- blocked: public-rpc-not-ready - Public RPC is not ready to share.
- blocked: backup-not-ready - State backup is not ready for public operation.
- blocked: bridge-not-ready - Base 8453 bridge readiness is not ready for external funded testing.
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
