# FlowChain Ops Alert Rules

Generated: 2026-05-18T01:07:51.5423881Z
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
| bridge-relayer-latency-failed | critical | Bridge relayer failed or exceeded the handoff-to-spendable latency gate. | `npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:service:status; npm run flowchain:bridge:emergency-stop` |
| bridge-relayer-cursor-unsafe | critical | Bridge relayer passed without safe staged cursor commit evidence. | `npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:bridge:emergency-stop; npm run flowchain:service:status` |
| bridge-relayer-guardrail-failed | critical | Bridge relayer fail-closed guardrail proof is missing or failed. | `npm run flowchain:bridge:relayer:guardrail:validate; npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:bridge:emergency-stop` |
| bridge-relayer-loop-unhealthy | critical | Bridge relayer loop is running without fresh no-secret/no-broadcast health evidence. | `npm run flowchain:service:status; npm run flowchain:bridge:relayer:loop:validate; npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop; npm run flowchain:bridge:emergency-stop` |
| deployment-refresh-aborted | critical | Public deployment dependency refresh aborted or skipped child gates. | `npm run flowchain:public-deployment:contract -- -AllowBlocked; npm run flowchain:public-deployment:contract -- -NoRefresh -AllowBlocked; npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh` |
| public-rpc-not-shareable | blocked | Public RPC readiness gate is not passed. | `npm run flowchain:public-rpc:check; npm run flowchain:public-rpc:validate; npm run flowchain:public-rpc:abuse-test` |
| backup-not-ready | blocked | State backup readiness is not passed. | `npm run flowchain:backup:restore:validate; npm run flowchain:backup:check` |
| bridge-not-ready | blocked | Base 8453 bridge readiness is not passed. | `npm run flowchain:bridge:live:check; npm run flowchain:bridge:infra:check; npm run flowchain:bridge:emergency-stop` |
| bridge-relayer-not-ready | blocked | Bridge relayer one-shot proof is not ready. | `npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:bridge:live:check; npm run flowchain:bridge:infra:check` |
| external-tester-not-shareable | blocked | External tester packet is not shareable. | `npm run flowchain:tester:readiness; npm run flowchain:external-tester:packet` |
| deployment-contract-not-ready | blocked | Public deployment contract is not passed. | `npm run flowchain:public-deployment:contract -- -AllowBlocked` |

Covered finding codes: `node-not-running, control-plane-not-running, service-status-not-passed, chain-height-unreadable, height-not-advancing, state-stale, no-secret-scan-not-passed, bridge-relayer-latency-failed, bridge-relayer-cursor-unsafe, bridge-relayer-guardrail-failed, bridge-relayer-loop-unhealthy, deployment-refresh-aborted, public-rpc-not-ready, backup-not-ready, bridge-not-ready, bridge-relayer-not-ready, external-tester-not-shareable, deployment-contract-not-ready`
