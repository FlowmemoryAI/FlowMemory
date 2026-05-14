# Export/Import Proof

## Default Operator Commands

`npm run flowchain:export` passed.

- Export path: `devnet/local/export/latest/flowchain-state-export.json`
- Bundle path: `devnet/local/export/flowchain-local-state.zip`
- Data directory: `devnet/local/storage`
- Current height: `2`
- Latest hash: `0x72a1ee8fb5c40ccabe086cce3e9eb75ae51efa0e25b2ace6035b98d504511a0e`
- Finalized height: `2`
- State root: `0xde7d0d32db13736b6fa798e6ed03f33b3bf35ed9f8297e74ac4f84369ca3fc58`
- Index health: tx=`16`, receipts=`16`, events=`16`, bridgeCredits=`0`

`npm run flowchain:import` passed.

- Restore path: `devnet/local/imported/state.json`
- Data directory: `devnet/local/imported/storage`
- Current height: `2`
- Latest hash: `0x72a1ee8fb5c40ccabe086cce3e9eb75ae51efa0e25b2ace6035b98d504511a0e`
- Finalized height: `2`
- State root: `0xde7d0d32db13736b6fa798e6ed03f33b3bf35ed9f8297e74ac4f84369ca3fc58`
- Index health: tx=`16`, receipts=`16`, events=`16`, bridgeCredits=`0`

The default export/import preserved the deterministic root and canonical point.

## Bridge Export/Import

`npm run flowchain:storage:e2e` passed.

- Export path: `devnet/local/storage-e2e/flowchain-storage-e2e-export.json`
- Before root: `0xdd86713bd53886defcc5375e1468a2fb552899fc6d16f08b5767703d91fcd64d`
- After root: `0xdd86713bd53886defcc5375e1468a2fb552899fc6d16f08b5767703d91fcd64d`
- Latest/finalized height: `3`
- Bridge observation entries: `1`
- Bridge credit entries: `1`
- Replay key entries: `1`

## Rejected Bad Imports

Rust test: `durable_import_rejects_wrong_chain_and_malformed_roots`

- Wrong `chainId`: rejected.
- Malformed `stateRoot`: rejected.
- Well-shaped but wrong `stateRoot`: rejected.
- Truncated export JSON: rejected.

Rust test: `durable_storage_rejects_manifest_corruption_and_unclean_import`

- Import into an existing target: rejected.
- Unknown future storage version: rejected.
- Old durable storage version: rejected pending explicit migration.
- Bad finalized height: rejected.
- Bad canonical snapshot pointer: rejected.
