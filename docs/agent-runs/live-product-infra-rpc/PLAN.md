# FlowChain Live Infra RPC Plan

Date: 2026-05-15
Branch: `agent/live-product-infra-rpc`

## Scope

Build a fail-closed infrastructure gate for an owner-operated FlowChain pilot host. This work covers public RPC configuration checks, supervised local Windows processes, state backup checks, Base 8453 bridge deployment coordination, safe runbooks, and one aggregate command.

This work does not change runtime state transitions, wallet custody, dashboard design, SDK implementation, or bridge event parsing internals.

## Implementation Order

1. Add public RPC readiness checks under `infra/scripts/flowchain-public-rpc*.ps1`.
2. Add supervised service start/status/stop/restart checks under `infra/scripts/flowchain-service*.ps1`.
3. Add backup verification under `infra/scripts/flowchain-public-rpc-backup-readiness.ps1`.
4. Add Base 8453 bridge infrastructure checks under `infra/scripts/flowchain-live-env-bridge-readiness.ps1`.
5. Add the aggregate `npm run flowchain:live-infra:check` gate.
6. Add operations docs and lockbox runbook.
7. Run the required command set and record evidence in `CHECKLIST.md` and `EXPERIMENTS.md`.

## Input Inventory

| Input or artifact | Owner | Initial status | Checking surface |
| --- | --- | --- | --- |
| `FLOWCHAIN_RPC_PUBLIC_URL` | Owner/operator | blocked-owner-input | public RPC readiness |
| `FLOWCHAIN_RPC_ALLOWED_ORIGINS` | Owner/operator | blocked-owner-input | public RPC readiness |
| `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE` | Owner/operator | blocked-owner-input | public RPC readiness |
| `FLOWCHAIN_RPC_TLS_TERMINATED` | Owner/operator | blocked-owner-input | public RPC readiness |
| `FLOWCHAIN_RPC_STATE_BACKUP_PATH` | Owner/operator | blocked-owner-input | public RPC + backup readiness |
| `devnet/local/state.json` | Node/runtime operator | implemented | service, public RPC, backup readiness |
| `devnet/local/node/flowchain-node.pid` | Node/runtime operator | implemented | service status |
| `devnet/local/services/control-plane.pid` | Infra/operator | implemented | service status |
| `FLOWCHAIN_PILOT_OPERATOR_ACK` | Owner/operator | checked | bridge live check plus bridge infra check |
| `FLOWCHAIN_BASE8453_RPC_URL` | Owner/operator | checked | bridge live check plus bridge infra check |
| `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS` | Owner/operator | implemented | bridge infra bytecode check |
| `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN` | Owner/operator | checked | bridge live check plus bridge infra check |
| `FLOWCHAIN_BASE8453_ASSET_DECIMALS` | Owner/operator | checked | bridge live check plus bridge infra check |
| `FLOWCHAIN_BASE8453_FROM_BLOCK` | Owner/operator | checked | bridge live check plus bridge infra check |
| `FLOWCHAIN_BASE8453_TO_BLOCK` | Owner/operator | checked | bridge live check plus bridge infra check |
| `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI` | Owner/operator | checked | bridge live check plus bridge infra check |
| `FLOWCHAIN_PILOT_TOTAL_CAP_WEI` | Owner/operator | checked | bridge live check plus bridge infra check |
| `FLOWCHAIN_PILOT_CONFIRMATIONS` | Owner/operator | checked | bridge live check plus bridge infra check |
| `FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY` | Owner/operator | checked-name-only | deploy runbook only; never required for readiness |
| `FLOWCHAIN_BASE8453_BROADCAST_ACK` | Owner/operator | checked-name-only | broadcast runbook only; never required for readiness |

## Expected End State

`npm run flowchain:live-infra:check` writes `docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json` and exits 0 only when public RPC, services, backups, and Base 8453 bridge infrastructure are all configured and machine-verified. Without owner inputs, it exits nonzero with `blocked` status and names only missing env or artifact names.
