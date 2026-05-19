# FlowChain Live Cutover Rehearsal

Generated: 2026-05-19T19:41:10.4533513Z
Status: blocked

This command runs the owner-env, public deployment, tester packet, completion audit, truth table, and no-secret gates through one redacted rehearsal. It records env names and statuses only.

Owner env file: `devnet/local/owner-inputs/flowchain-owner.local.env`
Owner env file git-ignored: True
Blocked only on known owner inputs: True

## Gate Status

| Gate | Ready |
| --- | --- |
| ownerEnvReady | False |
| publicDeploymentReady | False |
| testerPacketShareable | False |
| completionReady | False |
| truthTableCompleted | False |
| noSecretScanPassed | True |

## Steps

| Step | Status | Report |
| --- | --- | --- |
| Owner env readiness | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\owner-env-readiness-report.json` |
| Public deployment contract | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\public-deployment-contract-report.json` |
| External tester packet | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\external-tester-packet-report.json` |
| Completion audit | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\flowchain-completion-audit-report.json` |
| Production truth table | passed | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\production-truth-table-report.json` |
| No-secret scan | passed | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\no-secret-scan-report.json` |

## Missing Owner Env Names

- `FLOWCHAIN_RPC_PUBLIC_URL`
- `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
- `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
- `FLOWCHAIN_RPC_TLS_TERMINATED`
- `FLOWCHAIN_RPC_STATE_BACKUP_PATH`
- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`

## Next Commands

- npm run flowchain:owner-env:readiness -- -AllowBlocked
- npm run flowchain:public-deployment:contract -- -AllowBlocked
- npm run flowchain:live:cutover:rehearsal -- -AllowBlocked
- npm run flowchain:truth-table -- -AllowBlocked

The rehearsal is runnable and remains blocked only on the missing owner env names above.
