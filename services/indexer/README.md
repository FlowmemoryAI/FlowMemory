# FlowMemory Indexer V0

This package is a local, fixture-first FlowPulse indexer. It decodes sample receipts/logs, derives deterministic observation and cursor identities, models basic lifecycle states, and writes canonical JSON. It is not a production indexer.

## Commands

From the repository root:

```powershell
npm run index:fixtures
npm run demo:indexer
npm test --prefix services/indexer
```

`npm run index:fixtures` writes:

```text
services/indexer/out/indexer-state.json
```

Use a custom output path:

```powershell
npm run index:fixtures -- --out out/custom-state.json
```

## Fixtures

Primary receipt fixtures:

```text
services/indexer/fixtures/flowpulse-receipts.json
```

The fixture set covers:

- valid rootfield registration
- valid root commit
- duplicate observation
- removed/reorg-style log
- invalid commitment input
- unresolved artifact input
- unsupported pulse type
- reverted receipt
- malformed log

Legacy single-log fixture:

```text
services/indexer/fixtures/flowpulse-logs.json
```

## Decoder

The decoder accepts FlowPulse v0 logs with:

```text
FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)
```

`topic0` must equal:

```text
0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43
```

Decoded indexed topics:

- `pulseId`
- `rootfieldId`
- `actor`

Decoded data fields:

- `pulseType`
- `subject`
- `commitment`
- `parentPulseId`
- `sequence`
- `occurredAt`
- `uri`

Malformed logs are rejected into `rejectedLogs` with deterministic reason codes.

## Observation Identity

The contract emits `pulseId`. The indexer derives `observationId` only after receipt/log metadata exists:

```text
keccak256(abi.encode(
  "flowmemory.flowpulse.observation.v0",
  chainId,
  sourceContract,
  txHash,
  logIndex
))
```

`txHash` and `logIndex` are receipt/log-derived. They are not known by contracts or hooks during execution.

## Cursor Identity

The indexer derives `cursorId` for scan progress:

```text
keccak256(abi.encode(
  "flowmemory.indexer.cursor.v0",
  chainId,
  sourceSetId,
  blockNumber,
  blockHash,
  transactionIndex,
  logIndex
))
```

The `sourceSetId` is deterministic over chain id and the normalized emitting-contract set.

## Lifecycle States

V0 state values:

- `observed`
- `pending`
- `finalized`
- `removed`
- `superseded`
- `reorged`

The fixture state model supports a finality threshold and block-hash mismatch checks. It does not claim production reorg handling.

## Duplicate Handling

- `exactDuplicate`: same `observationId` and canonical observation JSON.
- `conflictingDuplicate`: same `observationId` with different canonical content.
- `pulseDuplicate`: same contract `pulseId` at a different observation location.
- `reorgReplacement`: same `pulseId` with changed block/log location.

Exact duplicates are idempotent. Conflicting duplicates are an indexer integrity risk. Pulse duplicates and reorg replacements stay visible for verifier/operator policy.

## Persistence

The persisted file wraps indexer state with:

```text
flowmemory.indexer.persistence.v0
```

The state itself declares:

```text
flowmemory.indexer.state.v0
```

JSON output is deterministic and contains observations, cursors, batches, rootfields, pulses, rejected logs, and duplicate records.

The JSON schema fixture lives at:

```text
services/indexer/fixtures/indexer-state.schema.json
```

## Local RPC Boundary

`readLocalRpcFlowPulseLogs` maps explicit JSON-RPC responses into the same raw fixture shape. It has no default RPC URL, no env file, no secrets, and tests use mocked fetch responses. Future live RPC indexing should be handled by a separate scoped issue.

See [docs/INDEXER_VERIFIER_MVP.md](../../docs/INDEXER_VERIFIER_MVP.md) for the full pipeline.
