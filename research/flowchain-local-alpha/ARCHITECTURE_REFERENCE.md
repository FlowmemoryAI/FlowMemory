# FlowChain Local Alpha Architecture Reference

Last updated: 2026-05-13

Status: research reference, not an implementation plan and not a production L1 approval.

## Purpose

FlowChain is used here as a working research name for the future chain-shaped direction of FlowMemory. This document defines the research-to-build boundary for FlowChain Local Alpha.

The Local Alpha goal is not to launch a public chain. The goal is to make the FlowMemory object model concrete enough that builders can implement local workbench, API, devnet, explorer, provenance, and release workflows without importing production validator, token, bridge, or advanced encrypted-compute scope.

## Status Vocabulary

Every major claim in this reference uses one of these labels:

- **Implemented**: merged into the current FlowMemory repo as of `docs/CURRENT_STATE.md` dated 2026-05-13 or confirmed from `origin/main` on 2026-05-13.
- **Local-alpha target**: appropriate to specify and later build for FlowChain Local Alpha, but not implemented by this research task.
- **Later research**: useful direction, but blocked behind review, proof, product, or security gates.
- **Blocked**: cannot move to implementation until named prerequisites are met.
- **Explicitly later**: intentionally not part of Local Alpha.

## Source Map

| Source | Status | How it should influence Local Alpha |
| --- | --- | --- |
| FlowMemory built state | Implemented | Use the merged launch-core V0 stack, schemas, fixture-backed dashboard, local no-value devnet, crypto V0 helpers, and chain docs as the factual baseline. |
| external local-chain reference comparison | Local-alpha target | Copy the discipline of a coherent local control plane, stable API, recoverable local state, source visibility, and explorer observability. Do not copy bridge, token, or encrypted-coprocessor ambition into Local Alpha. |
| legacy AI-native state research research | Later research | Treat AI Work Receipts, ModelPassports, AgentAccounts, MemoryCells, verifier modules, Process-Witness, and cognitive proof primitives as candidate long-term native objects and proof families. |
| Claude crypto research | Later research | Treat SEAL/dependency proofs, Synthetic Non-Amplification, proof-carrying receipts, and private evidence as research directions that inform boundaries before they become protocol code. |
| `chain/` docs | Implemented as research docs | Keep Base anchors, bridge security, hardware node roles, DA, and L1/appchain work gated. |

## Current Implemented Baseline

| Area | Status | Current fact |
| --- | --- | --- |
| FlowPulse event spine | Implemented | Contracts define FlowPulse V0 event semantics and the launch fixture path. Hooks still cannot know final `txHash` or `logIndex`; indexers derive those after receipts and logs exist. |
| Hook-adjacent swap signal path | Implemented | `FlowMemoryHookAdapter` remains a dependency-light V0 scaffold and now includes a Uniswap v4-shaped `afterSwap` callback surface. It is still not a production Uniswap v4 hook. |
| Rootfield and compact registries | Implemented | Local/test skeleton contracts exist for roots, artifacts, cursors, work receipts, verifier reports, workers, verifiers, and work state. They are not production protocol surfaces. |
| Crypto V0 foundation | Implemented | Keccak-based typed helpers, domains, receipt/report/root/artifact/work helpers, fixtures, and vectors exist under `crypto/`. Proof systems do not exist. |
| Indexer/verifier fixture path | Implemented | Fixture-first services produce local observations, cursors, duplicate/reject states, and verifier reports. They are not a production verifier network. |
| Flow Memory and Rootflow launch objects | Implemented | `MemorySignal`, `MemoryReceipt`, `RootflowTransition`, `RootfieldBundle`, and `AgentMemoryView` schemas and generated fixtures exist. |
| Dashboard V0 | Implemented | The dashboard renders generated fixture state for Flow Memory, Rootflow, FlowPulse, Rootfields, receipts, reports, devnet blocks, hardware nodes, alerts, and raw JSON. It is fixture-backed. |
| Local no-value devnet | Implemented | Rust prototype models deterministic local transactions, blocks, state roots, and handoff output. It is not consensus, validators, a token system, or a bridge. |
| Base canary | Implemented as test evidence | A small Base mainnet canary exists for V0 testing only. A guarded canary reader and separate canary dashboard dataset now exist for known addresses and small explicit block ranges. They do not change production guardrails. |

## Local Alpha Definition

**Local-alpha target**: FlowChain Local Alpha is a receipt-native local control plane for FlowMemory state, not a public chain.

It should prove that the following can be inspected, replayed, tested, and released locally:

- Work receipts and memory receipts.
- Rootflow transitions and parent/child state.
- Artifact commitments and availability status.
- Verifier reports and verifier module provenance.
- Challenge windows, finality state, and downgrade paths.
- Dependency roots and declared evidence relationships.
- Local devnet blocks, state roots, and Base anchor placeholders.
- Private references only as local encrypted references, not private computation.

