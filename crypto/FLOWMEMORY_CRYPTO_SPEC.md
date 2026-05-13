# FlowMemory Crypto Spec v0

Status: draft v0.

## Core Question

A FlowMemory fact is a typed claim that can be identified, committed, checked, and reported without placing raw data on-chain.

Facts can be:

- observed chain facts, such as a FlowPulse log after its transaction receipt exists
- committed off-chain facts, such as an artifact root or storage receipt commitment
- signed claims, such as worker signatures and verifier attestations
- deterministic verification reports
- future proofs over receipts, roots, or reports

An unverified fact is only a claim. Verification status must remain explicit.

## Source Inputs

FlowMemory v0 starts from the contracts foundation:

- `FlowPulse` emits `pulseId`, `rootfieldId`, `actor`, `pulseType`, `subject`, `commitment`, `parentPulseId`, `sequence`, `occurredAt`, and `uri`.
- `pulseId` is contract-computed and domain-separated by `flowmemory.flowpulse.v0`, chain id, emitting contract, rootfield id, actor, pulse type, subject, commitment, parent pulse, and sequence.
- `txHash`, `transactionIndex`, `logIndex`, and `blockHash` are not known to the contract. Indexers derive them after reading receipts and logs.
- `uri` is advisory log data. It is not proof of storage and is not an enforced off-chain-data boundary.

## Identifier Model

FlowMemory uses three different identifiers:

- `pulseId`: logical contract pulse id, available inside emitted FlowPulse args.
- `observationId`: canonical identifier for one observed log position after receipt metadata exists.
- `reportId`: deterministic identifier for a verifier report over a receipt and check set.

Do not use `pulseId` as the sole database primary key for canonical chain observation. A reorg or replayed transaction can produce the same semantic pulse in a different block context. Use `observationId` for observed logs and link it back to `pulseId`.

## Hash Primitive

Protocol commitments use Keccak-256 because Base/EVM contracts can verify it natively.

Top-level objects use:

```text
keccak256(abi.encode(TYPEHASH, field_1, field_2, ...))
```

Rules:

- `TYPEHASH = keccak256(bytes(type_string))`.
- Field order is normative.
- Strings, JSON, byte arrays, URIs, reports, and manifests are hashed before entering typed objects.
- Use `abi.encode`, not `abi.encodePacked`, for typed object hashes.
- Merkle leaf and node hashes use the typed object hashes defined in `MERKLE_AND_ROOTS.md`.
- Unknown or not-applicable `bytes32` fields use zero bytes.

## Canonical Encoding Strategy

On-chain compatible typed objects:

- Use Solidity ABI static encoding.
- Use `address` as the 20-byte EVM address left-padded in ABI words.
- Use `uint64` for block numbers, sequences, and Unix seconds or milliseconds where specified.
- Use `uint16` for schema versions when included in typed hashes.

Off-chain documents:

- JSON inputs use canonical JSON with recursively sorted object keys.
- Array order is preserved and is meaningful.
- Strings matching `0x[0-9a-fA-F]*` are normalized to lowercase before hashing.
- Avoid ambiguous JSON number semantics in v0. Prefer strings for large integers if a JSON field is not also encoded in a typed hash.
- URI hashes use exact UTF-8 bytes. Do not normalize, lowercase, resolve, or fetch a URI before hashing it.

## Domain Separation

Every accepted format must bind its domain through at least one of:

- schema id
- type hash
- chain id
- emitting contract
- deployment id
- verifier set root
- worker or verifier key id
- root scheme id
- report schema hash

No signature should be accepted if its domain does not match the chain, deployment, verifier set, key registry, and expiry policy being evaluated.

Implemented domain separator names:

```text
flowPulseObservationId
indexerCursorId
verifierReportDigest
verifierAttestationEnvelope
rootfieldNamespaceId
rootCommitment
artifactCommitment
workReceiptId
workerIdentity
verifierIdentity
merkleLeaf
merkleInternalNode
devnetBlockHash
agentAccountId
modelPassportId
memoryCellId
artifactAvailabilityProofId
verifierModuleId
challengeId
finalityReceiptId
hardwareSignalEnvelopeId
controlPlaneProvenanceResponseId
localSignatureEnvelope
```

## Versioning Strategy

Versioning is by schema name and type string.

- Breaking hash changes create a new type string with a new suffix, such as `FlowPulseObservationV1`.
- Non-breaking documentation changes do not change type hashes.
- Test vectors must declare the schema version that generated them.
- Contracts should not accept unknown schema ids unless a migration or adapter explicitly allows it.
- Verifiers must record which schema version produced each report.

## MVP Split

The current package implements:

- FlowPulse observation identity
- receipt hashing
- artifact root recomputation
- storage receipt commitment hashing
- worker and verifier signature payloads
- local secp256k1 signing and verification helpers for deterministic tests
- deterministic verifier reports
- verifier signature envelopes
- reorg-aware status handling
- FlowChain Local Alpha object identity for agent accounts, model passports, work receipts, artifact availability proofs, verifier modules, verifier reports, memory cells, challenges, finality receipts, hardware signal envelopes, and control-plane provenance responses
- Local Alpha operator, agent, verifier, and hardware signature envelope payloads and validators for replay, wrong domain, missing signer, zero hash, malformed id, malformed dependency, bad parent/root, and wrong object type checks
- test vectors and cross-language conformance tests

The runnable package in `crypto/src/` currently implements the v0 hash utilities and tests them against fixtures in `crypto/fixtures/`.

MVP should remain verifier-attested for:

- off-chain artifact availability
- URI locator policy
- storage provider claims
- model or worker behavior
- final status labels before proof systems exist
- local operator-vault policy; current fixture keys are deterministic no-value test keys and do not represent wallet custody, production account control, or transferable value

## Future Split

Future zk/proof-carrying work may prove:

- artifact chunk inclusion in a committed root
- receipt consistency with event args and observation id
- verifier report consistency with deterministic checks
- recursive aggregation of many reports into a checkpoint
- selective disclosure for private artifact metadata

Future work must still treat chain finality, data availability, key governance, and privacy policy as separate assumptions unless those systems are explicitly implemented.

## GitHub Context Used

This spec aligns with:

- PR #1, bootstrap repository scaffolding.
- PR #2, FlowPulse and Rootfield contracts foundation.
- Issue #5, minimal indexer/verifier MVP loop.
- Issue #13, canonical FlowPulse observation identity.
- Issue #14, verifier result status vocabulary.
- Issue #17, v0 receipt, attestation, and commitment schema vocabulary.
- Issue #26, deferring CursorRegistry until observation identity stabilizes.

Searches for `Claw` and `claw` in repository issues and code returned no matching GitHub artifacts during this pass.

## Follow-Up Issues

- Define and accept FlowPulse observation identity with indexer and verifier agents.
- Wire verifier services to validate `crypto/fixtures/vectors.json`.
- Add Solidity shared hash library under `contracts/shared/` after schema review, if on-chain adapters need it.
- Add deterministic verifier report fixtures under `services/verifier/` that consume the package outputs.
- Decide Rootfield URI policy: advisory URI fields, length caps, CID-only, or hash-only.
- Define key registry and verifier set root governance.
- Define challenge evidence and response envelopes.
- Produce a decision record before CursorRegistry or proof-carrying receipts are implemented.
- Decide when, if ever, the nearby Noesis/FlowChain RD crypto crates should receive a Keccak compatibility adapter for these V0 object IDs.
