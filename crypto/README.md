# FlowMemory Cryptography

Status: draft v0.

This directory defines the cryptographic vocabulary, runnable utilities, fixtures, and tests that contracts, indexers, verifiers, workers, and future appchain research should share. The package is intentionally commitment-first and verifier-friendly. It does not claim that FlowMemory is fully trustless before proof systems, verifier enforcement, and challenge handling exist.

## Package Commands

Install dependencies from this directory:

```powershell
cd E:\FlowMemory\flowmemory-crypto\crypto
npm install
```

Requires Node.js `>=20.19.0`.

Run deterministic tests:

```powershell
npm test
```

Print the sample hash outputs:

```powershell
npm run vectors
```

Validate all package-level vector fixtures:

```powershell
npm run validate:vectors
```

Validate the Local Alpha object and signature-envelope fixtures against the
canonical JSON Schemas:

```powershell
npm run validate:local-alpha
```

## Read Order

1. `FLOWMEMORY_CRYPTO_SPEC.md`
2. `OBSERVATION_IDENTITY.md`
3. `RECEIPT_HASHING.md`
4. `MERKLE_AND_ROOTS.md`
5. `ATTESTATIONS.md`
6. `FLOWCHAIN_LOCAL_ALPHA_OBJECTS.md`
7. `TEST_VECTORS.md`

Runnable fixtures live in `fixtures/`. `fixtures/vectors.json` contains the current 33 package-level vectors. `fixtures/local-alpha-objects.json` contains positive and negative Local Alpha object and signed-envelope fixtures. Supporting cross-language vectors live in `test-vectors/`.

Validate the current vector set with:

```powershell
python validate_test_vectors.py
```

The Python validator is a cross-check for the FlowPulse aggregate vector. The primary local/test package paths are `npm test`, `npm run validate:vectors`, and `npm run validate:local-alpha`.

## Core Vocabulary

- `pulseId`: contract-emitted logical FlowPulse identifier. It is produced during contract execution and intentionally excludes receipt-only metadata.
- `observationId`: indexer/verifier identifier for a specific observed FlowPulse log after receipt metadata exists.
- `receiptHash`: commitment to a FlowPulse observation, event args, artifact root, storage commitment, and evidence root.
- `artifactRoot`: commitment to off-chain artifact bytes and metadata.
- `reportId`: deterministic identifier for a verifier report.
- `attestation`: signed worker or verifier envelope over a receipt, report, artifact, or root.
- Local Alpha object IDs: canonical IDs for `AgentAccount`, `ModelPassport`, `WorkReceipt`, `ArtifactAvailabilityProof`, `VerifierModule`, `VerifierReport`, `MemoryCell`, `Challenge`, `FinalityReceipt`, hardware signal envelopes, and control-plane provenance responses.
- Local Alpha signature envelopes: local operator, agent, verifier, and hardware secp256k1 test signatures over typed object IDs. These are no-value local/test keys and are not wallet custody or production key-management claims.

## Implemented Helpers

The package exports Keccak helpers, canonical JSON hashing, typed hash utilities, FlowPulse observation ids, cursor ids, report digests, receipt hashes, artifact/root commitments, work receipt ids, Local Alpha object ids, hardware signal envelope ids, Local Alpha signature envelope payloads, envelope validators, Merkle roots, worker/verifier signature payloads, verifier attestation envelope hashes, and local secp256k1 sign/verify helpers for tests.

The implementation is ESM JavaScript with `src/index.d.ts` declarations for TypeScript consumers.

## MVP Boundary

MVP crypto can provide tamper-evident facts, deterministic IDs, replay-resistant signatures, artifact inclusion checks, and verifier reports. MVP crypto cannot prove data availability forever, prove model output correctness, or make verifier attestations trustless.

## Future Boundary

Future work may add proof-carrying receipts, zk circuits for receipt consistency, recursive report aggregation, and appchain/L1 verification tracks. Those remain research until public inputs, witnesses, circuits, and enforcement paths are specified.

## Integration Notes

There is a fixture-first `services/shared/` package in this repository, but the crypto package remains the authoritative source for the hash formats in this directory. Services should either:

- import this package directly from `crypto/` in local development, or
- mirror the exported functions from `crypto/src/index.js` with tests against `crypto/fixtures/`.

Indexer and verifier services must not hand-roll different hash formats. If a service cannot import this package, it should copy the type strings and vectors exactly and prove compatibility by passing the same fixture hashes.

Nearby Noesis/FlowChain RD crates under `E:\FlowMemory\github-research-sources\noesis-l1\crates\` are research inputs only for this package. They should not replace these Keccak typed-hash vectors unless a compatibility adapter and matching cross-language vectors are accepted.

## Downstream Consumption

- Chain/devnet agents should use the object ID helpers as transaction/object keys and reject zero roots, malformed IDs, wrong object types, replayed signer sequences, and bad parent/root relationships before state updates.
- Services and verifiers should use `validateLocalAlphaEnvelope` before accepting object documents from local transactions, API calls, hardware packets, or fixture imports.
- Dashboard/workbench agents should display IDs, domains, signer roles, status labels, and validation errors from these fixtures without implying production proof security.
- Hardware agents should treat hardware signal envelopes as low-bandwidth authenticated control messages only; payloads remain off-chain and signal roots are commitments, not radio bandwidth or field-deployment claims.
