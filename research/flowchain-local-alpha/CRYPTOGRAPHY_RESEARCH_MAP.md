# FlowChain Cryptography Research Map

Last updated: 2026-05-13

Status: research map. This document does not implement cryptography, proof systems, encrypted compute, verifier economics, or production chain code.

## Purpose

FlowChain Local Alpha needs enough cryptography direction to avoid chaos, but not so much ambition that research ideas become premature protocol claims. This map connects Process-Witness, SEAL/dependency proofs, Synthetic Non-Amplification, proof-carrying receipts, and the R&D/crypto library boundary to the current FlowMemory V0 foundation.

## Status Vocabulary

- **Implemented**: merged into FlowMemory as of `docs/CURRENT_STATE.md` dated 2026-05-13 or confirmed from `origin/main` on 2026-05-13.
- **Local-alpha target**: safe to specify for Local Alpha and later build behind fixtures/tests.
- **Later research**: not ready for Local Alpha implementation.
- **Blocked**: cannot move to implementation until named prerequisites are met.
- **No-go**: condition that blocks implementation or stronger claims.

## Current Crypto Baseline

| Area | Status | Current fact |
| --- | --- | --- |
| Keccak typed helpers | Implemented | The `crypto/` package has V0 hash helpers, typed domains, receipt/report/root/artifact/work helpers, attestations, fixtures, and test vectors. |
| Observation identity | Implemented foundation | The system separates contract `pulseId`, indexer-derived observation identity, and verifier report identity in V0 docs and fixtures. |
| Deterministic verifier reports | Implemented foundation | Local verifier reports exist as signed or structured claims from fixture evidence, not trustless proofs. |
| Proof systems | Later research | No production proof circuits, GPU proofs, verifier networks, or proof economics exist. |
| Private state | Local-alpha target, Later research | Local secret handling and private references are future Local Alpha work; encrypted compute is later research. |

## Research Track Summary

| Track | Status | Local Alpha treatment | Later gate |
| --- | --- | --- | --- |
| Process-Witness | Later research | Map candidate primitives to receipt obligations and verifier-module metadata. Do not build cognitive proof circuits. | Exact predicates, public inputs, witnesses, adversary model, cost model, and independent crypto review. |
| SEAL/dependency proofs | Later research, Local-alpha target for vocabulary | Define dependency atoms, dependency roots, dependence classes, completeness attestations, and omitted-dependency challenges in plain verifier-attested form first. | ZK dependency proofs only after dependency schemas, completeness warranties, and challenge windows are accepted. |
| Synthetic Non-Amplification | Local-alpha target | Enforce as an invariant in receipts, verifier reports, memory lineage, and explorer state: synthetic data cannot increase empirical certainty. | Domain-specific review before biological/scientific settlement claims. |
| Proof-carrying receipts | Later research | Keep V0 receipt/report hashes stable and define candidate public inputs. Continue using deterministic verifier reports for Local Alpha. | Circuit implementation only after exact public inputs, witness privacy rules, proof system choice, setup assumptions, and cost model. |
| R&D/crypto library boundary | Local-alpha target | Research proposes candidates; the crypto library implements only accepted schemas with vectors and tests. | No speculative primitives enter production libraries without decision record and review. |

## Implementation Promotion Gates

These are the minimum gates before the research tracks below may enter implementation work.

| Track | Local/private testnet allowance | Public devnet requirement | Public L1/mainnet requirement |
| --- | --- | --- | --- |
| Process-Witness | Local-alpha target: name process obligations and verifier-module metadata only. | Later research: exact predicates, public inputs, witness formats, adversary model, cost model, failure modes, and independent crypto review. | Blocked: production cognition proof claims need audits, reproducible vectors, challenge semantics, and a separate accepted decision. |
| SEAL/dependency privacy | Local-alpha target: dependency atoms, roots, dependence classes, completeness attestations, and omission challenges in plain verifier-attested form. | Later research: ZK proof rules, completeness warranties, downgrade semantics, revocation roots, witness privacy rules, and review. | Blocked: production dependence-proof claims or evidence-merge finality before circuits and challenge economics are reviewed. |
| Synthetic Non-Amplification | Local-alpha target: status invariant and fixture/test requirement. | Later research: domain-specific policy review for any public scientific or empirical workflow. | Blocked: public empirical-certainty, biological, or scientific settlement claims without real-world evidence gates. |
| Proof-carrying receipts | Local-alpha target: stable hashes, schemas, public-input candidates, and deterministic verifier reports. | Later research: proof system choice, setup assumptions, exact witnesses, proof costs, negative vectors, and verifier/challenge policy. | Blocked: contract proof verification or trustless receipt claims without independent audit. |
| Advanced encrypted compute | Explicitly later: no implementation; only threat-model vocabulary may be documented. | Later research: public/private state model, key custody, leakage analysis, DA/auditability, attestation semantics, and incident response review. | Blocked: FHE/MPC/TEE/coprocessor production claims without security review and operational policy. |

