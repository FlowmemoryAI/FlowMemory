# FlowPulse Observation Identity

Date: 2026-05-12

## Status

Accepted for the V0 local indexer/verifier package and MVP foundation.

## Context

FlowPulse contracts emit a `pulseId`, but contracts cannot know final receipt metadata such as `txHash`, `transactionIndex`, `logIndex`, `blockNumber`, or `blockHash` during execution. This is especially important for future Uniswap v4 hook work: hooks can emit events, but they cannot know final transaction metadata while running.

The indexer needs a canonical identity for an observed FlowPulse log after receipts/logs are available. The identity must distinguish reorged occurrences, support deterministic verifier reports, and avoid treating advisory URI data as trusted evidence.

## Decision

FlowMemory V0 uses separate identifiers:

- `pulseId`: emitted by the contract inside the FlowPulse event.
- `observationId`: derived by the indexer from receipt/log metadata after execution.
- `cursorId`: derived by the indexer for deterministic fixture scan progress.
- `reportId`: derived by the verifier from canonical JSON report content.

`pulseId` is protocol data, not canonical observation identity. The canonical indexer identity is `observationId`.

## FlowPulse Event Signature

The v0 event signature is:

```text
FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)
```

The `topic0` hash is:

```text
0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43
```

## Observation ID

The indexer derives `observationId` from the crypto V0 type:

```text
FlowPulseObservationV0(uint256 chainId,address emittingContract,uint64 blockNumber,bytes32 blockHash,bytes32 txHash,uint32 transactionIndex,uint32 logIndex,bytes32 eventSignature,bytes32 pulseId,bytes32 rootfieldId)
```

Fields:

- `chainId`
- `emittingContract`
- `blockNumber`
- `blockHash`
- `txHash`
- `transactionIndex`
- `logIndex`
- `eventSignature`
- `pulseId`
- `rootfieldId`

Preimage:

```text
keccak256(abi.encode(
  keccak256("FlowPulseObservationV0(uint256 chainId,address emittingContract,uint64 blockNumber,bytes32 blockHash,bytes32 txHash,uint32 transactionIndex,uint32 logIndex,bytes32 eventSignature,bytes32 pulseId,bytes32 rootfieldId)"),
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

`blockHash` and `blockNumber` are included so a reorged log occurrence and a later re-mined occurrence can be represented as distinct observations. `eventSignature` scopes the identity to FlowPulse v0 logs, not arbitrary logs at the same receipt location.

Decoded fields such as `actor`, `pulseType`, `subject`, `commitment`, `parentPulseId`, `sequence`, `occurredAt`, and `uri` are stored with the observation but are not part of the identity preimage. If the same `observationId` is observed with different decoded fields, that is an indexer integrity failure.

## Cursor ID

The indexer derives `cursorId` from:

- Domain: `flowmemory.indexer.cursor.v0`
- `chainId`
- `sourceSetId`
- `blockNumber`
- `blockHash`
- `transactionIndex`
- `logIndex`

Preimage:

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

`sourceSetId` is a deterministic hash of the chain id and normalized emitting-contract set. Cursor identity includes block hash so scan progress can detect a changed canonical chain.

## Lifecycle Names

- `observed`: successful receipt contains a decodable FlowPulse log and no finality policy is applied.
- `pending`: decoded observation is above the configured finality threshold.
- `finalized`: decoded observation is at or below the configured finality threshold.
- `removed`: provider marks the log removed.
- `superseded`: an older observation for the same `pulseId` was replaced.
- `reorged`: canonical block-hash check shows the indexed block is no longer canonical.

The V0 package models these states with fixtures. It does not implement production reorg handling.

## Duplicate Names

- Exact duplicate: same `observationId` and same canonical observation JSON; idempotent replay.
- Conflicting duplicate: same `observationId` but changed canonical content; indexer integrity failure.
- Pulse duplicate: same contract-emitted `pulseId` but different `observationId`; preserve both observations.
- Reorg replacement: same `pulseId` at a changed block/log location.

## Report ID

The verifier derives `reportId` from the canonical report body:

```text
keccak256(canonical_json(reportCore))
```

The `reportCore` includes `schema = flowmemory.verifier.report.v0`, `observationId`, observed receipt/log metadata, decoded FlowPulse fields, status, reason codes, evidence refs, resolver policy id, and verifier spec version. The report id does not include signatures, wall-clock generation timestamps, local file paths, or operator notes.

## Consequences

- Contracts remain unaware of receipt-only metadata.
- Indexers can distinguish contract-emitted pulse identity from observed-log identity.
- Reorged observations remain addressable for audits without being treated as current canonical facts.
- Cursor progress can include block hash without changing observation identity.
- Verifiers can produce deterministic reports bound to receipt/log facts.
- Dashboards and explorers can distinguish observed, verified, unresolved, unsupported, failed, reorged, stale, disputed, and superseded outcomes later without changing the observation identity.

## Out Of Scope

- Production indexer runtime.
- Production live RPC deployment.
- Production database schema.
- Verifier economics.
- Proof network.
- Artifact canonicalization format.
- Resolver policy beyond local fixtures.
- Report signing or verifier attestation implementation.

## Follow-Ups

- Define artifact commitment canonicalization.
- Define resolver policy beyond local fixtures.
- Define Base finality policy.
- Define durable persistence schema.
- Decide whether future report attestations should use EIP-712 or another signature format.
