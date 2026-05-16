# FlowChain Owner Inputs

Generated: 2026-05-16T20:41:22.0243487Z
Status: passed
Owner input ready: True

This file intentionally records env names, validation checks, and pass/block/fail status only. It does not contain owner-provided values.

| Env name | Group | Status | Check |
| --- | --- | --- | --- |
| FLOWCHAIN_RPC_PUBLIC_URL | public-rpc | present-valid | absolute public HTTPS endpoint |
| FLOWCHAIN_RPC_ALLOWED_ORIGINS | public-rpc | present-valid | one or more explicit HTTPS browser origins |
| FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE | public-rpc | present-valid | positive decimal integer |
| FLOWCHAIN_RPC_TLS_TERMINATED | public-rpc | present-valid | must equal true after TLS termination is configured |
| FLOWCHAIN_RPC_STATE_BACKUP_PATH | backup | present-valid | existing writable directory |
| FLOWCHAIN_PILOT_OPERATOR_ACK | base8453-bridge | present-valid | must equal the fixed capped-pilot acknowledgement |
| FLOWCHAIN_BASE8453_RPC_URL | base8453-bridge | present-valid | absolute HTTP(S) Base 8453 endpoint |
| FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS | base8453-bridge | present-valid | 20-byte hex address |
| FLOWCHAIN_BASE8453_SUPPORTED_TOKEN | base8453-bridge | present-valid | 20-byte hex address |
| FLOWCHAIN_BASE8453_ASSET_DECIMALS | base8453-bridge | present-valid | decimal integer from 0 through 255 |
| FLOWCHAIN_BASE8453_FROM_BLOCK | base8453-bridge | present-valid | non-negative decimal block number |
| FLOWCHAIN_BASE8453_TO_BLOCK | base8453-bridge | present-valid | non-negative decimal block number |
| FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI | base8453-bridge | present-valid | positive decimal integer |
| FLOWCHAIN_PILOT_TOTAL_CAP_WEI | base8453-bridge | present-valid | positive decimal integer |
| FLOWCHAIN_PILOT_CONFIRMATIONS | base8453-bridge | present-valid | positive decimal integer |

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

All required owner input names are present and structurally valid. Continue with the live infrastructure and tester gates.