## Process-Witness

### Meaning

**Later research**: Process-Witness is the legacy AI-native state research research family for certifying dimensions of AI cognition and behavior beyond "a computation matched a circuit." The review packet describes trajectory commitments, predicates over reasoning steps, concentration bounds, challenge sampling, sparse openings, composition rules, and proof/circuit paths.

### Why It Matters

**Later research**: Process-Witness is a possible long-range answer to why an AI-native chain might need native state. It could eventually bind progress, calibration, counterfactual robustness, replay resistance, refusal, inactivity, narrative/pragmatic structure, or other cognitive properties.

### Local Alpha Boundary

| Item | Status | Local Alpha handling |
| --- | --- | --- |
| Process obligation vocabulary | Local-alpha target | Allow a receipt or verifier module to name a process obligation such as replay resistance, calibration evidence, counterexample search, refusal evidence, or tool-trace completeness. |
| Process evidence reference | Local-alpha target | Store commitments or references to process evidence off-chain; do not store private reasoning traces on-chain. |
| Verifier module declaration | Local-alpha target | A verifier module may say it checks a process obligation deterministically from fixture evidence. |
| Cognitive proof circuit | Later research | Do not implement for Local Alpha. |
| Halo2/Pasta/Poseidon2-style production path | Later research | Treat as unaccepted until public inputs, witnesses, setup assumptions, and review exist. |

### No-Go Conditions

- **No-go**: Claiming the chain proves cognition, truth, intelligence, or model correctness.
- **No-go**: Building proof circuits before the receipt schema, public inputs, witness format, and verifier module semantics are accepted.
- **No-go**: Treating private reasoning traces as public artifacts.
- **No-go**: Making Process-Witness a dependency for Local Alpha launch.

## SEAL And Dependency Proofs

### Meaning

**Later research**: SEAL is the Claude research direction for typed evidence attestation and dependence proofs. Its strongest concept is a causal separation or dependency certificate that says whether evidence objects may be combined under a declared dependence class.

### Why It Matters

**Local-alpha target**: FlowMemory memory and receipts should not double-count evidence that shares a hidden dataset, model, lab, vendor, prompt, tool, worker, or analysis pipeline. Dependency handling protects the credibility of memory lineage and scientific claims.

### Local Alpha Vocabulary

| Concept | Status | Local Alpha meaning |
| --- | --- | --- |
| Dependency atom | Local-alpha target | A typed declaration of a dependency such as dataset, model lineage, tool, prompt family, lab, worker, provider, hardware source, or analysis pipeline. |
| Dependency root | Local-alpha target | Commitment to a set of dependency atoms or hidden dependency commitments. |
| Dependence class | Local-alpha target | Plain label such as independent, block-independent, exchangeable, arbitrary, synthetic-only, or unknown. |
| Completeness attestation | Local-alpha target | Issuer/verifier claim about dependency coverage, with scope and expiry. |
| Omitted-dependency challenge | Local-alpha target | Challenge that introduces a missing dependency and can downgrade finality or recompute merge status. |
| Causal separation certificate | Later research | ZK or formal proof that dependency footprints satisfy an allowed class. Not Local Alpha. |
| MergeCapability | Later research | Proof-carrying authorization to merge evidence under a dependence class. Can be mocked as verifier-attested policy in Local Alpha research only. |

### Local Alpha Rule

**Local-alpha target**: Dependency declarations can be verifier-attested before they are ZK-proven. The system should show dependency assumptions and challenge windows clearly, and should downgrade affected memory or receipt finality when omitted dependencies are accepted.

### No-Go Conditions

- **No-go**: Claiming independence when dependencies are unknown.
- **No-go**: Treating a dependency proof as sound if the issuer never warranted completeness.
- **No-go**: Allowing a dependency omission to be hidden after finality.
- **No-go**: Presenting SEAL as implemented cryptography before circuits, proof rules, and challenge semantics exist.

## Synthetic Non-Amplification

### Meaning

**Local-alpha target**: Synthetic Non-Amplification is the rule that synthetic data, simulations, model-generated evidence, and counterworlds can increase debt, risk, scrutiny, challenge windows, or discriminator requirements, but cannot increase empirical certainty without real-world validation.

### Local Alpha Invariant

| Claim type | Status | Allowed synthetic effect | Forbidden synthetic effect |
| --- | --- | --- | --- |
| Formal deterministic claim | Local-alpha target | Synthetic or generated examples may be accepted if a deterministic verifier checks the formal property. | Calling unchecked generation proof of correctness. |
| Empirical/scientific claim | Local-alpha target | Synthetic evidence may create hypotheses, counterexamples, challenge debt, or validation requirements. | Increasing clean empirical support or finality. |
| Memory quality claim | Local-alpha target | Synthetic counterexamples may mark memory as needs-review, challenged, or downgraded. | Making memory more trusted solely from synthetic support. |
| Model lineage claim | Later research | Model lineage commitments can help detect reused synthetic sources. | Claiming independence without lineage/dependency review. |

