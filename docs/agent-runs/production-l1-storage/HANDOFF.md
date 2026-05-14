# Production L1 Storage Handoff

## What Changed

- Replaced raw state-only persistence with a durable storage layer for the local FlowChain runtime.
- Added storage manifest, atomic writes, snapshots, block/header/tx/receipt/event/object records, and deterministic indexes.
- Added bridge observation, credit, withdrawal intent, release evidence, and replay-key persistence.
- Added deterministic export/import with schema, chain/genesis/root/canonical validation and clean target enforcement.
- Added storage status and storage E2E commands.
- Documented archival policy and updated local devnet docs.

## Output Paths

- Default compatibility state: `devnet/local/state.json`
- Default durable data directory: `devnet/local/storage/`
- Manifest: `devnet/local/storage/manifest.json`
- Index file: `devnet/local/storage/indexes/storage-indexes.json`
- Default export: `devnet/local/export/latest/flowchain-state-export.json`
- Default import target: `devnet/local/imported/state.json`
- Storage E2E output: `devnet/local/storage-e2e/`

## Commands

```powershell
npm run flowchain:export
npm run flowchain:import
npm run flowchain:storage:e2e
```

Direct CLI commands:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- storage-status
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- export-state --out devnet/local/export/latest/flowchain-state-export.json
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/imported/state.json import-state --from devnet/local/export/latest/flowchain-state-export.json
```

## Index Files

RPC/explorer agents should load `indexes/storage-indexes.json` and use:

- `txById`
- `receiptByTxId`
- `eventById`
- `accountToTxIds`
- `accountBalanceChanges`
- `tokenToEventIds`
- `poolToEventIds`
- `rootfieldToEventIds`
- `bridgeEventToObservationId`
- `bridgeObservationById`
- `bridgeCreditById`
- `withdrawalIntentById`
- `releaseEvidenceById`
- `replayKeyById`

## Query Fields For Future RPC/Explorer Agents

- Block: height, hash, parent hash, logical time, tx ids, receipt count, state root.
- Transaction: tx id, block height, block hash, tx path, receipt path, status.
- Receipt: tx id, block height, block hash, status, error, authorization reference.
- Event: event id, type, block height/hash, tx id, object/receipt/account/token/pool/rootfield/bridge ids.
- Account: account id to tx ids and balance changes.
- Token: token id to event ids.
- Pool: pool id to event ids.
- Bridge observation: observation id, source event key, replay key, evidence ref, credit ids, block height.
- Bridge credit: credit id, observation id, account id, asset id, amount, source event key, replay key, block height.
- Withdrawal intent: intent id, account id, asset id, amount, destination chain id, release policy, block height.
- Release evidence: evidence id, withdrawal intent id, source chain id, release tx hash, evidence ref, block height.

## Risks And Follow-Ups

- The local devnet remains no-value/private. This is not production consensus, bridge security, or public validator behavior.
- The current policy is archival; pruning has not been implemented.
- Indexes are file-backed JSON for local pilot scale. A future higher-throughput runtime should move the same contract into an embedded database or append-only storage engine.
