# FlowChain Owner Inputs

Generated: 2026-05-17T15:51:29.3504072Z
Status: failed
Owner input ready: False

This file intentionally records env names, validation checks, and pass/block/fail status only. It does not contain owner-provided values.

| Env name | Group | Status | Check |
| --- | --- | --- | --- |
| FLOWCHAIN_RPC_PUBLIC_URL | public-rpc | present-invalid | absolute public HTTPS endpoint |
| FLOWCHAIN_RPC_ALLOWED_ORIGINS | public-rpc | present-invalid | one or more explicit HTTPS browser origins |
| FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE | public-rpc | present-invalid | positive decimal integer |
| FLOWCHAIN_RPC_TLS_TERMINATED | public-rpc | present-invalid | must equal true after TLS termination is configured |
| FLOWCHAIN_RPC_STATE_BACKUP_PATH | backup | present-invalid | existing writable directory |
| FLOWCHAIN_TESTER_WRITE_ENABLED | external-tester-write | present-invalid | must equal true to expose the authenticated tester write gateway |
| FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256 | external-tester-write | present-invalid | 64-character SHA-256 hex digest of the out-of-band tester bearer token |
| FLOWCHAIN_TESTER_MAX_SEND_UNITS | external-tester-write | present-invalid | positive decimal integer test-unit cap per tester send |
| FLOWCHAIN_PILOT_OPERATOR_ACK | base8453-bridge | present-invalid | must equal the fixed capped-pilot acknowledgement |
| FLOWCHAIN_BASE8453_RPC_URL | base8453-bridge | present-invalid | absolute HTTP(S) Base 8453 endpoint |
| FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS | base8453-bridge | present-invalid | 20-byte hex address |
| FLOWCHAIN_BASE8453_SUPPORTED_TOKEN | base8453-bridge | present-invalid | 20-byte hex address |
| FLOWCHAIN_BASE8453_ASSET_DECIMALS | base8453-bridge | present-invalid | decimal integer from 0 through 255 |
| FLOWCHAIN_BASE8453_FROM_BLOCK | base8453-bridge | present-invalid | non-negative decimal block number |
| FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI | base8453-bridge | present-invalid | positive decimal integer |
| FLOWCHAIN_PILOT_TOTAL_CAP_WEI | base8453-bridge | present-invalid | positive decimal integer |
| FLOWCHAIN_PILOT_CONFIRMATIONS | base8453-bridge | present-invalid | positive decimal integer |

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
