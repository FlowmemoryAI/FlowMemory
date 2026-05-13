# Artifact Registry v0 Boundary

Date: 2026-05-13

## Status

Accepted

## Context

FlowMemory needs a contract surface for referencing artifacts without storing raw AI memory, model outputs, media, datasets, or large evidence payloads on-chain.

## Decision

ArtifactRegistry v0 stores compact artifact commitments only. A record binds an `artifactId` to:

- `rootfieldId`
- `artifactType`
- `commitmentHash`
- `schemaHash`
- `metadataHash`
- `owner` and `submitter`
- lifecycle status

The advisory `artifactURI` and `evidenceURI` fields are emitted as event strings only. They are not stored as canonical artifact data and are not validated for length, content, format, scheme, resolvability, or short-pointer behavior.

## Commitment Semantics

`commitmentHash`, `schemaHash`, and `metadataHash` are bytes32 commitments. V0 does not define canonical serialization, hashing, resolver policy, content addressing, or artifact availability guarantees. Verifiers must decide how to resolve and check off-chain artifact data against these commitments.

## Status Lifecycle

V0 supports `Active` and owner-only `Deprecated`. Deprecation is a signal that later consumers should prefer newer artifacts or policies. It is not a deletion, slashing event, dispute result, or proof of invalidity.

## Intentionally Excluded

- Raw artifact storage
- Contract-enforced URI validation
- Canonical CID/hash-only resolver policy
- Artifact availability guarantees
- Access control beyond artifact-owner deprecation
- Token staking, payments, rewards, or slashing
- Production audit claims

## Future Options

Future versions should decide whether artifacts move toward capped strings, CID/hash-only fields, stricter bytes32 commitment standards, resolver validation, or explicit canonicalization profiles. Those choices need verifier and indexer policy first.