## Gate Map

| Gate | Status | Architecture meaning |
| --- | --- | --- |
| Local/private testnet | Local-alpha target | A no-value second-computer package that uses the existing launch-core, local devnet, fixture pipeline, API/workbench target, provenance, and release manifest to prove the object model locally. |
| Public devnet | Later research, Blocked | A public experimental network can be considered only after the local/private package is reproducible, monitored, and reviewed. |
| Public L1/mainnet | Explicitly later, Blocked | A production or value-bearing chain requires a separate readiness program, independent review, bridge/DA/security work, and explicit accepted decisions. |

Only the local/private testnet gate may be used as near-term implementation guidance. Public devnet and public L1/mainnet language is boundary-setting research only.

## Architecture Layers

| Layer | Status | Local Alpha responsibility | Boundary |
| --- | --- | --- | --- |
| Object model | Local-alpha target | Define the objects that would justify a future appchain: `WorkReceipt`, research `AIWorkReceipt`, `MemoryCell`, `ArtifactAvailabilityProof`, `VerifierModule`, `Challenge`, `FinalityReceipt`, and `DependencyRoot`. | Do not claim these are all implemented as chain-native state. |
| Local workbench | Local-alpha target | Provide a local operator/developer surface for receipts, memory lineage, artifacts, verifier reports, challenges, dependency roots, finality, fixtures, and devnet state. | Not a wallet-first product, not a hosted production service. |
| Local API | Local-alpha target | Expose predictable local read/write/introspection methods for the workbench, agents, dashboard, and tests. | No production API or hosted persistence until separately scoped. |
| Devnet | Implemented foundation, Local-alpha target for hardening | Keep the no-value deterministic devnet as the local execution model and fixture handoff source. | No validators, sequencers, consensus claims, bridge, token, or public network. |
| Explorer | Implemented foundation, Local-alpha target for richer observability | Extend the fixture-backed dashboard/explorer concept so every receipt, verifier report, challenge, lineage edge, and finality status can be inspected without raw JSON. | Explorer views must not imply production finality or trustless verification. |
| Provenance | Local-alpha target | Make schemas, verifier modules, generated reports, fixture sources, deployment artifacts, and release manifests source-visible and hash-addressed. | Provenance is evidence and reproducibility, not proof of truth. |
| Releases | Local-alpha target | Ship versioned local-alpha releases with fixture snapshots, schema versions, migration notes, known limitations, and reproducibility checks. | No mainnet, token, bridge, validator, or encrypted-compute release narrative. |
| Proof systems | Later research | Map future proof-carrying receipts, SEAL/dependency proofs, and Process-Witness primitives to exact public inputs and witness privacy rules. | No production circuits until accepted schemas, vectors, costs, and review gates exist. |
| L1/appchain | Later research | Decide whether native receipt and memory state is meaningfully stronger than app-level logs on Base or another chain. | Public L1/appchain is blocked until go/no-go gates are met. |

## Native Object Model Direction

| Object | Status | Local Alpha meaning | Later L1 question |
| --- | --- | --- | --- |
| `WorkReceipt` | Implemented foundation, Local-alpha target | Current contracts and schemas already model compact work receipt commitments. Local Alpha should make lifecycle, provenance, challenge, and finality inspectable. | Should work receipts be native state or app-level logs? |
| `AIWorkReceipt` | Later research | Research name for AI-specific work involving model, prompt/input, output, tools, memory delta, artifacts, environment, dependencies, verifier decisions, and finality. | Is AI-specific receipt state essential enough to justify a chain? |
| `MemoryCell` | Local-alpha target | Durable memory unit with lineage to receipts, roots, artifacts, dependency declarations, status, and challenge/finality state. | Should memory cells be native state rather than derived indexer state? |
| `ArtifactAvailabilityProof` | Local-alpha target | Structured commitment or report about artifact root, manifest, locator policy, availability checks, and challenge response. | What availability guarantees are required before value-bearing work? |
| `VerifierModule` | Local-alpha target | Source-visible verifier policy/module with schema hash, version, check set, expected inputs, and deterministic report rules. | Can verifier modules become chain-native without central trust? |
| `Challenge` | Local-alpha target | Explicit state for disputed receipts, unavailable artifacts, omitted dependencies, stale finality, or failed verifier checks. | What challenge/finality model is safe for public appchain use? |
| `FinalityReceipt` | Local-alpha target | Reportable status that says what became accepted, rejected, unresolved, downgraded, superseded, or finalized and why. | Can finality be native while remaining downgradeable for dependency omissions? |
| `DependencyRoot` | Local-alpha target | Commitment to declared evidence, tool, data, model, lab, worker, or pipeline dependencies. | When, if ever, does SEAL-style private dependency proof become required? |