### No-Go Conditions

- **No-go**: Synthetic outputs become empirical support mass.
- **No-go**: A model-generated counterworld is treated as lab evidence.
- **No-go**: A memory cell becomes more final because generated data agrees with it.
- **No-go**: Biological or scientific settlement claims are made without real-world evidence gates.

## Proof-Carrying Receipts

### Current Boundary

**Implemented foundation**: V0 uses deterministic hashes, schemas, fixtures, and verifier reports. These are replayable claims, not trustless proofs.

**Later research**: Proof-carrying receipts may later attach zero-knowledge or succinct proofs to stable receipt/report hashes.

### Candidate Public Inputs

**Later research**: Future proof-carrying receipts should preserve the V0 receipt hash as a public input candidate.

Candidate public inputs:

- `schemaId`
- `chainId`
- `observationId`
- `eventArgsHash`
- `receiptHash`
- `artifactRoot`
- `storageReceiptCommitment`
- `verifierPolicyHash`
- `reportSchemaHash`
- `dependencyRoot`
- `finalityPolicyHash`

Candidate witnesses:

- Event args.
- Artifact manifest.
- Merkle opening path.
- Storage receipt opening.
- Check result details.
- Worker signature preimage.
- Verifier signature preimage.
- Dependency atom openings.

### Local Alpha Treatment

| Capability | Status | Treatment |
| --- | --- | --- |
| Receipt internal consistency | Local-alpha target | Keep deterministic replay and vector tests; define public inputs for later proofs. |
| Artifact Merkle inclusion | Later research | Good first proof candidate, but Local Alpha can use deterministic verifier reports. |
| Verifier-report consistency | Later research | Candidate circuit only after report schema and check set stabilize. |
| Rootflow aggregation | Later research | Candidate recursive aggregation path after receipt lifecycle stabilizes. |
| Chain receipt/log canonicality | Later research | Harder proof candidate; do not depend on it for Local Alpha. |

### No-Go Conditions

- **No-go**: Building circuits before accepted observation identity, receipt/report schemas, vectors, witness privacy rules, and cost model.
- **No-go**: Treating verifier attestations as trustless proofs.
- **No-go**: Forcing private artifact bytes public unless challenge or disclosure policy requires it.
- **No-go**: Adding proof verification to contracts before public inputs and threat model are accepted.

## R&D / Crypto Library Boundary

### Boundary Statement

**Local-alpha target**: Research and development can propose candidate primitives, object models, and go/no-go criteria. The crypto library should implement only accepted, versioned, test-vector-backed schemas.

### Ownership Split

| Work type | Status | Owner boundary |
| --- | --- | --- |
| Research vocabulary | Local-alpha target | `research/` may define concepts, risks, gates, and candidate data shapes. |
| Accepted schema | Implemented foundation, Local-alpha target | `crypto/` may implement only after the schema is accepted or explicitly marked candidate with tests. |
| Test vectors | Implemented foundation, Local-alpha target | Any library behavior needs deterministic vectors and negative cases. |
| Proof circuits | Later research | Must remain out of production code until go/no-go gates approve exact public inputs, witnesses, setup assumptions, and costs. |
| Private-state crypto | Later research | Local vault can use reviewed existing libraries later; custom cryptography requires review. |
| Protocol contracts | Explicitly outside this task | Contracts must not import speculative crypto primitives from research docs. |

### Promotion Checklist

Before a research primitive can move toward library implementation:

1. **Local-alpha target**: Define the object and threat model.
2. **Local-alpha target**: Define canonical serialization and domain separation.
3. **Local-alpha target**: Define replay boundaries.
4. **Local-alpha target**: Define public and private fields.
5. **Local-alpha target**: Define test vectors and negative vectors.
6. **Local-alpha target**: Define status semantics and failure behavior.
7. **Later research**: Define proof public inputs and witnesses if proofs are involved.
8. **Later research**: Get independent cryptography review for new proof claims.
9. **No-go**: Do not implement if the primitive requires tokenomics, bridge assumptions, production validators, or encrypted compute to be meaningful.

## Builder Guidance

- **Implemented**: Use current V0 crypto helpers and schemas as the factual baseline.
- **Local-alpha target**: Prefer deterministic verifier reports and challengeable provenance before proofs.
- **Local-alpha target**: Keep dependency declarations visible even when private details are hidden.
- **Local-alpha target**: Treat synthetic evidence as risk/debt unless real-world evidence validates it.
- **Later research**: Add proof-carrying receipts only after the receipt lifecycle is stable and the cost/benefit beats ordinary verifier replay.
- **No-go**: Do not let research novelty become a product security claim.
