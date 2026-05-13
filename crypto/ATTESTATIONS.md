# FlowMemory Attestations And Reports

Status: draft v0.

Attestations are signed envelopes over receipts, artifacts, or reports. They provide accountability. They do not make the system fully trustless.

## Worker Signature Envelope

Type string:

```solidity
FlowMemoryWorkerSignatureV0(bytes32 receiptHash,bytes32 workerId,bytes32 workerKeyId,uint64 workerSequence,uint64 expiresAtUnixMs,bytes32 artifactRoot,bytes32 nonce)
```

Struct hash:

```text
workerStructHash = keccak256(abi.encode(
  WORKER_SIGNATURE_TYPEHASH,
  receiptHash,
  workerId,
  workerKeyId,
  workerSequence,
  expiresAtUnixMs,
  artifactRoot,
  nonce
))
```

Worker signatures bind an off-chain worker to a receipt and optional artifact root. They do not prove the worker's output is correct.

## Verifier Report V0

Verifier reports are deterministic from their inputs. They should not include nondeterministic prose in the `reportId`.

Type string:

```solidity
FlowMemoryVerifierReportV0(bytes32 reportSchemaHash,bytes32 observationId,bytes32 receiptHash,bytes32 verifierId,bytes32 verifierSetRoot,uint8 status,bytes32 checksRoot,uint64 finalizedBlockNumber,bytes32 finalizedBlockHash,uint16 reportVersion)
```

Hash:

```text
reportId = keccak256(abi.encode(
  VERIFIER_REPORT_TYPEHASH,
  reportSchemaHash,
  observationId,
  receiptHash,
  verifierId,
  verifierSetRoot,
  status,
  checksRoot,
  finalizedBlockNumber,
  finalizedBlockHash,
  reportVersion
))
```

`checksRoot` commits to a deterministic checks document or Merkle tree of check results.

## Verifier Signature Envelope

Type string:

```solidity
FlowMemoryVerifierSignatureV0(bytes32 reportId,bytes32 verifierId,bytes32 verifierKeyId,bytes32 verifierSetRoot,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 nonce)
```

Struct hash:

```text
verifierStructHash = keccak256(abi.encode(
  VERIFIER_SIGNATURE_TYPEHASH,
  reportId,
  verifierId,
  verifierKeyId,
  verifierSetRoot,
  issuedAtUnixMs,
  expiresAtUnixMs,
  nonce
))
```

The signature proves a verifier key signed the report id. It does not prove that the report is correct unless users trust the verifier or can independently replay the checks.

## Generic Attestation Envelope

Type string:

```solidity
FlowMemoryAttestationEnvelopeV0(bytes32 subjectHash,uint8 subjectKind,bytes32 attesterId,bytes32 attesterKeyId,bytes32 verifierSetRoot,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 nonce)
```

Hash:

```text
attestationEnvelopeHash = keccak256(abi.encode(
  ATTESTATION_ENVELOPE_TYPEHASH,
  subjectHash,
  subjectKind,
  attesterId,
  attesterKeyId,
  verifierSetRoot,
  issuedAtUnixMs,
  expiresAtUnixMs,
  nonce
))
```

Suggested subject kinds:

```text
1 = receipt
2 = verifier report
3 = artifact root
4 = storage receipt commitment
5 = challenge evidence
```

The package implements this as `attestationEnvelopeHash` and aliases it as `attestationDigest`.

## Local Signature Helpers

The package includes `publicKeyFromPrivateKey`, `signDigest`, and `verifyDigest` for deterministic secp256k1 tests using local generated test keys only. These helpers are not key management, do not load real secrets, and do not assert production verifier identity. Production services must provide their own secure signer, key registry checks, expiry policy, and verifier set validation.

## Signature Mode Comparison

### EIP-712 Typed Signatures

Pros:

- Best fit for EVM wallets, contracts, and typed domain separation.
- Binds chain id, verifying contract or registry, and deployment salt cleanly.
- Human and tooling support is better than raw hashes.

Cons:

- More implementation complexity.
- Needs careful domain management before registries exist.
- Less natural for non-EVM device keys.

### Simple Domain-Separated Keccak Hashes

Pros:

- Simple for services, hardware, and non-EVM agents.
- Easy to reproduce in verifier tests.
- Can be wrapped by many signature systems.

Cons:

- Weaker wallet UX.
- More risk of accidental replay if domain fields are omitted.
- Contracts need explicit recovery logic per key type.

MVP choice:

- Use EIP-712 for EVM/secp256k1 worker and verifier signatures.
- Use simple typed Keccak hashes for object ids, roots, report ids, and future non-EVM key adapters.
- Do not accept ambiguous `personal_sign` messages for protocol-critical attestations.

## Status Vocabulary

```text
0 = reserved
1 = observed
2 = verified
3 = unresolved
4 = unsupported
5 = failed
6 = reorged
7 = superseded
```

Minimum evidence:

- `observed`: receipt/log was read, but finality or evidence checks are incomplete.
- `verified`: observation id, event args, commitments, artifacts, and signatures required by policy passed.
- `unresolved`: data is missing or unavailable, but failure is not proven.
- `unsupported`: schema, pulse type, root scheme, or key type is unknown.
- `failed`: a required check failed.
- `reorged`: the block/log is no longer canonical under the finality policy.
- `superseded`: a newer report replaces this report.

## Replay Protection

Verifier and worker signatures must bind:

- chain id
- deployment id or registry
- key id
- verifier set root where relevant
- sequence or nonce
- expiry
- receipt hash or report id

Off-chain services should reject duplicate `(workerId, workerSequence)` and duplicate verifier nonces unless the policy explicitly treats exact duplicate signatures as idempotent.