## Local Alpha Data Flow

1. **Implemented**: A local fixture, test contract, or constrained testnet reader produces FlowPulse observations and compact contract state.
2. **Implemented**: The indexer derives observation identity from receipts and logs after execution.
3. **Implemented**: The verifier produces deterministic local reports from fixture evidence.
4. **Implemented**: Launch-core generators produce Flow Memory and Rootflow fixtures.
5. **Local-alpha target**: The local API exposes receipt, memory, artifact, verifier, challenge, dependency, and finality resources with stable error shapes and pagination.
6. **Local-alpha target**: The workbench/explorer lets a builder inspect the whole path from pulse to receipt to verifier report to memory/root transition.
7. **Local-alpha target**: Provenance records tie every receipt/report to schema hashes, verifier module hashes, fixture/release hashes, and source references.
8. **Later research**: Proof-carrying receipts or appchain-native state replace some deterministic verifier claims only after review gates.

## Build Boundary

| Allowed for Local Alpha planning | Status | Not allowed in this task |
| --- | --- | --- |
| Research docs under `research/flowchain-local-alpha/` | Local-alpha target | Contract, service, app, crypto, hardware, production chain, bridge, tokenomics, or mainnet implementation. |
| Object model and acceptance criteria | Local-alpha target | Any claim that Local Alpha is a public chain. |
| API, workbench, explorer, provenance, and release requirements | Local-alpha target | Hosted production API or production dashboard work. |
| Go/no-go gates for future L1/appchain work | Local-alpha target | Validator set design, staking, sequencer operations, governance, fees, or token design. |
| Crypto research map and private-state roadmap | Local-alpha target | ZK circuits, encrypted compute runtime, threshold crypto, or production proof systems. |

## What FlowChain Should Be At external local-chain reference-Level

| Competency | Status | FlowChain Local Alpha bar |
| --- | --- | --- |
| Local workbench | Local-alpha target | A coherent local surface for receipt/memory/artifact/verifier/challenge/finality workflows. |
| API | Local-alpha target | Stable local methods and schemas that agents, workbench, explorer, and tests can share. |
| Devnet | Implemented foundation, Local-alpha target for polish | Deterministic no-value execution, reset, fixture import/export, state-root inspection, and reproducible handoff. |
| Explorer | Implemented foundation, Local-alpha target for completeness | Observability for lineage, verifier decisions, artifact state, dependency roots, challenges, and finality. |
| Provenance | Local-alpha target | Hash-addressed schema, verifier module, fixture, report, and release evidence. |
| Object model | Local-alpha target | WorkReceipt, MemoryCell, artifact proof, verifier module, challenge, finality receipt, dependency root, and research AIWorkReceipt vocabulary. |
| Releases | Local-alpha target | Versioned local-alpha bundles with schemas, fixtures, release manifest, reproducibility commands, limitations, and migration notes. |

## Explicitly Later

| Topic | Status | Reason |
| --- | --- | --- |
| Production validators | Explicitly later | Local Alpha has no consensus or public validator network. |
| Public L1 | Explicitly later | The native receipt/memory state model must prove useful locally first. |
| Tokenomics | Explicitly later | Value-bearing mechanics would distort Local Alpha and require separate security/economic review. |
| Bridges | Explicitly later | Bridge design requires DA, replay, finality, custody, emergency pause, monitoring, and independent review. |
| Advanced encrypted compute | Later research | Private state starts with local secrets and private references; encrypted compute requires cryptographic and systems review. |
| Production proof systems | Later research | Proof systems need exact public inputs, witness formats, setup assumptions, costs, and challenge semantics before implementation. |

## Decision Rule For Future L1/Appchain Work

**Later research**: FlowChain should move beyond Local Alpha only if the answer is yes to this question:

```text
Would FlowMemory be meaningfully weaker if work receipts, memory cells, dependency roots, verifier decisions, challenges, and finality receipts were only app-level logs on another chain?
```

If the answer is no, the correct path is to keep building on Base or another existing settlement layer and improve the local product, API, and verifier experience first.

## Non-Negotiable Guardrails

- **Implemented boundary**: Heavy AI, model, memory, media, artifact, and evidence data stays off-chain.
- **Implemented boundary**: Transaction hashes and log indexes are derived by indexers after receipts and logs exist.
- **Local-alpha target**: Public receipt metadata must be separated from private artifact references and local secret material.
- **Local-alpha target**: Synthetic evidence must never increase empirical certainty without real-world validation.
- **Local-alpha target**: Dependency omission must remain challengeable; polished proofs cannot hide incomplete provenance.
- **Explicitly later**: Production validator, bridge, token, mainnet, and encrypted-compute work stays out until separate go/no-go decisions approve it.
