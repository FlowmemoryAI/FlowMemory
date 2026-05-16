# FlowChain Owner Env Readiness

Generated: 2026-05-16T20:49:23.9829806Z
Status: failed

This gate points the live checks at the ignored local owner env file and records only env names, statuses, and redacted child output.

Owner env file: `docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation/missing-owner-env.local`
Inside repo: True
Git ignored: False

## Setup Required

- Public DNS plus TLS edge or tunnel forwarding HTTPS traffic to the local FlowChain control plane on `127.0.0.1:8787`.
- Explicit browser origins and a per-minute public request limit for the RPC edge.
- An always-on host that keeps the node and control plane running.
- A writable state backup directory for public operation.
- A Base 8453 provider endpoint, deployed lockbox address, supported token address, block range, confirmations, and capped pilot limits for the bridge observer.

## Required Env Names

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
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`

## Step Status

| Step | Status | Report |
| --- | --- | --- |
| owner env path safety | failed | `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\owner-env-readiness-validation\missing-owner-env-file-report.json` |

## Next Commands

- npm run flowchain:owner-env:template
- npm run flowchain:owner-env:readiness -- -AllowBlocked
- npm run flowchain:completion:audit -- -AllowBlocked

Fix the owner env file path, git-ignore state, or invalid owner values before sharing the public network.
