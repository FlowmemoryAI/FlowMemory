# FlowMemory Local Alpha Object Identity

Status: local/test V0.

This document defines the canonical cryptographic IDs for the FlowMemory Local
Alpha object model. These IDs are the crypto package boundary that localRuntime,
control-plane, API, verifier, and dashboard agents should consume. Do not invent
alternate hash formats for these objects.

## RD Crypto Boundary

The user noted that the RD library is for cryptography. I inspected this
workspace and nearby `FLOWMEMORY_WORKTREE_ROOT` research paths.

No RD-named cryptography library exists inside this worktree. The current
authoritative FlowMemory crypto package is:

```text
FLOWMEMORY_WORKTREE_ROOT\flowmemory-crypto\crypto
```

Private research/RD crypto sources may inform vocabulary and future proof interfaces, but they are not committed to the public repository and are not consumed directly by this package. FlowMemory Local Alpha IDs use the existing FlowMemory rule:

```text
keccak256(abi.encode(TYPEHASH, field_1, field_2, ...))
TYPEHASH = keccak256(bytes(type_string))
```

FlowMemory should consume the nearby RD libraries as research inputs only until a
separate compatibility issue accepts a cross-language adapter and vectors that
match the Keccak typed hashes in this package.

## Object IDs

All object IDs are bytes32 Keccak typed hashes. Variable-length names, policy
documents, manifests, source code, response bodies, and dependency sets must be
pre-hashed before entering the typed object.

| Object | ID field | Type string key | Domain string key | Helper |
| --- | --- | --- | --- | --- |
| AgentAccount | `agentId` | `agentAccountV0` | `agentAccountId` | `agentAccountId` |
| ModelPassport | `modelId` | `modelPassportV0` | `modelPassportId` | `modelPassportId` |
| WorkReceipt | `workReceiptId` | `workReceiptV0` | `workReceiptId` | `workReceiptId` |
| ArtifactAvailabilityProof | `proofId` | `artifactAvailabilityProofV0` | `artifactAvailabilityProofId` | `artifactAvailabilityProofId` |
| VerifierModule | `moduleId` | `verifierModuleV0` | `verifierModuleId` | `verifierModuleId` |
| VerifierReport | `reportId` | `verifierReportV0` | `verifierReportDigest` | `verifierReportHash` |
| MemoryCell | `memoryCellId` | `memoryCellV0` | `memoryCellId` | `memoryCellId` |
| Challenge | `challengeId` | `challengeV0` | `challengeId` | `challengeId` |
| FinalityReceipt | `finalityReceiptId` | `finalityReceiptV0` | `finalityReceiptId` | `finalityReceiptId` |
| BridgeDeposit | `depositId` | `bridgeDepositV0` | `bridgeDepositId` | `bridgeDepositId` |
| BridgeCredit | `creditId` | `bridgeCreditV0` | `bridgeCreditId` | `bridgeCreditId` |
| BridgeWithdrawal | `withdrawalId` | `bridgeWithdrawalV0` | `bridgeWithdrawalId` | `bridgeWithdrawalId` |
| Local balance record | `balanceRecordId` | `localBalanceRecordV0` | `localBalanceRecordId` | `localBalanceRecordId` |
| HardwareSignalEnvelope | `hardwareSignalEnvelopeId` | `hardwareSignalEnvelopeV0` | `hardwareSignalEnvelopeId` | `hardwareSignalEnvelopeId` |
| Control-plane provenance response | `provenanceResponseId` | `controlPlaneProvenanceResponseV0` | `controlPlaneProvenanceResponseId` | `controlPlaneProvenanceResponseId` |

`WorkReceipt` and `VerifierReport` intentionally reuse the existing
FlowMemory V0 domains, `flowmemory.v0.work.receipt-id` and
`flowmemory.v0.verifier.report-digest`. The other Local Alpha object domains
use `flowmemory.local-alpha.v0.*`. This keeps the local testnet vocabulary
compatible with the existing receipt/report package instead of creating a
second receipt/report identity system.

`LocalSignatureEnvelope` uses `localSignatureEnvelopeV0` and
`localSignatureEnvelopeHash`. It signs the object ID, object schema hash,
domain separator, signer ID, signer key ID, signer role, sequence, validity
window, and nonce. The signing digest is the local EIP-712 style digest over
that struct hash and the object domain separator.

