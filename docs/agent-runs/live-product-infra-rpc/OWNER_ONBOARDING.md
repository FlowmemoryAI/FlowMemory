# FlowChain Owner Onboarding

Generated: 2026-05-19T13:15:55.1452886Z
Status: passed

FlowChain RPC is implemented by this repository. The owner does not need a third-party FlowChain RPC provider. Public RPC readiness means exposing the private local RPC origin through an owner-operated HTTPS edge with DNS, TLS, CORS, rate limits, and monitoring.

Base 8453 is different. The bridge observer reads Base mainnet, so that path needs a Base 8453 RPC endpoint or an owner-operated Base node.

## Signup And Setup Groups

| Group | Need external signup? | What it is for | Env names |
| --- | --- | --- | --- |
| FlowChain public RPC edge | True | Public DNS/domain plus HTTPS host, tunnel, or reverse proxy for this chain's private RPC origin. | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED |
| State backup | False | Existing writable directory or owner-managed storage mounted on the host. | FLOWCHAIN_RPC_STATE_BACKUP_PATH |
| External tester write gateway | False | Out-of-band shared tester bearer token hash and local send cap for friends-and-family pilot writes. | FLOWCHAIN_TESTER_WRITE_ENABLED, FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256, FLOWCHAIN_TESTER_MAX_SEND_UNITS |
| Base 8453 bridge observer | True | Base mainnet 8453 RPC provider or owner-operated Base node, plus deployed lockbox/token details. | FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS, FLOWCHAIN_BASE8453_CURSOR_STATE, FLOWCHAIN_BASE8453_TO_BLOCK |

## Local Shell Template

Set real values only in the local shell or service environment. Do not commit them and do not paste provider endpoints or credentials into chat.
You may also set `FLOWCHAIN_OWNER_ENV_FILE` to an ignored local NAME=value file; the repo parser imports only known FlowChain owner env names and does not execute that file.
Run `npm run flowchain:owner-env:template` to create the ignored local file scaffold before filling values.
Run `npm run flowchain:owner-env:readiness:validate` to confirm unsafe owner env-file paths fail before live gates run.
After filling the local file, run `npm run flowchain:owner-env:readiness -- -AllowBlocked` to validate the owner values against the live gates without printing values.

```powershell
$env:FLOWCHAIN_OWNER_ENV_FILE="<optional local ignored env file path>"
$env:FLOWCHAIN_RPC_PUBLIC_URL="<public HTTPS endpoint for this FlowChain RPC edge>"
$env:FLOWCHAIN_RPC_ALLOWED_ORIGINS="<comma-separated HTTPS app origins>"
$env:FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE="<positive integer>"
$env:FLOWCHAIN_RPC_TLS_TERMINATED="true"
$env:FLOWCHAIN_RPC_STATE_BACKUP_PATH="<existing writable backup directory>"
$env:FLOWCHAIN_TESTER_WRITE_ENABLED="true"
$env:FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256="<sha256 hex of out-of-band tester bearer token>"
$env:FLOWCHAIN_TESTER_MAX_SEND_UNITS="<positive local test-unit cap per send>"
$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$env:FLOWCHAIN_BASE8453_RPC_URL="<Base 8453 RPC endpoint or self-operated node endpoint>"
$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS="<20-byte lockbox address>"
$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN="<20-byte token address>"
$env:FLOWCHAIN_BASE8453_ASSET_DECIMALS="<0 through 255>"
$env:FLOWCHAIN_BASE8453_FROM_BLOCK="<first bounded Base block>"
$env:FLOWCHAIN_BASE8453_CURSOR_STATE="services/bridge-relayer/out/base8453-pilot-cursor-state.json"
$env:FLOWCHAIN_BASE8453_TO_BLOCK="<optional last bounded Base block>"
$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI="<positive capped amount>"
$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI="<positive capped amount greater than or equal to max deposit>"
$env:FLOWCHAIN_PILOT_CONFIRMATIONS="<2 through 256>"
```

## Remaining Inputs

- Missing: FLOWCHAIN_RPC_PUBLIC_URL
- Missing: FLOWCHAIN_RPC_ALLOWED_ORIGINS
- Missing: FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- Missing: FLOWCHAIN_RPC_TLS_TERMINATED
- Missing: FLOWCHAIN_RPC_STATE_BACKUP_PATH
- Missing: FLOWCHAIN_PILOT_OPERATOR_ACK
- Missing: FLOWCHAIN_BASE8453_RPC_URL
- Missing: FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
- Missing: FLOWCHAIN_BASE8453_SUPPORTED_TOKEN
- Missing: FLOWCHAIN_BASE8453_ASSET_DECIMALS
- Missing: FLOWCHAIN_BASE8453_FROM_BLOCK
- Missing: FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
- Missing: FLOWCHAIN_PILOT_TOTAL_CAP_WEI
- Missing: FLOWCHAIN_PILOT_CONFIRMATIONS

## Next Commands

- npm run flowchain:owner:onboarding
- npm run flowchain:owner:signup-checklist
- npm run flowchain:owner-env:template
- npm run flowchain:owner-env:readiness:validate
- npm run flowchain:owner-env:readiness -- -AllowBlocked
- npm run flowchain:owner-inputs
- npm run flowchain:public-rpc:edge-template
- npm run flowchain:public-rpc:validate
- npm run flowchain:public-rpc:check
- npm run flowchain:backup:restore:validate
- npm run flowchain:backup:create
- npm run flowchain:backup:restore:verify
- npm run flowchain:backup:check
- npm run flowchain:bridge:live:check
- npm run flowchain:bridge:infra:check
- npm run flowchain:completion:audit -- -AllowBlocked
