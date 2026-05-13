# FlowChain Private State Roadmap

Last updated: 2026-05-13

Status: research roadmap. This document does not implement private state, encrypted compute, wallet code, vault code, proof systems, contracts, or production APIs.

## Purpose

FlowChain Local Alpha needs private-state discipline before it needs advanced encrypted compute. The correct sequence is:

1. Local secret vault first.
2. Private artifact references second.
3. SEAL/dependency privacy third.
4. Encrypted compute later only after review.

## Status Vocabulary

- **Implemented**: merged into FlowMemory as of `docs/CURRENT_STATE.md` dated 2026-05-13 or confirmed from `origin/main` on 2026-05-13.
- **Local-alpha target**: appropriate to specify and later build for Local Alpha.
- **Later research**: blocked behind cryptography, product, and security review.
- **Blocked**: cannot move to implementation until named prerequisites are met.
- **No-go**: condition that blocks implementation or stronger claims.

## Current Private-State Baseline

| Area | Status | Current fact |
| --- | --- | --- |
| Public commitments | Implemented foundation | Current contracts and fixtures store or emit compact roots, commitments, receipts, reports, and advisory URI strings. |
| Secret storage | Local-alpha target | No production local vault exists in the current state summary; a local vault remains a future Local Alpha implementation target. |
| Private artifact references | Local-alpha target | Current `metadataURI` and `evidenceURI` style values are arbitrary caller-supplied log strings and do not enforce privacy, length, format, or resolver behavior. |
| Dependency privacy | Later research | SEAL/dependency privacy is research only. |
| Encrypted compute | Later research | No production encrypted compute exists and none is approved for Local Alpha. |

## Roadmap Summary

| Phase | Status | Goal | Explicit boundary |
| --- | --- | --- | --- |
| 1. Local secret vault | Local-alpha target | Protect local operator, agent, wallet, API, hardware, and private workspace secrets. | Not on-chain, not a production wallet, not MPC, not threshold crypto. |
| 2. Private artifact references | Local-alpha target | Separate public receipt metadata from encrypted local/private locators and artifact reference envelopes. | Not private compute and not a data availability guarantee. |
| 3. SEAL/dependency privacy | Later research, Local-alpha target for vocabulary | Hide sensitive dependency details while preserving challengeable dependency roots and completeness claims. | No ZK dependence claims until proof rules and challenge windows are reviewed. |
| 4. Encrypted compute | Later research | Explore encrypted execution, coprocessors, FHE/MPC/TEE, or private inference only after object model and threat model stabilize. | Not part of Local Alpha. |

## Gate Relationship

| Gate | Status | Private-state requirement |
| --- | --- | --- |
| Local/private testnet | Local-alpha target | Local vault and private artifact reference boundaries may move to implementation after schemas, tests, no-plaintext-log checks, and recovery behavior are accepted. Dependency privacy remains verifier-attested vocabulary only. |
| Public devnet | Later research, Blocked | Public operator key policy, release signing, disclosure logs, omission-challenge handling, and privacy threat model must be reviewed before any public network. |
| Public L1/mainnet | Explicitly later, Blocked | Production custody, encrypted compute, private evidence, and dependency privacy require independent security/crypto review, incident response policy, and explicit accepted decisions. |

## Phase 1: Local Secret Vault First

### Scope

**Local-alpha target**: The vault is a local boundary for secrets needed by operators and agents.

Candidate secret classes:

- Local agent signing keys.
- Local wallet keys for test/dev workflows.
- API keys or RPC credentials.
- Hardware sidecar/channel keys.
- Private artifact locator decryption keys.
- Local workbench session secrets.
- Recovery/export passphrases.

### Requirements

