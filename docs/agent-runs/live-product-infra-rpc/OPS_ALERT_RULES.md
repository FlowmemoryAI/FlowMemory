# FlowChain Ops Alert Rules

Generated: 2026-05-20T04:23:18.1749755Z
Status: passed
Current alert state: blocked

This report maps local ops snapshot findings to operator actions. It does not send network notifications or store external alert credentials.

| Rule | Severity | Signal | Commands |
| --- | --- | --- | --- |
| node-process-down | critical | Node process is not running. | `npm run flowchain:service:status; npm run flowchain:service:restart -- -LiveProfile; npm run flowchain:emergency:stop-local` |
| control-plane-down | critical | Control-plane RPC process is not running. | `npm run flowchain:service:status; npm run flowchain:service:restart -- -LiveProfile` |
| block-production-stalled | critical | Block height is unreadable or did not advance. | `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30; npm run flowchain:service:restart -- -LiveProfile` |
| state-file-stale | critical | Runtime state file is older than the monitor freshness threshold. | `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30; npm run flowchain:service:restart -- -LiveProfile` |
| transaction-intake-corrupt | critical | Signed transaction intake contains invalid local NDJSON rows. | `npm run flowchain:ops:snapshot; npm run flowchain:control-plane:smoke; npm run flowchain:no-secret:scan` |
| secret-boundary-breach | critical | No-secret scan did not pass. | `npm run flowchain:no-secret:scan; npm run flowchain:emergency:export-evidence` |
| backup-retention-unsafe | critical | Backup retention failed to protect the latest snapshot or reported prune errors. | `npm run flowchain:backup:restore:validate; npm run flowchain:backup:owner-path:dry-run; npm run flowchain:backup:check` |
| bridge-relayer-check-contract-failed | critical | Bridge relayer one-shot safety check contract is missing or failing. | `npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh; npm run flowchain:bridge:emergency-stop` |
| bridge-relayer-latency-failed | critical | Bridge relayer failed or exceeded the handoff-to-spendable latency gate. | `npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:service:status; npm run flowchain:bridge:emergency-stop` |
| bridge-relayer-cursor-unsafe | critical | Bridge relayer passed without safe staged cursor commit evidence. | `npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:bridge:emergency-stop; npm run flowchain:service:status` |
| bridge-relayer-guardrail-failed | critical | Bridge relayer fail-closed guardrail proof is missing or failed. | `npm run flowchain:bridge:relayer:guardrail:validate; npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:bridge:emergency-stop` |
| bridge-direct-observe-cursor-unsafe | critical | Standalone Base 8453 observer could use or mutate the final relayer cursor without explicit owner opt-in. | `npm run flowchain:bridge:relayer:guardrail:validate; npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:bridge:emergency-stop` |
| bridge-relayer-loop-unhealthy | critical | Bridge relayer loop is running without fresh no-secret/no-broadcast health evidence. | `npm run flowchain:service:status; npm run flowchain:bridge:relayer:loop:validate; npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop; npm run flowchain:bridge:emergency-stop` |
| supervisor-relayer-recovery-failed | critical | Service supervisor requested the bridge relayer loop but latest recovery evidence does not show a healthy relayer loop. | `npm run flowchain:service:supervisor -- -Once -StartBridgeRelayerLoop; npm run flowchain:service:supervisor:validate; npm run flowchain:service:restart -- -LiveProfile -StartBridgeRelayerLoop; npm run flowchain:bridge:emergency-stop` |
| deployment-refresh-aborted | critical | Public deployment dependency refresh aborted or skipped child gates. | `npm run flowchain:public-deployment:contract -- -AllowBlocked; npm run flowchain:public-deployment:contract -- -NoRefresh -AllowBlocked; npm run flowchain:ops:snapshot -- -AllowBlocked -NoRefresh` |
| truth-table-stale-or-failed | critical | Production truth table is stale, failed, missing, or reports repo-owned blockers. | `npm run flowchain:truth-table -- -AllowBlocked; npm run flowchain:completion:audit -- -AllowBlocked; npm run flowchain:live:cutover:rehearsal -- -AllowBlocked` |
| external-tester-evidence-unsafe | critical | External tester returned evidence contains a secret marker, credential URL, or env assignment. | `npm run flowchain:tester:evidence:validate; npm run flowchain:no-secret:scan; npm run flowchain:emergency:export-evidence` |
| dashboard-ui-readiness-failed | critical | Dashboard wallet, faucet, send, tester launch, explorer, activation cockpit, or no-secret UI readiness proof is missing or failed. | `npm run flowchain:dashboard:ui:readiness; npm run flowchain:dashboard:build; npm test --prefix apps/dashboard` |
| owner-inputs-validation-failed | critical | Owner input validation scenarios are missing, failed, or unsafe to use for live cutover. | `npm run flowchain:owner-inputs:validate; npm run flowchain:owner-inputs; npm run flowchain:owner-env:readiness` |
| public-rpc-edge-hardening-failed | critical | Public RPC edge deployment hardening evidence is missing or failed. | `npm run flowchain:public-rpc:deployment-bundle; npm run flowchain:public-rpc:deployment:automation; npm run flowchain:public-deployment:contract -- -AllowBlocked -NoRefresh` |
| public-rpc-not-shareable | blocked | Public RPC readiness gate is not passed. | `npm run flowchain:public-rpc:check; npm run flowchain:public-rpc:validate; npm run flowchain:public-rpc:abuse-test` |
| backup-not-ready | blocked | State backup readiness is not passed. | `npm run flowchain:backup:restore:validate; npm run flowchain:backup:check` |
| bridge-not-ready | blocked | Base 8453 bridge readiness is not passed. | `npm run flowchain:bridge:live:check; npm run flowchain:bridge:infra:check; npm run flowchain:bridge:emergency-stop` |
| bridge-relayer-not-ready | blocked | Bridge relayer one-shot proof is not ready. | `npm run flowchain:bridge:relayer:once -- -AllowBlocked; npm run flowchain:bridge:live:check; npm run flowchain:bridge:infra:check` |
| external-tester-not-shareable | blocked | External tester packet is not shareable. | `npm run flowchain:tester:readiness; npm run flowchain:external-tester:packet` |
| external-tester-evidence-invalid | blocked | External tester returned evidence is incomplete or transfer proof is inconsistent. | `npm run flowchain:tester:evidence:validate; npm run flowchain:external-tester:packet -- -AllowBlocked` |
| deployment-contract-not-ready | blocked | Public deployment contract is not passed. | `npm run flowchain:public-deployment:contract -- -AllowBlocked` |

Covered finding codes: `node-not-running, control-plane-not-running, service-status-not-passed, chain-height-unreadable, height-not-advancing, state-stale, transaction-intake-invalid-rows, no-secret-scan-not-passed, backup-retention-unsafe, bridge-relayer-check-contract-failed, bridge-relayer-latency-failed, bridge-relayer-cursor-unsafe, bridge-relayer-guardrail-failed, bridge-direct-observe-cursor-unsafe, bridge-relayer-loop-unhealthy, supervisor-relayer-recovery-failed, deployment-refresh-aborted, truth-table-stale-or-failed, external-tester-evidence-unsafe, dashboard-ui-readiness-failed, owner-inputs-validation-failed, public-rpc-edge-hardening-failed, public-rpc-not-ready, backup-not-ready, bridge-not-ready, bridge-relayer-not-ready, external-tester-not-shareable, external-tester-evidence-invalid, deployment-contract-not-ready`
