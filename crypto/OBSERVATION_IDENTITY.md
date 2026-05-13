# FlowPulse Observation Identity

Status: draft v0.

This document defines how FlowMemory names FlowPulse facts after they are observed by an indexer or verifier.

## Identifier Roles

### `pulseId`

`pulseId` is emitted by the contract. In the current `RootfieldRegistry` skeleton it is computed as:

```solidity
keccak256(abi.encode(
  FlowPulseTypes.SCHEMA_ID,
  block.chainid,
  address(this),
  rootfieldId,
  actor,
  pulseType,
  subject,
  commitment,
  parentPulseId,
  sequence
))
```

Use `pulseId` to link semantic protocol activity across docs, reports, and app views. Do not use it as the only canonical observed-log key.

### `observationId`

`observationId` is derived after a transaction receipt and log metadata exist. It binds a FlowPulse log to a concrete chain position.

Type string:

```solidity
FlowPulseObservationV0(uint256 chainId,address emittingContract,uint64 blockNumber,bytes32 blockHash,bytes32 txHash,uint32 transactionIndex,uint32 logIndex,bytes32 eventSignature,bytes32 pulseId,bytes32 rootfieldId)
```

Hash:

```text
observationId = keccak256(abi.encode(
  FLOWPULSE_OBSERVATION_TYPEHASH,
  chainId,
  emittingContract,
  blockNumber,
  blockHash,
  txHash,
  transactionIndex,
  logIndex,
  eventSignature,
  pulseId,
  rootfieldId
))
```

Field sources:

- `chainId`: chain configuration or receipt context.
- `emittingContract`: log emitter address.
- `blockNumber`: receipt or block metadata.
- `blockHash`: receipt or block metadata.
- `txHash`: transaction receipt identifier.
- `transactionIndex`: transaction position in the block.
- `logIndex`: log position from receipt/RPC metadata.
- `eventSignature`: topic 0 for `FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)`.
- `pulseId`: topic 1 from the event.
- `rootfieldId`: topic 2 from the event.

`txHash`, `transactionIndex`, and `logIndex` do not exist during contract execution. They must never be treated as hook-known or contract-known values.

### `reportId`

`reportId` identifies a deterministic verifier report. It is derived from the report body, not from the verifier signature.

Type string:

```solidity
FlowMemoryVerifierReportV0(bytes32 reportSchemaHash,bytes32 observationId,bytes32 receiptHash,bytes32 verifierId,bytes32 verifierSetRoot,uint8 status,bytes32 checksRoot,uint64 finalizedBlockNumber,bytes32 finalizedBlockHash,uint16 reportVersion)
```

Hash:

```text
reportId = keccak256(abi.encode(
  VERIFIER_REPORT_TYPEHASH,
  reportSchemaHash,
  observationId,
  receiptHash,
  verifierId,
  verifierSetRoot,
  status,
  checksRoot,
  finalizedBlockNumber,
  finalizedBlockHash,
  reportVersion
))
```

The verifier signature envelope signs `reportId`; the signature is not part of `reportId`.

### `cursorId`

`cursorId` identifies an indexer checkpoint for an ordered stream. It is not a replacement for `observationId`; it points to the latest observation accepted by that stream.

Type string:

```solidity
FlowMemoryIndexerCursorV0(bytes32 sourceId,bytes32 streamId,uint64 sequence,bytes32 observationId,bytes32 previousCursorId)
```

Hash:

```text
cursorId = keccak256(abi.encode(
  INDEXER_CURSOR_TYPEHASH,
  sourceId,
  streamId,
  sequence,
  observationId,
  previousCursorId
))
```

## Reorg Handling

`observationId` includes `blockHash`, so a reorg creates a different observation. Verifiers should model state transitions like this:

```text
observed -> pending_finality -> verified
observed -> reorged
verified -> superseded
failed -> superseded
```

Requirements:

- A pre-finality observation can be useful but must be labeled pending or observed.
- A reorged observation must not silently mutate into a new observation id.
- A report over a reorged observation should be marked `reorged` or `superseded`.
- Apps must display `pulseId` and `observationId` differently when both are relevant.

## Duplicate Handling

Duplicate logs with the same `(chainId, emittingContract, txHash, logIndex)` should produce the same `observationId`.

Duplicate `pulseId` values in different block contexts are not necessarily duplicates. Verifiers must compare the full observation identity and the event args hash before collapsing them.

## Rootfield Context

`rootfieldId` is part of observation identity because FlowPulse events are Rootfield-scoped. The same `pulseId` and `rootfieldId` can be used to trace semantic continuity, while `observationId` gives receipt-level uniqueness.
