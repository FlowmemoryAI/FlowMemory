# FlowPulse v0

Date: 2026-05-12

## Status

Accepted

## Context

FlowMemory needs an initial on-chain event surface for contract activity that indexers and verifiers can reconstruct from receipts and logs. The project is still in its contracts foundation stage, so the first version needs to be small enough to review safely while preserving the core protocol boundaries already documented in the repository.

The initial contracts foundation includes a `FlowPulse` event schema and a `RootfieldRegistry` skeleton. This decision records the intended meaning and limits of that first schema so future contracts, indexers, and reviewers share the same assumptions.

## Decision

FlowPulse v0 is the first canonical event schema for FlowMemory protocol activity. It emits a domain-separated `pulseId`, a `rootfieldId`, the emitting actor, a compact pulse type, a type-specific subject, a type-specific commitment, an optional parent pulse id, a per-rootfield sequence, a block timestamp, and an advisory URI string.

FlowPulse exists to provide a small, consistent event stream for commitment-oriented protocol actions such as registering a Rootfield namespace or committing a new root. It is not intended to store raw memory, model, media, artifact, or verification payloads.

FlowPulse v0 intentionally excludes:

- Dynamic fee mechanics
- Tokenomics
- Uniswap v4 hook behavior
- Upgrade policy
- Raw AI memory or model data
- Raw artifacts, media, or large evidence payloads
- Contract-claimed `txHash` or `logIndex`
- Enforced URI length, format, content, or resolver policy

`txHash` and `logIndex` are indexer-derived because contracts cannot know final receipt metadata while executing. This is especially important for future hook work: a hook can emit events or update intentional state, but it cannot know the final transaction hash or log index during execution. Indexers and verifiers must derive those values after reading transaction receipts and logs.

Heavy AI, memory, model, artifact, media, and evidence data stays off-chain because on-chain storage is expensive and inappropriate for large or sensitive payloads. FlowPulse v0 commits to off-chain facts with hashes and roots; it does not make the chain a data store for the underlying material.

URI fields are advisory and unenforced in v0. `metadataURI` and `evidenceURI` are arbitrary caller-supplied strings accepted by the current skeleton contract. The contract does not enforce length, content, format, resolvability, or "short pointer" behavior, and emitted URI bytes are still on-chain log data. Keeping heavy or sensitive data out of URI fields is a caller responsibility and verifier policy, not a contract guarantee.

FlowPulse is intentionally minimal so that the first contracts foundation can establish stable event semantics without prematurely committing to fee design, token design, hook integration, verifier economics, proof formats, or appchain assumptions.

## Consequences

FlowPulse v0 gives indexers and verifiers an initial stream to consume without requiring product features or full protocol mechanics. It also keeps the contracts foundation reviewable by limiting on-chain state to compact commitments and metadata needed by the registry skeleton.

The minimal design leaves several responsibilities outside the contract:

- Indexers must attach chain id, contract address, transaction hash, log index, block number, and receipt status from observed chain data.
- Verifiers must resolve and check off-chain content against emitted commitments.
- Callers must avoid placing heavy or sensitive raw data into URI strings.
- Future contracts must define any stronger validation or enforcement rules explicitly.

## Future Versions May Add

- Bounded `bytes32` commitment-only fields where URI strings are unnecessary
- CID or hash-only fields for stricter off-chain artifact references
- URI length caps or validation policy
- Additional FlowPulse type identifiers and type-specific semantics
- Rootflow-specific commitment semantics
- Attestation, receipt, proof, or verifier status events
- Access control and upgrade decisions if protocol governance requires them
- Uniswap v4 hook integration after hook-specific constraints are documented

## Out Of Scope

- Dynamic fees
- Token mechanics or incentives
- Production deployment policy
- Uniswap v4 hooks
- Full indexer or verifier implementation
- Cryptographic proof system design
- Appchain or L1 design
- Hardware signaling semantics
- Storing raw AI memory, model, artifact, media, or evidence data on-chain

## Follow-Ups

- Define the first indexer contract-event ingestion expectations.
- Decide whether future URI fields should be replaced or constrained by bounded commitments, CIDs, hashes, length caps, or validation rules.
- Define additional FlowPulse types only when a concrete contract or verifier workflow needs them.
