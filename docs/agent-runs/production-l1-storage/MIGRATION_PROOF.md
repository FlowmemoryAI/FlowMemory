# Migration Proof

## Implemented Behavior

Legacy local devnet format was a single raw `state.json` file without durable storage manifest or indexes. On load:

1. The raw state file is parsed as `ChainState`.
2. Chain id, genesis hash, roots, block parent chain, latest hash, and next block number are validated.
3. The raw file is copied into `storage/backups/`.
4. The durable layout is committed with manifest, snapshots, blocks, headers, transactions, receipts, events, objects, and indexes.

Unknown future durable versions are refused. Older durable manifest versions are refused until an explicit versioned migration is added. Wrong chain id or wrong genesis hash is refused.

## Proof

Rust test: `durable_storage_migrates_legacy_state_with_backup`

- Writes a legacy raw `state.json`.
- Calls `load_state`.
- Verifies the migrated state root matches the original logical state.
- Verifies `manifest.json` exists.
- Verifies exactly one backup exists under `storage/backups/`.

Rust test: `durable_storage_rejects_manifest_corruption_and_unclean_import`

- Refuses future storage version `99`.
- Refuses old durable storage version `0`.

No additional historical durable format exists in this repository, so no multi-version durable migration was needed for this pass.
