# FlowChain Owner Env Template

Generated: 2026-05-21T17:47:44.2248616Z
Status: passed

This command creates or preserves a local ignored owner env file. It writes only empty assignments and never records owner-provided values.

Template path: `devnet/local/owner-inputs/flowchain-owner.local.env`
Git ignored: True

Use this in the local shell after you fill the local file:

```powershell
$env:FLOWCHAIN_OWNER_ENV_FILE="E:\FlowMemory\flowmemory-live-infra-rpc\devnet\local\owner-inputs\flowchain-owner.local.env"
npm run flowchain:owner-inputs
npm run flowchain:live-infra:check
npm run flowchain:owner-env:readiness:validate
npm run flowchain:owner-env:readiness -- -AllowBlocked
```

## Empty File Shape

```env
# FlowChain owner input file.
# Keep this local file ignored. Fill values only on the machine that runs FlowChain.
# Point FLOWCHAIN_OWNER_ENV_FILE at this file, then run the owner/live readiness gates.

FLOWCHAIN_RPC_PUBLIC_URL=
FLOWCHAIN_RPC_ALLOWED_ORIGINS=
FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE=
FLOWCHAIN_RPC_TLS_TERMINATED=
FLOWCHAIN_RPC_STATE_BACKUP_PATH=
FLOWCHAIN_TESTER_WRITE_ENABLED=
FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256=
FLOWCHAIN_TESTER_MAX_SEND_UNITS=
FLOWCHAIN_PILOT_OPERATOR_ACK=
FLOWCHAIN_BASE8453_RPC_URL=
FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS=
FLOWCHAIN_BASE8453_SUPPORTED_TOKEN=
FLOWCHAIN_BASE8453_ASSET_DECIMALS=
FLOWCHAIN_BASE8453_FROM_BLOCK=
FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI=
FLOWCHAIN_PILOT_TOTAL_CAP_WEI=
FLOWCHAIN_PILOT_CONFIRMATIONS=

# Optional bridge scan controls.
FLOWCHAIN_BASE8453_CURSOR_STATE=
FLOWCHAIN_BASE8453_TO_BLOCK=
```

## Field Guide

Use this table while filling the ignored local file. It lists names and validation rules only; keep real values in the local file or service environment.

| Name | Group | Required | Purpose | Validation | Where to get it | Do not send |
| --- | --- | --- | --- | --- | --- | --- |
| `FLOWCHAIN_RPC_PUBLIC_URL` | public-rpc | yes | Public HTTPS URL testers and wallets use for FlowChain RPC. | absolute non-local HTTPS endpoint | owner DNS, tunnel, or reverse proxy hostname | provider login password, tunnel token, or TLS private key |
| `FLOWCHAIN_RPC_ALLOWED_ORIGINS` | public-rpc | yes | Comma-separated HTTPS browser origins allowed to call the public RPC edge. | one or more explicit HTTPS origins; wildcard is rejected | dashboard/tester site origin list | wildcard origin or private browser session data |
| `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE` | public-rpc | yes | Per-origin or per-client public RPC request limit. | positive decimal integer | owner public edge rate-limit policy | provider account credentials |
| `FLOWCHAIN_RPC_TLS_TERMINATED` | public-rpc | yes | Acknowledgement that HTTPS termination is configured at the public edge. | must equal true | owner TLS edge configuration | TLS private key or certificate account credentials |
| `FLOWCHAIN_RPC_STATE_BACKUP_PATH` | backup | yes | Existing writable directory for live state backup and restore proof. | existing writable directory | owner host durable disk or mounted backup volume | cloud storage secret or host login password |
| `FLOWCHAIN_TESTER_WRITE_ENABLED` | tester-write | yes | Enables authenticated capped tester write routes. | must equal true | owner launch decision after public gates are ready | raw tester token |
| `FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256` | tester-write | yes | Digest of the out-of-band tester bearer token. | 64-character SHA-256 hex digest | npm run flowchain:tester:token:setup | raw tester token or token hash together with the raw token |
| `FLOWCHAIN_TESTER_MAX_SEND_UNITS` | tester-write | yes | Maximum units a tester can send per capped write request. | positive decimal integer | owner tester pilot cap | uncapped launch policy |
| `FLOWCHAIN_PILOT_OPERATOR_ACK` | base8453-bridge | yes | Explicit acknowledgement for the capped Base 8453 bridge pilot. | must equal I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT | owner go-live decision | wallet recovery words or private key |
| `FLOWCHAIN_BASE8453_RPC_URL` | base8453-bridge | yes | Base chain endpoint used by the bridge observer. | absolute HTTP(S) endpoint | Base RPC provider or owner-operated Base node | provider URLs that embed account tokens |
| `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS` | base8453-bridge | yes | Deployed Base 8453 lockbox contract address. | 20-byte hex address | bridge deployment artifact or verified owner contract | deployer private key |
| `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN` | base8453-bridge | yes | Base 8453 token address accepted by the capped pilot. | 20-byte hex address | owner-approved bridge token contract | wallet private key |
| `FLOWCHAIN_BASE8453_ASSET_DECIMALS` | base8453-bridge | yes | Decimals for the supported Base 8453 asset. | integer from 0 through 255 | token metadata or deployment checklist | provider account credentials |
| `FLOWCHAIN_BASE8453_FROM_BLOCK` | base8453-bridge | yes | First Base 8453 block the bridge observer scans. | non-negative decimal block number | lockbox deployment block or chosen pilot start block | provider account credentials |
| `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI` | base8453-bridge | yes | Maximum single deposit credited during the capped pilot. | positive decimal integer | owner pilot risk cap | uncapped value |
| `FLOWCHAIN_PILOT_TOTAL_CAP_WEI` | base8453-bridge | yes | Total bridge credit cap for the capped pilot. | positive decimal integer | owner pilot risk cap | uncapped value |
| `FLOWCHAIN_PILOT_CONFIRMATIONS` | base8453-bridge | yes | Base confirmations required before observer credit. | positive decimal integer | owner bridge finality policy | provider account credentials |
| `FLOWCHAIN_BASE8453_CURSOR_STATE` | base8453-bridge | optional | Optional local cursor state path for Base scan progress. | local path controlled by the owner host | default relayer state path unless overridden | cursor file contents if they include local paths you want private |
| `FLOWCHAIN_BASE8453_TO_BLOCK` | base8453-bridge | optional | Optional upper Base 8453 block for bounded observer scans. | non-negative decimal block number | owner bounded scan plan | provider account credentials |
