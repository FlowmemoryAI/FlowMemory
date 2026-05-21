# FlowChain Owner Env Readiness

Generated: 2026-05-21T10:35:44.5255103Z
Status: blocked

This gate points the live checks at the ignored local owner env file and records only env names, statuses, and redacted child output.

Owner env file: `devnet/local/owner-inputs/flowchain-owner.local.env`
Inside repo: True
Git ignored: True

## Setup Required

- Public DNS plus TLS edge or tunnel forwarding HTTPS traffic to the local FlowChain control plane on `127.0.0.1:8787`.
- Explicit browser origins and a per-minute public request limit for the RPC edge.
- A tester write gateway flag, SHA-256 token digest, and per-send cap before public friends-and-family wallet writes.
- An always-on host that keeps the node and control plane running.
- A writable state backup directory for public operation.
- A Base 8453 provider endpoint, deployed lockbox address, supported token address, block range, confirmations, and capped pilot limits for the bridge observer.

## Required Env Names

- `FLOWCHAIN_RPC_PUBLIC_URL`
- `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
- `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
- `FLOWCHAIN_RPC_TLS_TERMINATED`
- `FLOWCHAIN_RPC_STATE_BACKUP_PATH`
- `FLOWCHAIN_TESTER_WRITE_ENABLED`
- `FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256`
- `FLOWCHAIN_TESTER_MAX_SEND_UNITS`
- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_CURSOR_STATE`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`

## Step Status

| Step | Status | Report |
| --- | --- | --- |
| Owner input contract from local env file | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\owner-inputs-report.json` |
| Live infrastructure with local env file | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\flowchain-live-infra-check-report.json` |
| Public deployment contract with local env file | blocked | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\public-deployment-contract-report.json` |

## Next Commands

- npm run flowchain:owner-env:template
- npm run flowchain:owner-env:readiness -- -AllowBlocked
- npm run flowchain:completion:audit -- -AllowBlocked

The runner is working and remains blocked only on the missing owner env names listed in the JSON report.
