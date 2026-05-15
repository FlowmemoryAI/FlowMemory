# FlowChain Owner-Operated Public RPC Runbook

Status: fail-closed operator path. This document does not claim broad public use readiness.

## What Code Provides

The repository now provides:

- `npm run flowchain:service:start` for supervised node and control-plane processes on Windows.
- `npm run flowchain:service:status` for safe process, bind, height, backup, and bridge status.
- `npm run flowchain:service:stop` and `npm run flowchain:service:restart`, which preserve runtime state.
- `npm run flowchain:public-rpc:check` for endpoint, TLS, CORS, rate-limit, health, discovery, readiness, state, and response-hygiene checks.
- `npm run flowchain:backup:check` for writable backup path and state readback verification.
- `npm run flowchain:bridge:infra:check` for Base 8453 deployment input checks.
- `npm run flowchain:live-infra:check` as the aggregate gate.

## What The Owner Must Provide

The owner must provide, in the local shell or service environment only:

```powershell
$env:FLOWCHAIN_RPC_PUBLIC_URL="<https endpoint exposed by the owner TLS proxy>"
$env:FLOWCHAIN_RPC_ALLOWED_ORIGINS="<comma-separated HTTPS origins>"
$env:FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE="<positive integer>"
$env:FLOWCHAIN_RPC_TLS_TERMINATED="true"
$env:FLOWCHAIN_RPC_STATE_BACKUP_PATH="<existing writable backup directory>"
```

The owner must also provide the Base 8453 bridge env contract before the bridge checks can pass:

```powershell
$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$env:FLOWCHAIN_BASE8453_RPC_URL="<Base 8453 RPC endpoint>"
$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS="<deployed lockbox address>"
$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN="<0x0000000000000000000000000000000000000000 or ERC-20 address>"
$env:FLOWCHAIN_BASE8453_ASSET_DECIMALS="<decimal count>"
$env:FLOWCHAIN_BASE8453_FROM_BLOCK="<first bounded block>"
$env:FLOWCHAIN_BASE8453_TO_BLOCK="<last bounded block>"
$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI="<per-deposit cap>"
$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI="<total cap>"
$env:FLOWCHAIN_PILOT_CONFIRMATIONS="<confirmation depth>"
```

Do not commit these values.

## Recommended Windows Host Shape

Use a Windows machine or VM where the FlowChain control plane binds privately to `127.0.0.1:8787`. Put a TLS-terminating reverse proxy or tunnel in front of it. The public URL should point to the proxy, not directly to an unencrypted local process.

Minimum proxy controls:

- TLS termination with a valid certificate.
- Only configured CORS origins from `FLOWCHAIN_RPC_ALLOWED_ORIGINS`.
- Per-minute rate limit matching `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`.
- No request logging of secrets or raw signed payloads.
- Access to `/health`, `/rpc/discover`, `/rpc/readiness`, `/chain/status`, `/wallets/operator`, `/bridge/live-readiness`, and `/rpc`.

Provider-specific credentials, DNS names, tunnel URLs, tokens, and webhook URLs stay outside the repo.

## Start Services

Prepare local state first if this is a clean host:

```powershell
npm run flowchain:init
```

Start node and control-plane services with the live profile:

```powershell
npm run flowchain:service:start -- -LiveProfile
```

The live profile rejects bounded `MaxBlocks` mode. Local defaults bind to `127.0.0.1`.

Check safe status:

```powershell
npm run flowchain:service:status
```

Stop or restart without deleting runtime data:

```powershell
npm run flowchain:service:stop
npm run flowchain:service:restart -- -LiveProfile
```

## Optional Relayer Loop

After the Base 8453 env contract is configured and checked, the owner can start the read-only observer loop:

```powershell
npm run flowchain:service:start -- -LiveProfile -StartBridgeRelayerLoop
```

This loop uses the existing Base observer path and does not broadcast. Keep logs under `devnet/local/services/logs/`.

## Readiness Gate

Run:

```powershell
npm run flowchain:live-infra:check
```

The report is written to:

```text
docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json
```

Expected behavior:

- Missing owner inputs produce `blocked` and list env names only.
- Missing local runtime artifacts list artifact names such as `devnet/local/state.json`.
- Stopped supervised processes list pid artifact names such as `devnet/local/services/control-plane.pid`.
- Success requires public RPC, services, backup, bridge live check, bridge infra check, and no-secret scan to pass together.

## Evidence For Review

Use these paths for handoff:

```text
docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json
docs/agent-runs/live-product-infra-rpc/service-status-report.json
docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json
docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json
docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json
docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json
docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json
```
