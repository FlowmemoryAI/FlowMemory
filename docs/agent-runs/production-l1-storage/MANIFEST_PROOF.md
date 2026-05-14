# Manifest Proof

Manifest path for default state: `devnet/local/storage/manifest.json`

## Stored Fields

- `schema`
- `storageVersion`
- `chainId`
- `genesisHash`
- `dataDirectory`
- `latestHeight`
- `latestHash`
- `finalizedHeight`
- `finalizedHash`
- `stateRoot`
- `mapRoots`
- `pruningPolicy`
- `archival`
- `createdToolVersion`
- `compatibilityStatePath`

## Validation

Startup validates:

- Manifest schema equals `flowmemory.local_devnet.storage_manifest.v1`.
- Storage version is known and current.
- Chain id matches the local devnet chain id.
- Genesis hash matches the local devnet genesis hash.
- Finalized height does not exceed latest height.
- Latest hash, finalized hash, and state root are well-shaped roots.
- Manifest chain id, genesis hash, latest height/hash, finalized height/hash, and state root match the latest snapshot.

## Proof

- `durable_storage_writes_manifest_records_and_indexes` proves the manifest is written and reloadable.
- `durable_storage_rejects_manifest_corruption_and_unclean_import` proves future storage version, old durable storage version, bad finalized height, and bad canonical snapshot pointer are rejected.
- `npm run flowchain:export` printed manifest-derived data directory, height, latest hash, finalized height, state root, and index health.
- `npm run flowchain:import` printed the same restored canonical point and root for the imported state.
