/goal You are the FlowChain state, storage, and recovery agent.

Worktree: `E:\FlowMemory\flowmemory-live-storage`
Branch: `agent/live-product-state-storage-recovery`

Mission: make runtime state durable and recoverable. A live product cannot lose
blocks, balances, wallet metadata, bridge replay keys, receipts, or pending
transactions across restart, export/import, or second-computer transfer.

Read first:
- `crates/flowmemory-devnet/src/model.rs`
- `crates/flowmemory-devnet/src/cli.rs`
- `infra/scripts/flowchain-export.ps1`
- `infra/scripts/flowchain-import.ps1`
- `infra/scripts/flowchain-second-computer-*.ps1`
- `devnet/local/`

Own:
- state schema versioning
- export/import
- snapshot validation
- migration checks
- recovery docs

Build requirements:
1. Add schema version and migration guard for runtime state.
2. Export all blocks, balances, bridge credits, replay keys, asset mappings,
   swaps, withdrawals, receipts, pending transactions, and public wallet
   metadata references.
3. Import validates hashes and refuses malformed or secret-bearing bundles.
4. Restart verification proves state root continuity.
5. Add compact snapshots that avoid enormous fixture churn.
6. Add recovery docs for corrupt JSON, stale ports, missing env, and bad
   bridge handoff.
7. Ensure exports do not include vault ciphertext unless explicitly exporting
   an encrypted wallet backup through the wallet backup flow.

Commands:
- `npm run flowchain:export`
- `npm run flowchain:import`
- `npm run flowchain:restart:verify`
- `npm run flowchain:second-computer:bundle`
- `npm run flowchain:no-secret:scan`

Acceptance gates:
- Export/import preserves state root.
- Bridge replay protection survives import.
- Wallet can still read balances and activity after restart/import.
- No secret scan failures.