| Requirement | Status | Acceptance condition |
| --- | --- | --- |
| Encrypted at rest | Local-alpha target | Secrets are encrypted in a local file or platform keystore-backed envelope using reviewed libraries. |
| Unlock/lock lifecycle | Local-alpha target | Workbench and API can distinguish locked, unlocked, expired, and unavailable vault states. |
| Import/export | Local-alpha target | Export is explicit, encrypted, and never part of normal logs or fixtures. |
| Rotation | Local-alpha target | Keys can be rotated or retired with downstream receipts showing superseded status where needed. |
| Corrupt-file recovery | Local-alpha target | Failure states are clear and do not silently create new identities. |
| No plaintext logs | Local-alpha target | Tests check that secrets do not appear in normal logs, fixtures, generated JSON, or public receipt data. |
| Local-only default | Local-alpha target | Vault material never syncs or publishes unless a separate explicit export action is performed. |

### No-Go Conditions

- **No-go**: Secrets appear in `metadataURI`, `evidenceURI`, receipts, fixtures, dashboard data, workbench logs, devnet state, or chain events.
- **No-go**: Vault unlock state is ambiguous to the API or workbench.
- **No-go**: A lost or corrupt vault causes silent identity replacement.
- **No-go**: Custom cryptography is introduced where a reviewed existing library or platform keystore should be used.

## Phase 2: Private Artifact References Second

### Scope

**Local-alpha target**: Private artifact references keep public receipts useful without leaking sensitive locations, identifiers, or evidence.

Public receipt metadata should contain:

- Receipt id/hash.
- Artifact root or manifest hash.
- Storage or locator commitment.
- Evidence commitment.
- Privacy class.
- Availability status.
- Challenge/finality status.

Private reference material may contain:

- Encrypted locator.
- Access token reference.
- Private storage provider path.
- Decryption key reference.
- Retention policy detail.
- Private manifest fields.
- Local operator notes.

### Requirements

| Requirement | Status | Acceptance condition |
| --- | --- | --- |
| Public/private split | Local-alpha target | Public views show commitments and status, not raw locators or secrets. |
| Encrypted locator envelope | Local-alpha target | Private locators are encrypted under vault-managed keys or an explicitly reviewed envelope. |
| Resolver policy | Local-alpha target | API says whether a reference is local-only, shared-with-verifier, shared-with-agent, or public. |
| Availability checks | Local-alpha target | Missing, changed, expired, duplicated, or inaccessible artifacts produce deterministic status. |
| Challenge opening | Local-alpha target | Opening a private reference for a challenge is explicit and logged as a disclosure event. |
| Export controls | Local-alpha target | Release bundles and fixtures exclude private locator material by default. |

### No-Go Conditions

- **No-go**: Raw artifact bytes, model outputs, media, secrets, or private locators are placed on-chain.
- **No-go**: URI strings are treated as private or safe by default.
- **No-go**: A verifier report claims availability without evidence or defined access policy.
- **No-go**: Private references are required to reconstruct public state roots.

## Phase 3: SEAL And Dependency Privacy Third

### Scope

**Later research**: SEAL-style dependency privacy aims to prove or attest dependency relationships without exposing all sensitive provenance.

**Local-alpha target for vocabulary**: Before proofs, Local Alpha can model dependency roots, declared dependence classes, completeness attestations, and omitted-dependency challenges.

### Local Alpha Vocabulary

| Concept | Status | Private-state role |
| --- | --- | --- |
| Dependency atom | Local-alpha target | Typed dependency that may be public, private, salted, or committed. |
| Dependency root | Local-alpha target | Commitment to dependency atoms or hidden dependency commitments. |
| Completeness attestation | Local-alpha target | Issuer/verifier claim that a dependency set is complete for a declared scope. |
| Omitted-dependency challenge | Local-alpha target | Mechanism to reveal or prove a missing dependency and downgrade affected finality. |
| Causal separation proof | Later research | ZK proof that dependency footprints satisfy an admissible class. |
| MergeCapability | Later research | Proof-carrying permission to merge evidence under a dependence class. |

### Requirements Before ZK Dependency Proofs

- **Later research**: Exact dependency schema.
- **Later research**: Completeness warranty model.
- **Later research**: Omitted-dependency challenge state machine.
- **Later research**: Public inputs and witness privacy rules.
- **Later research**: Revocation and downgrade semantics.
- **Later research**: Independent cryptography review.
- **Later research**: Cost model versus deterministic verifier replay.

