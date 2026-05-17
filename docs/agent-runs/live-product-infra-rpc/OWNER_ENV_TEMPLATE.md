# FlowChain Owner Env Template

Generated: 2026-05-17T14:47:35.5821210Z
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
