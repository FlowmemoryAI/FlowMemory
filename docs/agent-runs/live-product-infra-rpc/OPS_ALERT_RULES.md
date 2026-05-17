# FlowChain Ops Alert Rules

Generated: 2026-05-17T08:45:29.9528314Z
Status: passed
Current alert state: blocked

This report maps local ops snapshot findings to operator actions. It does not send network notifications or store external alert credentials.

| Rule | Severity | Signal | Commands |
| --- | --- | --- | --- |
| node-process-down | critical | Node process is not running. | `npm run flowchain:service:status; npm run flowchain:service:restart -- -LiveProfile; npm run flowchain:emergency:stop-local` |
| control-plane-down | critical | Control-plane RPC process is not running. | `npm run flowchain:service:status; npm run flowchain:service:restart -- -LiveProfile` |
| block-production-stalled | critical | Block height is unreadable or did not advance. | `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30; npm run flowchain:service:restart -- -LiveProfile` |
| state-file-stale | critical | Runtime state file is older than the monitor freshness threshold. | `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30; npm run flowchain:service:restart -- -LiveProfile` |
| secret-boundary-breach | critical | No-secret scan did not pass. | `npm run flowchain:no-secret:scan; npm run flowchain:emergency:export-evidence` |
| public-rpc-not-shareable | blocked | Public RPC readiness gate is not passed. | `npm run flowchain:public-rpc:check; npm run flowchain:public-rpc:validate; npm run flowchain:public-rpc:abuse-test` |
| backup-not-ready | blocked | State backup readiness is not passed. | `npm run flowchain:backup:restore:validate; npm run flowchain:backup:check` |
| bridge-not-ready | blocked | Base 8453 bridge readiness is not passed. | `npm run flowchain:bridge:live:check; npm run flowchain:bridge:infra:check; npm run flowchain:bridge:emergency-stop` |
| external-tester-not-shareable | blocked | External tester packet is not shareable. | `npm run flowchain:tester:readiness; npm run flowchain:external-tester:packet` |
| deployment-contract-not-ready | blocked | Public deployment contract is not passed. | `npm run flowchain:public-deployment:contract -- -AllowBlocked` |

Covered finding codes: `node-not-running, control-plane-not-running, service-status-not-passed, chain-height-unreadable, height-not-advancing, state-stale, no-secret-scan-not-passed, public-rpc-not-ready, backup-not-ready, bridge-not-ready, external-tester-not-shareable, deployment-contract-not-ready`