`LocalTransactionEnvelope` uses `localTransactionEnvelopeV0` and
`localTransactionEnvelopeHash`. It signs the local chain id, transaction domain
separator, signer ID, signer key ID, signer role, transaction nonce, canonical
JSON payload hash, object ID, object type hash, and issue time. The transaction
domain is chain-bound as
`flowmemory.local-alpha.v0.local-transaction-envelope:chain:<chainId>`.

Runnable definitions live in `crypto/src/objects.js`.

Canonical object fixtures live in:

```text
crypto/fixtures/local-alpha-objects.json
```

Package-level vectors are pinned in:

```text
crypto/fixtures/vectors.json
```

The Local Alpha JSON Schemas live in:

```text
schemas/flowmemory/agent-account.schema.json
schemas/flowmemory/model-passport.schema.json
schemas/flowmemory/work-receipt.schema.json
schemas/flowmemory/memory-cell.schema.json
schemas/flowmemory/artifact-availability-proof.schema.json
schemas/flowmemory/verifier-module.schema.json
schemas/flowmemory/verifier-report.schema.json
schemas/flowmemory/challenge.schema.json
schemas/flowmemory/finality-receipt.schema.json
schemas/flowmemory/bridge-deposit.schema.json
schemas/flowmemory/bridge-credit.schema.json
schemas/flowmemory/bridge-withdrawal.schema.json
schemas/flowmemory/local-balance-record.schema.json
schemas/flowmemory/hardware-signal-envelope.schema.json
schemas/flowmemory/local-signature-envelope.schema.json
schemas/flowmemory/local-transaction-envelope.schema.json
schemas/flowmemory/control-plane-provenance-response.schema.json
```

## Local Signature Envelope Rules

Local Alpha accepts four signer roles:

| Role | Intended signer | Boundary |
| --- | --- | --- |
| `operator` | local operator process or operator-vault adapter | No value-bearing wallet claim. The fixture keys are deterministic no-value test keys. |
| `agent` | registered `AgentAccount` local key | Signs local work receipts, memory cells, challenges, or agent-scoped provenance. |
| `verifier` | local verifier module/report signer | Signs verifier modules, verifier reports, and finality receipts as testnet statements, not trustless proofs. |
| `hardware` | FlowRouter or simulator device key | Signs low-bandwidth control envelopes only. Heavy payloads remain off-chain. |

## Local Test Wallet Boundary

`crypto/src/wallet.js` implements an encrypted local test vault for private/local
smoke runs. It supports create, unlock, public account listing, public metadata
export, transaction signing, verification, account addition, and key rotation.
The vault encrypts private keys with scrypt plus AES-256-GCM. Public metadata
exports intentionally omit private keys, mnemonics, seed material, and
ciphertext. This is a local test utility, not production custody or audited key
management.

Envelope validation requires:

- `objectSchema`, `objectType`, and `objectTypeHash` match the document schema.
- `objectId` matches the recomputed document ID.
- `domain` and `domainSeparator` match the canonical object domain.
- `signerId`, `signerKeyId`, `publicKey`, and `signature` are present.
- signer role is allowed for the object type.
- `envelopeId` and `signingDigest` recompute from the envelope fields.
- the secp256k1 signature verifies against the signing digest and public key.
- the caller supplies replay context and rejects repeated signer/domain/sequence tuples.
- critical object hashes are nonzero, dependency roots are well-formed, parent/root relationships are coherent, and the object type is not swapped.

The fixture validator covers invalid vectors for replay, wrong chain id, wrong
domain, wrong signer, missing signer, bad signature, zero hash, malformed ID,
malformed dependency, malformed bridge deposit, bad parent/root, and wrong
object type. Every Local Alpha object envelope also has a valid fixture and a
bad-signature invalid fixture.

## Consumer Rules

Chain/localRuntime:

- Use these IDs as local transaction/object keys.
- Reject malformed IDs, zero critical roots, bad parent/root transitions,
  wrong object types, and replayed signer/domain/sequence tuples before state
  mutation.
- Do not treat signatures as production wallet custody or value-bearing
  authorization.

