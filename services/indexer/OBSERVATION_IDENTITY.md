# FlowPulse Observation Identity

This is the indexer-facing identity model for FlowPulse V0.

## Identity Layers

- `pulseId`: emitted by the FlowPulse contract.
- `observationId`: derived by the indexer from receipt/log location after execution.
- `cursorId`: derived by the indexer for source-set scan progress.
- `reportId`: derived by the verifier from canonical report content.

## Required Fields

Decoded from FlowPulse:

- `pulseId`
- `rootfieldId`
- `actor`
- `pulseType`
- `subject`
- `commitment`
- `parentPulseId`
- `sequence`
- `occurredAt`
- `uri`

Attached from receipt/log context:

- `chainId`
- `emittingContract`
- `eventSignature`
- `blockNumber`
- `blockHash`
- `txHash`
- `transactionIndex`
- `logIndex`
- `receiptStatus`

Receipt/log fields are derived after execution. Contracts and hooks do not know them.

## Observation ID

`observationId` identifies a specific observed FlowPulse log location:

```text
keccak256(abi.encode(
  "flowmemory.flowpulse.observation.v0",
  chainId,
  sourceContract,
  txHash,
  logIndex
))
```

Canonicalization before hashing:

- `sourceContract` is the normalized emitting contract address.
- `txHash` is a normalized 32-byte transaction hash.
- `logIndex` is a nonnegative integer.
- `chainId` is serialized as a uint256 ABI value.
- Hash function is EVM Keccak-256.

`blockHash`, `blockNumber`, `transactionIndex`, `eventSignature`, and decoded FlowPulse fields are stored with the observation for audit and reorg handling, but they are not part of the V0 observation-id preimage.

## Cursor ID

`cursorId` identifies scan progress for a configured source set:

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

`sourceSetId` is:

```text
keccak256("flowmemory.indexer.source_set.v0|<chainId>|<sorted lower-case addresses>")
```

Cursor identity includes `blockHash` because scan progress must be able to detect replays over a changed canonical chain.

## State Model

- `observed`: decoded from a successful receipt/log with no finality policy applied.
- `pending`: decoded but above the configured fixture finality threshold.
- `finalized`: at or below the configured fixture finality threshold.
- `removed`: provider fixture marks the log removed.
- `superseded`: older observation for the same `pulseId` is replaced by another observation.
- `reorged`: canonical block-hash check says the indexed block is no longer canonical.

This model is enough for fixtures and tests. It is not production reorg handling.

## Duplicate Rules

Exact duplicate:

- Same `observationId`.
- Same canonical observation JSON.
- Safe to treat as idempotent replay.

Conflicting duplicate:

- Same `observationId`.
- Required metadata or decoded fields differ.
- Treat as an indexer integrity failure.

Pulse duplicate:

- Same contract-emitted `pulseId`.
- Different `observationId`.
- Preserve both observations for verifier/operator policy.

Reorg replacement:

- Same `pulseId`.
- Different block/log location.
- Previous observation may become `superseded` or `reorged` depending on canonicality evidence.

Unsupported observation:

- FlowPulse is decoded but current verifier rules do not support the pulse type or artifact semantics.
- Preserve the observation and let verifier status become `unsupported`.

## Non-Goals

- No production live RPC service.
- No production database schema.
- No production reorg worker.
- No tokenomics or verifier economics.
- No secrets in env files.