### No-Go Conditions

- **No-go**: Claiming independence without declared dependency scope.
- **No-go**: Hiding dependency omissions behind zero knowledge.
- **No-go**: Finality that cannot be downgraded after a valid omitted-dependency challenge.
- **No-go**: Treating private dependency proofs as implemented before proof rules and circuits exist.

## Phase 4: Encrypted Compute Later Only After Review

### Scope

**Later research**: Encrypted compute includes FHE, MPC, TEE-backed private execution, encrypted coprocessor models, encrypted mempools, private inference, or generalized private smart contract execution.

### Why It Is Later

Encrypted compute has difficult dependencies:

- Stable object model.
- Stable local API and private reference model.
- Clear threat model.
- Key custody design.
- Side-channel and leakage analysis.
- Data availability and auditability rules.
- Proof or attestation semantics.
- Incident response and downgrade paths.
- Independent security review.

### No-Go Conditions

- **No-go**: Encrypted compute is used to compensate for unclear public/private data modeling.
- **No-go**: A TEE, MPC, FHE, or coprocessor claim is made without specifying trust assumptions and leakage.
- **No-go**: Private computation output becomes final without verifier, challenge, or disclosure policy.
- **No-go**: Production encrypted compute is bundled with Local Alpha.

## Public And Private State Boundary

| Data | Status | Public receipt/root? | Private vault/reference? |
| --- | --- | --- | --- |
| Receipt hash | Implemented foundation | Yes | No secret. |
| Observation identity | Implemented foundation | Yes, after receipt/log observation. | No secret. |
| Artifact root | Implemented foundation | Yes | No secret if root is salted or high entropy where needed. |
| Raw artifact bytes | Implemented boundary | No | Local/private storage only. |
| Artifact locator | Local-alpha target | Commitment or encrypted envelope only. | Yes. |
| API/RPC credential | Local-alpha target | No | Yes. |
| Agent signing key | Local-alpha target | Public key may be public; private key never public. | Yes. |
| Hardware channel key | Local-alpha target | No | Yes. |
| Dependency root | Local-alpha target | Yes | Openings may be private. |
| Dependency atoms | Local-alpha target, Later research | Public only if safe; otherwise committed/salted/encrypted. | Yes where sensitive. |
| Verifier report | Implemented foundation | Public report/digest/status can be public. | Private evidence openings may be vault-gated. |
| Synthetic evidence | Local-alpha target | Status and commitments may be public. | Raw generated datasets may be private/off-chain. |

## Workbench And API Responsibilities

**Local-alpha target**: The workbench and API should make privacy state explicit.

Required labels:

- public
- local-only
- private-reference
- shared-with-verifier
- shared-with-agent
- challenge-disclosed
- redacted
- unavailable
- expired
- superseded

Required behaviors:

- Public views must not require vault unlock.
- Private reference views must require vault unlock.
- Disclosure for a challenge must create an auditable local event.
- Exported fixtures must exclude private fields unless explicitly requested into an encrypted export.
- Explorer must distinguish commitment, locator, artifact, proof, and verifier claim.

## Recommended Implementation Order For A Future Build

1. **Local-alpha target**: Define vault file/envelope format and tests.
2. **Local-alpha target**: Define API locked/unlocked error semantics.
3. **Local-alpha target**: Add no-plaintext-secrets fixture/log tests.
4. **Local-alpha target**: Define private artifact reference envelope.
5. **Local-alpha target**: Add availability and challenge disclosure states.
6. **Local-alpha target**: Define dependency root and dependency atom vocabulary.
7. **Later research**: Add completeness attestations and omitted-dependency challenge fixtures.
8. **Later research**: Evaluate SEAL-style ZK dependency proofs.
9. **Later research**: Evaluate encrypted compute only after independent review.

## Bottom Line

**Local-alpha target**: FlowChain private state starts as local secret management plus private artifact references.

**Later research**: Hidden dependency proofs and encrypted compute can matter later, but only after the basic public/private data model, challenge model, and verifier/release machinery are clear.