Services/control plane:

- Import the crypto package or reproduce the type strings and vectors exactly.
- Run `validateLocalAlphaEnvelope` before accepting local object documents from
  transactions, APIs, fixtures, or hardware packets.
- Store validation errors explicitly instead of silently coercing objects.

Dashboard/workbench:

- Display object IDs, domains, signer role, status label, and validation errors.
- Show verifier reports and finality receipts as local/test statements unless a
  later proof/enforcement path is accepted.

Hardware:

- Use `HardwareSignalEnvelope` for compact control signals only.
- Treat LoRa and Meshtastic fields as low-bandwidth control provenance, not as
  artifact transport or internet replacement.
- Keep raw hardware payloads off-chain and bind them through `signalRoot`.

## What V0 Proves

V0 proves deterministic identity and tamper-evident binding for the typed fields
included in each object ID. If any included field changes, the ID changes.

V0 also proves:

- field-order compatibility with the FlowMemory Keccak ABI typed-hash rule;
- domain/type-string separation for each object class;
- malformed hex rejection for bytes32/address fields;
- canonical JSON stability for pre-hashed control-plane response bodies;
- chain-bound transaction envelope signatures over payload hashes and nonces;
- duplicate ID detection in fixture validation;
- explicit finality and challenge state labels for local/test consumers.

## What V0 Does Not Prove

V0 does not prove that an AI model output is correct, that a verifier is honest,
that storage remains available forever, that hidden dependencies are complete,
or that a challenge outcome is economically secure.

V0 does not implement production proof circuits, GPU proofs, verifier
economics, encrypted compute, production consensus, or a public network. The object
IDs are stable commitments and provenance handles, not a trustless proof system.

## Explicit RD Gates

These tracks are gated and must not be treated as implemented by this package:

- Process-Witness: research input only until public inputs, witness format,
  replay policy, privacy boundaries, and cross-language vectors are accepted.
- SEAL/dependency privacy: attach through `dependencyRoot` and challenge roots
  only until dependency atom schemas, disclosure policy, and verifier checks are
  accepted.
- Synthetic Non-Amplification: no claims until there is a formal rule, fixture
  corpus, verifier module, and dashboard/status vocabulary.
- Advanced encrypted compute: no runtime or security claim until threat model,
  key lifecycle, leakage policy, and deterministic verifier boundary exist.
- GPU proofs: no proof claim until proof system, public inputs, cost model,
  verifier module, and reproducible local vectors exist.
- Audited production proof systems: no audit or production-readiness claim until
  a named audit artifact, issue/decision record, and enforcement path are merged.

## Dependency And SEAL Mapping

The Local Alpha object model leaves a forward-compatible slot for future SEAL or
dependency-atom work:

- `MemoryCell.dependencyRoot` commits to the dependency atoms or dependency
  certificate set that a memory update relies on.
- `ControlPlaneProvenanceResponse.dependencyRoot` lets an API response cite the
  same dependency state without embedding private dependency atoms.
- `Challenge.challengeType = dependency_omission` gives omitted-dependency
  challenges a canonical local/test object ID.
- `VerifierModule.supportedChallengeTypesRoot` and `supportedModesRoot` can
  commit to future verifier support for SEAL, dependency separation, or
  completeness checks.
- `FinalityReceipt.challengeRoot` keeps finality downgradeable if a later
  dependency challenge succeeds.

Future SEAL objects should hash their own public inputs into roots and attach
through these fields. They should not mutate the V0 object ID type strings.

## Future Proof-Carrying Receipts

Proof-carrying receipts can be added without breaking V0 IDs by treating proofs
as new linked objects rather than new bytes inside existing ID preimages.

The stable path is:

1. Keep V0 IDs unchanged.
2. Define a new proof object with its own schema, type string, public inputs,
   proof system id, verifier module id, and proof artifact commitment.
3. Link that proof object to `receiptId`, `reportId`, `challengeId`,
   `finalityReceiptId`, or `dependencyRoot`.
4. If a breaking receipt hash is needed later, create a V1 type string instead
   of changing V0.

This lets Local Alpha dashboards and APIs rely on V0 IDs while future proof
systems attach stronger evidence as additional commitments.
