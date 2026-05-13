# FlowMemory Cryptography Implementation Plan

Status: draft v0 for bootstrap design.

This plan turns the draft crypto foundation into reviewable implementation steps. It stays within crypto, shared contracts, and verifier scope. It does not include tokenomics.

## Phase 0: Schema Review

Deliverables:

- Review `crypto/FLOWMEMORY_CRYPTO_SPEC.md`.
- Review `crypto/OBSERVATION_IDENTITY.md`.
- Review `crypto/RECEIPT_HASHING.md`.
- Review `crypto/MERKLE_AND_ROOTS.md`.
- Review `crypto/ATTESTATIONS.md`.
- Open issues for unresolved schema choices.
- Decide whether v0 JSON canonicalization must strictly use RFC 8785 or a narrower project-specific subset.
- Decide the first accepted FlowPulse event schema with the protocol contracts agent.

Acceptance checks:

- Every hash has a type string.
- Every variable-length field is pre-hashed.
- Every replay domain is named.
- The docs clearly state what is not trustless yet.

## Phase 1: Test Vector Harness

Status: runnable package candidate exists in `crypto/` with 21 package-level vectors and a Python FlowPulse aggregate cross-check.

Deliverables:

- Add a small reference implementation under `crypto/` for Keccak typed hashes.
- Validate `crypto/test-vectors/flowpulse-observation-v0.json`.
- Add negative tests for swapped fields, changed type strings, wrong Merkle order, and odd-leaf handling.
- Add equivalent vectors for empty artifact and one-chunk artifact roots.

Acceptance checks:

- Local tests reproduce all vector hashes.
- Bad vectors fail deterministically.
- No production keys, secrets, RPC URLs, or private locators are committed.

## Phase 2: Shared Contract Hash Library

Scope:

- `contracts/shared/`

Deliverables:

- Solidity constants for type hashes.
- Pure functions for event cursor hash, receipt hash, artifact root hash, storage commitment hash, worker struct hash, verifier attestation hash, and challenge hash.
- Merkle proof verification for `FM-MERKLE-KECCAK256-BINARY-V0`.
- Tests comparing Solidity output to the JSON vectors.

Acceptance checks:

- Solidity tests match off-chain vectors.
- Functions use `abi.encode`, not ambiguous packed encoding; Merkle leaf and internal node hashes are typed objects in v0.
- Contracts do not attempt to access `txHash` or `logIndex` during hook execution.

## Phase 3: Verifier Service Reference

Scope:

- `services/verifier/`

Deliverables:

- Parser for receipt, artifact manifest, storage commitment, worker signature, and verifier attestation envelopes.
- Cursor derivation from observed receipt/log data.
- Reorg/finality status handling.
- Worker signature verification with strict domain checks.
- Artifact root recomputation from manifest and chunk openings.
- Deterministic verification report with `checksRoot`.

Acceptance checks:

- Verifier rejects wrong chain, wrong deployment, stale finality, expired signatures, duplicate worker sequence, and bad Merkle openings.
- Verifier labels output as observed, pending, verified, failed, challenged, or superseded.
- Verification reports are deterministic from the same inputs.

## Phase 4: Storage Receipt And Challenge Loop

Deliverables:

- Define storage provider identity envelope.
- Define public versus private locator commitment policy.
- Implement availability sampling reports.
- Implement challenge evidence envelope and response envelope.
- Record failure modes without tokenomics or slashing assumptions.

Acceptance checks:

- Challenges can require manifest openings, chunk openings, signature proof, storage locator opening, and verifier report replay.
- Services can mark claims challenged, responded, upheld, dismissed, or expired.
- Apps and explorers can distinguish storage claim from storage proof.

## Phase 5: Rootflow And Rootfield Binding

Deliverables:

- Draft Rootflow as ordered receipt progression commitment.
- Draft Rootfield as artifact/state/report commitment layer.
- Define how roots are rolled up, checkpointed, and challenged.
- Add a decision record before contracts depend on either root.

Acceptance checks:

- Rootflow and Rootfield have different semantics.
- Indexers can reconstruct roots from receipts and logs.
- Verifiers can recompute roots from committed inputs.

## Phase 6: zk And Proof-Carrying Roadmap

Research tracks:

- Merkle inclusion and non-inclusion proof circuits.
- Receipt consistency circuits for cursor, receipt, artifact root, and storage commitment linkage.
- Verifier-report compression into proof-carrying receipts.
- Recursive aggregation of receipt proofs into Rootflow checkpoints.
- Selective disclosure for private artifact metadata.
- Hardware/device attestation research for FlowRouter identity.

Gate before implementation:

- Define exact public inputs.
- Define witness formats and privacy requirements.
- Decide proving system and trusted setup assumptions.
- Compare proof cost against ordinary deterministic verification.
- Record a go/no-go decision before building production circuits.

## Recommended Issues To Create

These are the smallest useful issues to create from this crypto pass:

- Define the first FlowPulse event schema and payload nonce policy.
- Integrate the typed-hash reference implementation and vector tests into verifier services.
- Add Solidity shared hash library and vector tests.
- Implement verifier receipt parser and cursor derivation.
- Define worker and verifier key registry requirements.
- Define storage provider identity and locator privacy policy.
- Draft Rootflow and Rootfield semantics as a decision record.
- Research zk public inputs for proof-carrying receipts.

Created or reused follow-up GitHub issues:

- #28: future `ReceiptVerifier` contract boundary, with draft local boundary in `contracts/shared/RECEIPT_VERIFIER_BOUNDARY.md`.
- #38: service-side validation for crypto v0 test vectors.
- #40: verifier signature envelope validation.
- #42: zk proof-carrying receipt research milestones.
- #47: services/shared crypto package integration boundary.

Issue #39 was created during this cycle and closed as a duplicate of #28.

## Near-Term Pull Request Shape

The first implementation PR should include only:

- typed hash reference functions
- test vector validation
- no network calls
- no production contracts
- no production verifier service
- no token mechanics

That keeps the first crypto implementation small enough to review and safe enough to change while schemas are still draft.
