/goal You are the FlowChain Chain/Network long-loop agent.

Worktree: E:\FlowMemory\flowmemory-chain
Branch: agent/l1-loop-chain-network

Baseline: FlowChain Product Testnet V1 already exists and `npm run flowchain:product-e2e` has passed on main. Build on the existing Rust devnet. Do not create a replacement chain.

Allowed folders:
- crates/flowmemory-devnet/
- devnet/
- infra/scripts/flowchain-*.ps1 only when the script is runtime/network related
- docs/agent-runs/chain-network/
- runtime/network docs under docs/

Forbidden folders:
- apps/dashboard/
- contracts/
- crypto/
- services/bridge-relayer/
- unrelated docs

Create tracking files first:
- docs/agent-runs/chain-network/PLAN.md
- docs/agent-runs/chain-network/CHECKLIST.md
- docs/agent-runs/chain-network/EXPERIMENTS.md
- docs/agent-runs/chain-network/NOTES.md

Quantitative goal: complete 10/10 checks below and keep them checked in CHECKLIST.md:
1. `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` passes.
2. A command `npm run flowchain:network-e2e` or equivalent exists.
3. A three-node local static-peer smoke runs from scripts without manual steps.
4. Each node produces blocks for at least 60 seconds or a bounded deterministic equivalent.
5. At least 20 signed local transactions are accepted, included exactly once, and queryable by id.
6. Restarting a node preserves height, latest hash, mempool state, product token state, DEX state, and bridge-credit state.
7. Export/import preserves deterministic roots for the tested state.
8. Peer/node status reports enough data for the control plane to show health and sync.
9. Product transaction types still pass: transfer, token launch, mint/test funding, pool create, add liquidity, remove liquidity, swap, bridge credit.
10. `npm run flowchain:product-e2e` still passes after your changes.

Implementation constraints:
- Keep local/testnet/no-value semantics.
- Use existing inbox/intake, block, state, receipt, and export/import patterns.
- Do not add tokenomics, fees, slashing, public validators, mainnet behavior, or real bridge custody.
- Do not duplicate state models if an existing map/root/receipt type can be extended.

Feedback loop:
1. Run the smallest Rust unit test for the changed function.
2. Run `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml`.
3. Run the network smoke command you add.
4. Run `npm run flowchain:product-e2e`.
5. If `npm run flowchain:l1-e2e` exists, run it last.

PR output:
- One PR only.
- Link the checklist.
- State exact commands run.
- State remaining blockers for full L1 readiness.
