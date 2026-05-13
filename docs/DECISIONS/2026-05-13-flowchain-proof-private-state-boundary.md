# FlowChain Proof And Private-State Boundary

Date: 2026-05-13

## Status

Accepted for research and implementation gating.

## Context

The FlowMemory research packet contains advanced ideas: Process-Witness, SEAL/dependency privacy, Synthetic Non-Amplification, proof-carrying receipts, private evidence, encrypted compute, bridge security, and future validator/sequencer economics. These ideas matter for long-term coherence, but none of them are production-ready protocol surfaces in the current repo.

FlowMemory already has V0 hashes, schemas, receipts, verifier reports, local fixtures, and a no-value devnet prototype. Those are deterministic local/test artifacts, not trustless proof systems or production private compute.

## Decision

FlowChain may use advanced research only as gated vocabulary until prerequisites are accepted:

- **Process-Witness** remains later research. Local/private work may name process obligations and verifier-module metadata, but may not build cognitive proof circuits or claim the chain proves cognition, truth, or model correctness.
- **SEAL/dependency privacy** remains later research. Local/private work may model dependency atoms, dependency roots, dependence classes, completeness attestations, and omitted-dependency challenges in verifier-attested form before any ZK dependence proof.
- **Synthetic Non-Amplification** is a local-alpha invariant. Synthetic data can create hypotheses, counterexamples, challenge debt, scrutiny, or validation requirements. It must not increase empirical certainty or memory trust without real-world validation, except for formal deterministic claims checked by deterministic verifiers.
- **Proof-carrying receipts** remain later research. Local/private work should preserve stable receipt/report hashes and public-input candidates, but production circuits, contract proof verification, and trustless receipt claims are blocked.
- **Advanced encrypted compute** is explicitly later. FHE, MPC, TEE, encrypted coprocessors, encrypted mempools, and private inference are blocked until public/private state, key custody, leakage, DA, auditability, and incident-response requirements are reviewed.
- **Bridge security** is explicitly later for value movement. Local work may model no-value anchor placeholders and replay boundaries only.
- **Validator/sequencer economics** are explicitly later and blocked. Non-economic operator roles may be documented for future public devnet research; staking, rewards, fees, slashing, token mechanics, or revenue claims require a separate approved scope.

## Alternatives Considered

- **Implement proof systems now**: rejected because public inputs, witness formats, setup assumptions, cost model, negative vectors, and challenge semantics are not accepted.
- **Use encrypted compute to solve privacy early**: rejected because the basic public/private data model and local vault/reference boundary must come first.
- **Treat verifier attestations as trustless proofs**: rejected because V0 verifier reports are deterministic and replayable but remain claims.
- **Add economics to solve public operator behavior**: rejected because tokenomics is forbidden in the current scope and would obscure missing security design.

## Consequences

- Local/private testnet work can stay practical: deterministic fixtures, vectors, verifier reports, private references, challenges, and provenance before advanced proofs.
- Public devnet and L1/mainnet work cannot rely on research primitives until they have accepted specs and reviews.
- Scientific, biological, or empirical settlement claims remain blocked until real-world evidence gates and dependency policies exist.
- The crypto library should only accept versioned, vector-backed schemas; speculative primitives stay in research.

## Scope Boundaries

This decision does not authorize:

- crypto implementation;
- proof circuits;
- production encrypted compute;
- bridge deployment;
- tokenomics;
- verifier economics;
- validator or sequencer economics;
- production L1/mainnet launch planning.

## Follow-Ups

- Draft dependency atom/root schemas before any dependency proof work.
- Draft challenge/finality transitions before any downgrade-sensitive receipt implementation.
- Keep proof public-input candidates aligned with V0 receipt and verifier report hashes.
- Require a separate decision record before any research primitive moves into `crypto/`, `contracts/`, `services/`, `apps/`, or `crates/`.
