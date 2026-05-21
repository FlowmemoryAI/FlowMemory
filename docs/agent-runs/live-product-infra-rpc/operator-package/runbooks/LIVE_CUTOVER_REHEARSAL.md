# FlowChain Live Cutover Rehearsal

Generated: 2026-05-21T10:27:03.9236435Z
Status: blocked

This command runs the owner-env, public deployment, local tester wallet network, tester write-token setup, tester packet, packet validation, external tester client validation, completion audit, truth table, and no-secret gates through one redacted rehearsal. It records env names and statuses only.

Owner env file: `devnet/local/owner-inputs/flowchain-owner.local.env`
Owner env file git-ignored: True
Blocked only on known owner inputs: True
Truth table status observed inside rehearsal: stale
Truth table self-reference stale accepted: True

## Gate Status

| Gate | Ready |
| --- | --- |
| ownerEnvReady | False |
| publicDeploymentReady | False |
| testerNetworkE2ePassed | True |
| testerWriteTokenSetupPassed | True |
| testerPacketShareable | False |
| testerPacketValidationPassed | True |
| testerClientValidationPassed | True |
| completionReady | False |
| truthTableCompleted | False |
| truthTableAccepted | True |
| truthTableSelfReferenceStaleAccepted | True |
| noSecretScanPassed | True |

## Steps

| Step | Status | Report |
| --- | --- | --- |
| Owner env readiness | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\owner-env-readiness-report.json` |
| Public deployment contract | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\public-deployment-contract-report.json` |
| Local tester wallet network E2E | passed | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\live-service-tester-network-e2e-report.json` |
| Tester write token setup | passed | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\tester-write-token-setup-report.json` |
| External tester packet | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\external-tester-packet-report.json` |
| External tester packet validation | passed | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\external-tester-packet-validation-report.json` |
| External tester client validation | passed | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\external-tester-client-validation-report.json` |
| Completion audit | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\flowchain-completion-audit-report.json` |
| Production truth table | stale | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\production-truth-table-report.json` |
| No-secret scan | passed | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\no-secret-scan-report.json` |

## Truth Table Stale Items

- `live-cutover-rehearsal`

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
- npm run flowchain:wallet:live-tester:e2e
- npm run flowchain:tester:token:setup
- npm run flowchain:external-tester:packet:validate
- npm run flowchain:external-tester:client:validate
- npm run flowchain:live:cutover:rehearsal -- -AllowBlocked
- npm run flowchain:truth-table -- -AllowBlocked

The rehearsal is runnable and remains blocked only on the missing owner env names above.
