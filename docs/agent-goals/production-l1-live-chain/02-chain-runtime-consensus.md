/goal You are the FlowChain chain runtime and consensus agent.

Worktree: `E:\FlowMemory\flowmemory-live-runtime`
Branch: `agent/live-product-runtime-consensus`

Mission: upgrade the existing Rust devnet into the production-shaped FlowChain
L1 runtime needed by the wallet and bridge. Build on `crates/flowmemory-devnet/`.
Do not create a parallel chain implementation.

Read first:
- `AGENTS.md`
- `docs/agent-goals/production-l1-live-chain/README.md`
- `crates/flowmemory-devnet/`
- `infra/scripts/flowchain-*.ps1`
- `fixtures/bridge/base8453-runtime-bridge-handoff.json`
- `devnet/local/production-l1-real-funds-readiness/runtime-credit-proof.json`

Own:
- block production, state transition, finality receipt, replay protection
- account/balance ledger for bridged assets and local assets
- runtime transaction intake for wallet transfer, bridge credit, withdrawal
  intent, swap, liquidity, token operations, and operator controls
- deterministic export/import/restart behavior

Build requirements:
1. Keep long-running node mode working with durable state.
2. Add a production profile that separates local test units, bridged assets,
   and runtime asset IDs without losing exact source-chain value.
3. Include signed transaction verification hooks. Until full signature
   enforcement exists, fail closed for public readiness and expose the exact
   remaining validation gap.
4. Guarantee each transaction has a deterministic receipt, status, state root,
   block number, and replay key.
5. Make Base 8453 bridge credits produce spendable runtime balances.
6. Make transfers work from the same wallet/account ID the UI displays, or
   provide a deterministic account-mapping API consumed by the wallet.
7. Persist pending transactions, blocks, receipts, balances, asset mappings,
   bridge replay keys, swaps, and withdrawal intents across restart.

Commands to add or keep green:
- `npm run flowchain:node:smoke`
- `npm run flowchain:multi-node:smoke`
- `npm run flowchain:wallet:transfer:e2e`
- `npm run flowchain:real-value-pilot:runtime`
- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml`

Acceptance gates:
- A fresh node runs for at least 25 blocks.
- Restart preserves height, balances, replay keys, receipts, and state root.
- A credited Base 8453 balance can be transferred in a later block.
- Duplicate bridge credits and duplicate signed transactions are rejected.
- Runtime receipts are queryable by tx id and object id.
- `git diff --check` passes.

