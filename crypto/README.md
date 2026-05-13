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

## Read Order

1. `FLOWMEMORY_CRYPTO_SPEC.md`
2. `OBSERVATION_IDENTITY.md`
3. `RECEIPT_HASHING.md`
4. `MERKLE_AND_ROOTS.md`
5. `ATTESTATIONS.md`
6. `TEST_VECTORS.md`

Runnable fixtures live in `fixtures/`. `fixtures/vectors.json` contains the current 21 package-level vectors. Supporting cross-language vectors live in `test-vectors/`.

Validate the current vector set with:

```powershell
python validate_test_vectors.py
```

The Python validator is a cross-check for the FlowPulse aggregate vector. The production-candidate package paths are `npm test` and `npm run validate:vectors`.

## Core Vocabulary

- `pulseId`: contract-emitted logical FlowPulse identifier. It is produced during contract execution and intentionally excludes receipt-only metadata.
- `observationId`: indexer/verifier identifier for a specific observed FlowPulse log after receipt metadata exists.
- `receiptHash`: commitment to a FlowPulse observation, event args, artifact root, storage commitment, and evidence root.
- `artifactRoot`: commitment to off-chain artifact bytes and metadata.
- `reportId`: deterministic identifier for a verifier report.
- `attestation`: signed worker or verifier envelope over a receipt, report, artifact, or root.

## Implemented Helpers

The package exports Keccak helpers, canonical JSON hashing, typed hash utilities, FlowPulse observation ids, cursor ids, report digests, receipt hashes, artifact/root commitments, work receipt ids, Merkle roots, worker/verifier signature payloads, verifier attestation envelope hashes, and local secp256k1 sign/verify helpers for tests.

The implementation is ESM JavaScript with `src/index.d.ts` declarations for TypeScript consumers.

## MVP Boundary

MVP crypto can provide tamper-evident facts, deterministic IDs, replay-resistant signatures, artifact inclusion checks, and verifier reports. MVP crypto cannot prove data availability forever, prove model output correctness, or make verifier attestations trustless.

## Future Boundary

Future work may add proof-carrying receipts, zk circuits for receipt consistency, recursive report aggregation, and appchain/L1 verification tracks. Those remain research until public inputs, witnesses, circuits, and enforcement paths are specified.

## Integration Notes

There is no `services/shared/` package in this repository yet. Until one exists, services should either:

- import this package directly from `crypto/` in local development, or
- mirror the exported functions from `crypto/src/index.js` with tests against `crypto/fixtures/`.

Indexer and verifier services must not hand-roll different hash formats. If a service cannot import this package, it should copy the type strings and vectors exactly and prove compatibility by passing the same fixture hashes.
