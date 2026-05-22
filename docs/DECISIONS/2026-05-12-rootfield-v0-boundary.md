# Rootfield v0 Boundary

Date: 2026-05-12

## Status

Accepted

## Context

The first contracts foundation introduces `RootfieldRegistry` as a minimal namespace and root-commitment skeleton. It needs a clear boundary before later agents add indexers, verifiers, hooks, fees, or governance mechanics.

Rootfield v0 is deliberately small. It records ownership, schema and metadata hashes, the latest committed root, basic counters, and FlowPulse emissions. This decision defines what those fields mean in v0 and what they do not yet guarantee.

## Decision

Rootfield v0 is a commitment registry boundary, not a data-storage layer. Contract state should remain compact and should represent intentional commitments, not raw AI memory, model artifacts, media, or large evidence payloads.

### URI Policy

`metadataURI` and `evidenceURI` are advisory strings. The v0 contract accepts them as caller-supplied event data and does not enforce length, content, format, resolvability, allowed schemes, or "short pointer" behavior. Emitted URI bytes are still on-chain log data.

Callers are responsible for keeping heavy or sensitive raw data out of URI fields. Verifiers and indexers may use URI values as hints, but they must not treat them as trusted facts without checking the relevant commitments.

Future versions should decide whether URI handling remains advisory or moves to one of these stricter options:

- Capped strings, if human-readable pointers remain useful
- `bytes32` commitments, if contract-level compactness is more important
- CID/hash-only fields, if artifact addressing needs deterministic validation
- A validation policy, if accepted schemes, lengths, or formats must be enforceable

These alternatives are deliberately deferred in v0. Capped strings still leave content and resolver semantics ambiguous. `bytes32` commitments are compact but require canonical hashing rules that are not finalized. CID/hash-only fields may be the right artifact boundary, but the project has not yet chosen a storage or retrieval convention. URI validation policy needs clearer verifier and indexer requirements before it belongs in contract logic.

### Commitment Semantics

`schemaHash`, `metadataHash`, `latestRoot`, and `artifactCommitment` are compact commitments to off-chain definitions, metadata, root states, or evidence. They are not the underlying data. A commitment only becomes meaningful when an indexer or verifier can resolve the referenced artifact and check that it matches the emitted or stored hash.

Rootfield v0 does not define the complete hashing standard for every off-chain artifact. Callers and verifiers must agree on artifact canonicalization before treating a commitment as verified protocol truth.

### Status Lifecycle Assumptions

The v0 registry lifecycle is intentionally narrow but now includes the minimum lifecycle controls needed for reviewable local testing:

- A rootfield starts unregistered.
- Registration creates an active rootfield owned by the registering account.
- The owner may submit roots while the rootfield is active.
- Root submission updates `latestRoot`, increments counters, and emits FlowPulse.
- The owner may deactivate the rootfield. Deactivation emits a status-change FlowPulse and prevents later root submissions.
- The owner may transfer ownership of an active rootfield to another nonzero address. Transfer emits a status-change FlowPulse and the new owner becomes the only account that can submit roots or deactivate the rootfield.

V0 does not implement reactivation, pause windows, challenge periods, governance-controlled status transitions, social recovery, multisig recovery, or automated dispute handling. Ownership transfer is a direct owner-only operation, not a recovery system.

### Namespace Squatting Policy

Rootfield v0 is first-come, first-served. The contract does not reserve names, charge namespace fees, check human-readable ownership, enforce allowlists, or prevent someone from registering a desirable rootfield id before another party.

Callers should treat `rootfieldId` values as opaque commitments or collision-resistant identifiers rather than public brand names. Future versions may add reserved namespaces, governance review, attestations, signed claims, challenge windows, or fee-based anti-squatting policy, but none of that exists in v0.

### Ownership And Recovery Policy

Rootfield v0 supports only explicit owner-initiated transfer to a nonzero address. It does not support lost-key recovery, administrator rescue, timelocked transfer acceptance, role-based administration, guardians, or ownership disputes.

This keeps the skeleton easy to audit but means a lost owner key can strand an active rootfield. Any production recovery design should be introduced as a separate reviewed protocol change.

## v0 Intentionally Excludes

- Tokenomics
- Dynamic fees
- Uniswap v4 hooks
- dedicated network or dedicated-network mechanics
- Production deployment logic
- Lost-key recovery
- Governance or upgrade policy
- Reactivation after deactivation
- Pause windows or challenge periods
- Challenge, slashing, dispute, or verifier reward mechanics
- Contract-enforced URI validation
- Full artifact canonicalization rules
- Raw AI memory, model, artifact, media, or evidence storage

## Consequences

This boundary keeps Rootfield v0 reviewable and useful as a first protocol surface. It allows contract tests and CI to stabilize around registration, root commitment, and FlowPulse emission without forcing premature decisions about fees, hooks, governance, verifier economics, or artifact standards.

The tradeoff is that important verification guarantees remain off-chain. Indexers and verifiers must derive receipt metadata, validate commitments, decide how to handle URI hints, and reject heavy or sensitive raw data by policy until the protocol adds stricter contract rules.

## Follow-Ups

- Decide whether Rootfield URI fields should become capped strings, `bytes32` commitments, CID/hash-only fields, or validated strings.
- Define canonical hashing and serialization rules for metadata, root states, and artifact evidence.
- Decide whether namespace squatting needs reserved ids, attestations, governance review, challenge windows, or fees.
- Decide whether ownership transfer should require acceptance, delay, multisig policy, or recovery hooks.
- Define any future rootfield reactivation, pause, challenge, or governance behavior as a separate reviewed change.
