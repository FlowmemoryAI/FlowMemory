# Restart Proof

Proof command: `npm run flowchain:storage:e2e`

The command builds a source storage state, writes it durably, reloads through the storage layer, exports it, imports into a clean directory, then verifies the imported state and indexes.

## Before Restart/Import

- Source state path: `devnet/local/storage-e2e/source/state.json`
- Export path: `devnet/local/storage-e2e/flowchain-storage-e2e-export.json`
- State root: `0xdd86713bd53886defcc5375e1468a2fb552899fc6d16f08b5767703d91fcd64d`
- Latest height: `3`
- Latest hash: `0x8845470877bb4e86282fd6b05a36d10838a2c055a3460be69501d45e143ff544`
- Finalized height: `3`
- Finalized hash: `0x8845470877bb4e86282fd6b05a36d10838a2c055a3460be69501d45e143ff544`

## After Restart/Import

- Imported state path: `devnet/local/storage-e2e/imported/state.json`
- State root: `0xdd86713bd53886defcc5375e1468a2fb552899fc6d16f08b5767703d91fcd64d`
- Latest height: `3`
- Latest hash: `0x8845470877bb4e86282fd6b05a36d10838a2c055a3460be69501d45e143ff544`
- Finalized height: `3`
- Finalized hash: `0x8845470877bb4e86282fd6b05a36d10838a2c055a3460be69501d45e143ff544`

## Query Results

- `txById`: `14`
- `receiptByTxId`: `14`
- `eventById`: `14`
- `bridgeObservationById`: `1`
- `bridgeCreditById`: `1`
- `replayKeyById`: `1`
- Root preserved: `true`
- Bridge credit preserved: `true`
- Replay key preserved: `true`
- Event index preserved: `true`

The Rust test `durable_storage_writes_manifest_records_and_indexes` also reloads the saved state through `load_state` and verifies the same root plus bridge credit and replay-key presence. Pending transactions are part of `ChainState` snapshots and exports; included transactions are promoted into block transaction records.
