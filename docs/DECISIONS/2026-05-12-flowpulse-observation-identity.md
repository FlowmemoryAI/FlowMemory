# FlowPulse Observation Identity

Date: 2026-05-12

## Status

Accepted for the MVP foundation.

## Context

FlowPulse contracts emit a `pulseId`, but contracts cannot know final receipt metadata such as `txHash`, `transactionIndex`, `logIndex`, `blockNumber`, or `blockHash` during execution. This is especially important for future Uniswap v4 hook work: hooks can emit events, but they cannot know final transaction metadata while running.

The indexer needs a canonical identity for an observed FlowPulse log after receipts/logs are available. The identity must distinguish reorged occurrences, support deterministic verifier reports, and avoid treating advisory URI data as trusted evidence.

## Decision

FlowMemory will use three separate identifiers in the indexer/verifier MVP:

- `pulseId`: emitted by the contract inside the FlowPulse event.
- `observationId`: derived by the indexer from receipt/log metadata after execution.
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

The indexer derives `observationId` from:

- Domain: `flowmemory.flowpulse.observation.v0`
- `chainId`
- `emittingContract`
- `eventSignature`
- `blockNumber`
- `blockHash`
- `txHash`
- `transactionIndex`
- `logIndex`

Preimage:

```text
keccak256(abi.encode(
  "flowmemory.flowpulse.observation.v0",
  chainId,
  emittingContract,
  eventSignature,
  blockNumber,
  blockHash,
  txHash,
  transactionIndex,
  logIndex
))
```

`blockHash` and `blockNumber` are included so a reorged log occurrence and a later re-mined occurrence can be represented as distinct observations. `eventSignature` is included so the identity is explicitly scoped to FlowPulse v0 logs, not arbitrary logs at the same receipt location.

Decoded fields such as `pulseId`, `rootfieldId`, `actor`, `pulseType`, `subject`, `commitment`, `parentPulseId`, `sequence`, `occurredAt`, and `uri` are stored with the observation but are not part of the identity preimage. If the same `observationId` is observed with different decoded fields, that is an indexer integrity failure.

## Lifecycle Names

- `pending`: candidate scan work or pre-receipt/pre-finality context.
- `mined`: successful receipt contains a decodable FlowPulse log and `observationId` exists.
- `finalized`: mined observation remains canonical after the configured finality policy.
- `reorged`: observation block/log is no longer canonical or was marked removed.

The MVP does not require mempool indexing. A canonical `observationId` begins at `mined`.

## Duplicate Names

- Exact duplicate: same `observationId` and same decoded content; idempotent replay.
- Conflicting duplicate: same `observationId` but changed decoded content or metadata; indexer integrity failure.
- Pulse duplicate: same contract-emitted `pulseId` but different `observationId`; separate observations that require verifier/operator policy.
- Reorg replacement: different `observationId` caused by changed `blockHash`, block position, transaction position, or log position.

## Report ID

The verifier derives `reportId` from the canonical report body:

```text
keccak256(canonical_json(reportCore))
```

The `reportCore` includes `schema = flowmemory.verifier.report.v0`, `observationId`, observed receipt/log metadata, decoded FlowPulse fields, status, reason codes, resolver policy id, and verifier spec version. The report id does not include signatures, wall-clock generation timestamps, local file paths, or operator notes.

## Consequences

- Indexers can distinguish contract-emitted pulse identity from observed-log identity.
- Reorged observations remain addressable for audits without being treated as current canonical facts.
- Verifiers can produce deterministic reports bound to receipt/log facts.
- Dashboards and explorers can distinguish observed, verified, unresolved, unsupported, failed, reorged, stale, disputed, and superseded outcomes later without changing the observation identity.

## Out Of Scope

- Production indexer runtime.
- Live RPC integration.
- Database schema.
- Verifier economics.
- Proof network.
- Artifact canonicalization format.
- Resolver policy.
- Report signing or verifier attestation implementation.

## Follow-Ups

- Define artifact commitment canonicalization.
- Define resolver policy v0.
- Define Base finality policy.
- Decide whether future report attestations should use EIP-712 or another signature format.
