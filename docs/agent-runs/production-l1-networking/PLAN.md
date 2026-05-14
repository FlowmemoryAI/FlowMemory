# Production L1 Networking Plan

## Scope

- Worktree: `E:\FlowMemory\flowmemory-prod-networking`
- Branch: `agent/production-l1-networking`
- Allowed folders: `crates/flowmemory-devnet/`, `devnet/`, `infra/scripts/flowchain-*.ps1`, `docs/LOCAL_DEVNET.md`, `docs/agent-runs/production-l1-networking/`, `package.json` for network aliases only.
- Forbidden folders: `services/`, `contracts/`, `crypto/`, `apps/dashboard/`, `hardware/`, local secret files.

## Approach

1. Inspect the current Rust devnet state model, CLI, storage, and smoke scripts.
2. Add a local/private network contract around node identity, peer config, handshakes, peer status, deterministic sync, transaction relay, and block reconciliation.
3. Keep the implementation inside the existing devnet runtime and Windows wrapper scripts.
4. Produce machine-readable reports under `devnet/local/multi-node-smoke/` and `devnet/local/network-e2e/`.
5. Document the peer config shape, status fields, RPC/dashboard-safe metadata, and runnable command surface.

## Acceptance Mapping

- Static peer config: node ID, addresses, chain ID, genesis hash, role, data directory, static peers.
- Handshake: chain ID, genesis hash, protocol version, latest height/hash, sync status, rejection reasons.
- Status: connected, disconnected, wrong chain, wrong genesis, unsupported protocol, syncing, caught up, last seen height/hash.
- Propagation/reconciliation: submitted transaction appears on another node after sync with shared height and state root.
- Restart: stopped node catches up after peer advances, or reports an exact blocker.
- Negative cases: wrong chain, wrong genesis, stale block, invalid parent block, duplicate transaction.
- Checks: `npm run flowchain:multi-node:smoke`, optional `npm run flowchain:network:e2e`, `git diff --check`.

## Completed Shape

- Runtime: deterministic local-file private networking in `crates/flowmemory-devnet/`.
- Strict command: `npm run flowchain:network:e2e`.
- Required smoke: `npm run flowchain:multi-node:smoke`.
- Reports: `devnet/local/network-e2e/network-e2e-report.json` and `devnet/local/multi-node-smoke/multi-node-smoke-report.json`.
- Handoff: `docs/agent-runs/production-l1-networking/HANDOFF.md`.
