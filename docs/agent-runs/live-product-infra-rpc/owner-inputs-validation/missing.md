# FlowChain Owner Inputs

Generated: 2026-05-19T21:11:29.6848901Z
Status: blocked
Owner input ready: False

This file intentionally records env names, validation checks, and pass/block/fail status only. It does not contain owner-provided values.

| Env name | Group | Status | Check |
| --- | --- | --- | --- |
| FLOWCHAIN_RPC_PUBLIC_URL | public-rpc | missing | required |
| FLOWCHAIN_RPC_ALLOWED_ORIGINS | public-rpc | missing | required |
| FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE | public-rpc | missing | required |
| FLOWCHAIN_RPC_TLS_TERMINATED | public-rpc | missing | required |
| FLOWCHAIN_RPC_STATE_BACKUP_PATH | backup | missing | required |
| FLOWCHAIN_TESTER_WRITE_ENABLED | external-tester-write | missing | required |
| FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256 | external-tester-write | missing | required |
| FLOWCHAIN_TESTER_MAX_SEND_UNITS | external-tester-write | missing | required |
| FLOWCHAIN_PILOT_OPERATOR_ACK | base8453-bridge | missing | required |
| FLOWCHAIN_BASE8453_RPC_URL | base8453-bridge | missing | required |
| FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS | base8453-bridge | missing | required |
| FLOWCHAIN_BASE8453_SUPPORTED_TOKEN | base8453-bridge | missing | required |
| FLOWCHAIN_BASE8453_ASSET_DECIMALS | base8453-bridge | missing | required |
| FLOWCHAIN_BASE8453_FROM_BLOCK | base8453-bridge | missing | required |
| FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI | base8453-bridge | missing | required |
| FLOWCHAIN_PILOT_TOTAL_CAP_WEI | base8453-bridge | missing | required |
| FLOWCHAIN_PILOT_CONFIRMATIONS | base8453-bridge | missing | required |

## Owner Env File

- FLOWCHAIN_OWNER_ENV_FILE configured: False

## Next Commands

- npm run flowchain:owner-env:template
- npm run flowchain:owner-env:readiness:validate
- npm run flowchain:owner-env:readiness -- -AllowBlocked
- npm run flowchain:owner:onboarding
- npm run flowchain:owner:signup-checklist
- npm run flowchain:service:monitor
- npm run flowchain:live-infra:check
- npm run flowchain:tester:readiness
- npm run flowchain:external-tester:packet
- npm run flowchain:live-product:e2e

Do not share the network externally yet. Resolve the missing or invalid env names above, then rerun the next commands.
