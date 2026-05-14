# Production L1 Storage Contract

Status: implemented for the private/local FlowChain devnet runtime.

## Schemas

- Manifest schema: `flowmemory.local_devnet.storage_manifest.v1`
- Export schema: `flowmemory.local_devnet.storage_export.v1`
- Index schema: `flowmemory.local_devnet.storage_indexes.v1`
- Event schema: `flowmemory.local_devnet.storage_event.v1`
- Storage version: `1`
- Storage policy: `archival`

## Directory Layout

Default state path: `devnet/local/state.json`

Default durable data directory:

```text
devnet/local/storage/
  manifest.json
  blocks/{height:020}.json
  headers/{height:020}.json
  transactions/{tx_id}.json
  receipts/{tx_id}.json
  events/{event_id}.json
  objects/*.json
  indexes/storage-indexes.json
  snapshots/{height:020}.json
  snapshots/latest.json
  backups/
  tmp/
```

Custom state paths use a sibling `<state-file>.storage/` directory unless the state file is named `state.json`, which uses sibling `storage/`.

## Manifest Record

`manifest.json` is written after block, header, transaction, receipt, event, object, index, and snapshot records. It contains:

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

Startup validates schema, known storage version, expected chain id, expected genesis hash, root shape, finalized height not exceeding latest height, and equality with the loaded snapshot.

## Durable Records

- Block record: full `Block` including block number, parent hash, logical time, tx ids, transaction bodies, receipts, state root, and block hash.
- Header record: `BlockHeaderRecord` with block number, parent hash, logical time, tx ids, receipt count, state root, and block hash.
- Transaction record: `TxRecord` with tx id, block height/hash, and transaction envelope.
- Receipt record: `ReceiptRecord` with tx id, block height/hash, status, error, and local authorization reference if present.
- Event record: `EventRecord` with event id, event type, block height/hash, tx id, receipt status, object/receipt ids, account/token/pool/rootfield ids, bridge ids, replay key, and payload.
- Object maps: one deterministic JSON map per mutable state family under `objects/`.
- Snapshot: full `ChainState` at the latest height plus `snapshots/latest.json`.

## Root Inputs

`stateRoot` is deterministic canonical JSON hashed with Keccak-256. Inputs include:

- Schema, chain id, genesis hash, latest height/hash, finalized height/hash.
- Operator references, rootfields, agent accounts, local balances, faucet records, balance transfers.
- Token definitions, token balances, token mint receipts, DEX pools, LP positions, liquidity receipts, swap receipts.
- Model passports, memory cells, challenges, finality receipts.
- Artifact commitments, availability proofs, verifier modules, work receipts, verifier reports.
- Imported FlowPulse observations and imported verifier reports.
- Bridge observations, bridge credits, withdrawal intents, release evidence, consumed replay keys.
- Base anchor placeholders.

Excluded inputs: local logs, wall-clock timestamps, absolute machine paths, process ids, env files, node inbox files, and local operator secret material.

## Indexes

`indexes/storage-indexes.json` contains:

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

These indexes are rebuilt deterministically from state and block transaction bodies. Startup validates index keys and referenced tx/receipt/event files. Missing derived records or invalid indexes are regenerated from the durable snapshot.

## Atomicity And Recovery

The write path serializes deterministic JSON to a temporary file and renames it into place for every durable JSON record. The canonical manifest is moved last. Startup removes leftover `*.tmp` files and validates the manifest against the latest snapshot. If derived records or indexes are incomplete, they are rebuilt by recommitting the snapshot. A partially written record cannot become the canonical tip unless the manifest also validates against it.

## Export And Import

Exports are self-describing JSON with manifest, canonical point, state root, map roots, included-files list, evidence-safety metadata, full state, and indexes. Import validates schema, storage version, chain id, genesis hash, root shape, root contents, canonical point, manifest, and indexes. Import refuses non-clean targets.

## Pruning Policy

The implemented default is archival. No pruning command exists in this pass. Old blocks, headers, transactions, receipts, events, snapshots, object maps, and indexes remain available.
