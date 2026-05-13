# FlowPulse Observation Identity

Date: 2026-05-12

## Status

Accepted for the V0 local indexer/verifier package.

## Context

FlowPulse contracts emit a `pulseId`, but contracts cannot know final receipt metadata such as `txHash`, `transactionIndex`, `logIndex`, `blockNumber`, or `blockHash` during execution. This matters for future hook work: hooks can emit events, but they cannot know final transaction metadata while running.

The indexer needs a canonical identity for an observed FlowPulse log after receipts/logs are available. The verifier then needs deterministic report identities bound to those observations.

## Decision

FlowMemory V0 uses separate identifiers:

- `pulseId`: emitted by the contract inside the FlowPulse event.
- `observationId`: derived by the indexer from receipt/log location after execution.
- `cursorId`: derived by the indexer for source-set scan progress.
- `reportId`: derived by the verifier from canonical JSON report content.

`pulseId` is protocol data, not canonical observation identity.

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

The indexer derives `observationId` from:

- Domain: `flowmemory.flowpulse.observation.v0`
- `chainId`
- `sourceContract`
- `txHash`
- `logIndex`

Preimage:

```text
keccak256(abi.encode(
  "flowmemory.flowpulse.observation.v0",
  chainId,
  sourceContract,
  txHash,
  logIndex
))
```

`sourceContract` is the normalized emitting contract address. `txHash` and `logIndex` are receipt/log-derived values. Decoded fields such as `pulseId`, `rootfieldId`, `actor`, `pulseType`, `subject`, `commitment`, `parentPulseId`, `sequence`, `occurredAt`, and `uri` are stored with the observation but are not part of the identity preimage.

`blockHash`, `blockNumber`, `transactionIndex`, and `eventSignature` are also stored with the observation. They are used for ordering, display, finality, and reorg checks, but they are not part of the V0 `observationId` preimage.

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

The verifier derives `reportId` from:

```text
keccak256(canonical_json(reportCore))
```

The `reportCore` includes `schema = flowmemory.verifier.report.v0`, `observationId`, observed receipt/log metadata, decoded FlowPulse fields, status, reason codes, evidence refs, resolver policy id, and verifier spec version. The report id does not include wall-clock timestamps, local file paths, signatures, or operator notes.

## Consequences

- Contracts remain unaware of receipt-only metadata.
- Indexers can distinguish protocol pulse identity from observed-log identity.
- Cursor progress can include block hash without changing observation identity.
- Verifiers can produce deterministic reports bound to indexed observations.
- Reorg and finality handling remains explicit state, not hidden inside `observationId`.

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
