# FlowChain Owner Needs Now

Generated: 2026-05-21T12:39:12.9550784Z
Status: passed
Launch readiness: blocked-owner-input

This report lists names, commands, and owner actions only. It does not print owner values.

## Current L1 State

- Latest height: 112761
- Finalized height: 112761
- Release ready: False
- Deployment ready: False
- External tester packet shareable: False
- Completion ready: False

## Needed Now

| Group | Status | Owner action | Missing or invalid names | Validate with |
| --- | --- | --- | --- | --- |
| Public RPC edge | needs-owner-input | Pick the public RPC URL, configure TLS termination, set exact HTTPS browser origins, and choose a positive per-minute rate limit. | `FLOWCHAIN_RPC_PUBLIC_URL`, `FLOWCHAIN_RPC_ALLOWED_ORIGINS`, `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`, `FLOWCHAIN_RPC_TLS_TERMINATED` | `npm run flowchain:public-rpc:check -- -AllowBlocked` |
| Backup storage | needs-owner-input | Create an existing writable backup directory on the always-on host and point the owner env file at it. | `FLOWCHAIN_RPC_STATE_BACKUP_PATH` | `npm run flowchain:backup:owner-path:dry-run` |
| Base 8453 bridge | needs-owner-input | Provide the Base RPC endpoint, lockbox and supported token addresses, asset decimals, start block, capped pilot acknowledgement, deposit cap, total cap, and confirmation depth. | `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_RPC_URL`, `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`, `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`, `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, `FLOWCHAIN_PILOT_CONFIRMATIONS` | `npm run flowchain:bridge:live:check -- -AllowBlocked` |

## Ready Groups

- Tester write gateway: ready

## Deployment Gates Blocking Sharing

| Gate | Status | First command | Blocking names |
| --- | --- | --- | --- |
| owner-input-contract | blocked | `npm run flowchain:owner-inputs` | `FLOWCHAIN_RPC_PUBLIC_URL`, `FLOWCHAIN_RPC_ALLOWED_ORIGINS`, `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`, `FLOWCHAIN_RPC_TLS_TERMINATED`, `FLOWCHAIN_RPC_STATE_BACKUP_PATH`, `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_RPC_URL`, `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`, `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`, `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, `FLOWCHAIN_PILOT_CONFIRMATIONS` |
| public-rpc-synthetic-canary | blocked | `npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked` | `FLOWCHAIN_RPC_PUBLIC_URL` |
| public-rpc-edge | blocked | `npm run flowchain:public-rpc:validate` | `FLOWCHAIN_RPC_PUBLIC_URL`, `FLOWCHAIN_RPC_ALLOWED_ORIGINS`, `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`, `FLOWCHAIN_RPC_TLS_TERMINATED` |
| state-backup | blocked | `npm run flowchain:backup:create` | `FLOWCHAIN_RPC_STATE_BACKUP_PATH` |
| base8453-bridge-edge | blocked | `npm run flowchain:bridge:live:check` | `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_RPC_URL`, `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`, `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`, `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, `FLOWCHAIN_PILOT_CONFIRMATIONS` |
| base8453-bridge-relayer-queue | blocked | `npm run flowchain:bridge:relayer:once` | `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_RPC_URL`, `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`, `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`, `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, `FLOWCHAIN_PILOT_CONFIRMATIONS` |
| external-tester-sharing | blocked | `npm run flowchain:tester:readiness` | `FLOWCHAIN_RPC_PUBLIC_URL`, `FLOWCHAIN_RPC_ALLOWED_ORIGINS`, `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`, `FLOWCHAIN_RPC_TLS_TERMINATED`, `FLOWCHAIN_RPC_STATE_BACKUP_PATH`, `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_RPC_URL`, `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`, `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`, `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, `FLOWCHAIN_PILOT_CONFIRMATIONS` |

## Do Not Send

- provider dashboard password
- TLS private key
- tunnel token
- origin wildcard
- cloud storage secret
- backup provider account password
- private backup credentials
- raw tester bearer token
- owner env file contents
- token hash together with the raw token
- wallet seed words
- deployer private key
- provider API secret pasted in chat
- unbounded pilot caps

## Next Commands

- `npm run flowchain:owner-env:template`
- `npm run flowchain:owner:needs-now`
- `npm run flowchain:owner-env:readiness -- -AllowBlocked`
- `npm run flowchain:public-deployment:contract -- -AllowBlocked`
- `npm run flowchain:live:cutover:rehearsal -- -AllowBlocked`
- `npm run flowchain:truth-table -- -AllowBlocked`
