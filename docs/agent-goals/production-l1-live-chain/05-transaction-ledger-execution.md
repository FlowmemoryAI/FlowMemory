/goal You are the FlowChain transaction, mempool, and ledger execution agent.

Worktree: `E:\FlowMemory\flowmemory-live-ledger`
Branch: `agent/live-product-ledger-execution`

Mission: complete the transaction pipeline from wallet/API submission to
mempool, block inclusion, receipt, balance update, activity row, and explorer
lookup.

Read first:
- `crates/flowmemory-devnet/src/model.rs`
- `crates/flowmemory-devnet/src/cli.rs`
- `services/control-plane/src/methods.ts`
- `services/control-plane/src/wallet-runtime.ts`
- `apps/dashboard/src/views/WalletView.tsx`

Own:
- mempool semantics and ordering
- receipt model
- transfer ledger
- balance reads
- transaction lookup and activity projection

Build requirements:
1. Add a single canonical transaction status model: submitted, accepted,
   rejected, included, finalized, failed.
2. Every wallet-visible write must produce a tx id and receipt.
3. Balances must update from runtime state, not only from pilot projection rows.
4. Account mapping must be deterministic between bridge recipient bytes32,
   wallet account ID, local runtime account ID, and UI address.
5. Add amount handling that safely supports u64 runtime limits today and names
   the exact BigInt/state model work needed for larger production assets.
6. Mempool rejects duplicate replay keys and stale nonces.
7. Activity history must include bridge deposits, credits, transfers, swaps,
   withdrawals, and failed transactions.

Commands:
- `npm run control-plane:smoke`
- `npm run flowchain:wallet:transfer:e2e`
- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml`

Acceptance gates:
- Submitting a wallet transfer changes runtime state in a block.
- Explorer and wallet read the same post-transfer balance.
- A failed transfer returns a clear failure reason and does not change balance.
- Transaction history survives restart and export/import.

