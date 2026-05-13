# Architecture

FlowMemory is a layered system for commitment-oriented AI memory, verification,
local operator tooling, and bounded hardware research. The merged repo now has
the V0 launch-core, local deterministic devnet prototype, fixture
indexer/verifier, dashboard, crypto helpers, hardware simulator, and HQ wrapper
layer. Native private/local FlowChain object lifecycle, control-plane coverage,
long-running node behavior, and full workbench coverage remain in flight until
explicitly merged.

## Layer Map

1. Contracts foundation
2. Integration harness and local fixtures
3. Rootflow and Flow Memory launch core
4. Indexer/verifier
5. Crypto schema layer
6. Dashboard and operator apps
7. Hardware and control signaling
8. Research lab
9. Devnet/appchain research
10. HQ program operating system
11. FlowChain private/local testnet packaging

## Contracts

Current implementation:

- `contracts/FlowPulse.sol` defines the FlowPulse v0 event interface and pulse type constants.
- `contracts/RootfieldRegistry.sol` registers Rootfield namespaces, accepts root commitments, and emits FlowPulse events.
- `contracts/FLOWPULSE_SCHEMA.md` documents event semantics.
- `tests/RootfieldRegistry.t.sol` provides initial Foundry tests.

Responsibilities:

- Emit FlowPulse events.
- Store intentional compact protocol state.
- Store roots, receipts, commitments, attestations, proofs, and work state only when deliberately part of the protocol.

Boundaries:

- Contracts do not store heavy AI memory, model artifacts, media, or raw evidence.
- Contracts do not know final `txHash` or `logIndex`.
- `metadataURI` and `evidenceURI` are advisory log strings in the current skeleton.
- Dynamic fees, tokenomics, production deployment, and production hooks are out of scope.

## Integration Harness And Local Fixtures

Purpose:

- Connect contracts, fixture logs, parser expectations, verifier report shape, and local smoke tests.
- Provide a runnable local V0 stack before live service or production deployment work.

Expected artifacts:

- Foundry test output.
- FlowPulse fixture logs.
- Local devnet smoke-test notes.
- Receipt fixture handoff documents.
- Deterministic parser and verifier fixture expectations.

Boundaries:

- No mainnet deployment.
- No production RPC credentials.
- No hosted services.

## Rootflow And Flow Memory

Status: launch-critical V0 specification, with implementation expected across contracts, crypto, indexer/verifier, and dashboard PRs.

Primary docs:

- `docs/ROOTFLOW_V0.md`
- `docs/FLOW_MEMORY_V0.md`
- `docs/V0_LAUNCH_ACCEPTANCE.md`
- `docs/DECISIONS/rootflow-v0.md`

Responsibilities:

- Define Rootflow transitions from observed FlowPulse events to committed memory roots.
- Define Flow Memory objects for AI agents and dashboards.
- Link Rootfield namespaces, root commitments, parent state, receipts, verifier reports, and statuses.
- Preserve the distinction between compact on-chain commitments and off-chain memory/artifact data.

Boundaries:

- Rootflow is not a production L1.
- Flow Memory is not unlimited on-chain storage.
- V0 verification is local/testnet readiness, not a full trustless verifier network.
- Dashboard-readable state may be fixture-backed until services stabilize.

## Indexer And Verifier

Status: specification and fixture work only.

Responsibilities:

- Read receipts and logs.
- Derive `txHash`, `logIndex`, block metadata, and observation identity.
- Reconstruct FlowPulse streams.
- Track pending, finalized, duplicate, failed, unsupported, unresolved, and reorged states.
- Resolve off-chain artifacts.
- Verify roots, receipts, commitments, attestations, and proof placeholders against allowed evidence.
- Produce deterministic verification reports and outputs.

Crypto foundation:

- Use `crypto/FLOWMEMORY_CRYPTO_SPEC.md` as the draft v0 schema overview.
- Use `crypto/OBSERVATION_IDENTITY.md` to distinguish contract `pulseId`, indexer-derived `observationId`, and verifier `reportId`.
- Use `services/verifier/README.md` for the draft deterministic verifier report flow and status vocabulary.

Boundaries:

- Indexers and verifiers derive receipt metadata after execution.
- Service runtimes, persistence, APIs, and live RPC readers should follow fixture and schema decisions.
- Verifier economics, staking, slashing, and production networks are out of scope.

## Crypto

Status: vocabulary and schema planning only.

Responsibilities:

- Define receipts, attestations, roots, commitments, proofs, report digests, and signature envelopes.
- Define domain separation, replay boundaries, canonical serialization, and test-vector expectations.
- Support verifier/report schemas without forcing a proof system.

Boundaries:

- No proof circuits.
- No GPU proofs.
- No verifier economics.
- No production cryptographic infrastructure.

## Dashboard

Status: data model planning only.

Responsibilities:

- Define app-facing entities for operator dashboard and protocol explorer.
- Present observed, pending, finalized, verified, failed, unresolved, unsupported, and reorged states clearly.
- Consume indexer/verifier outputs once local schemas stabilize.

Boundaries:

- No frontend scaffolding until the data model is accepted.
- No production APIs.
- No full dashboard implementation in the foundation-hardening phase.

## Hardware

Status: bounded research and POC planning only.

Responsibilities:

- Define FlowRouter v0 research scope.
- Explore Meshtastic and LoRa control-signaling messages.
- Explore enclosure, NFC memory cartridge, FlowCore indicator, and two-node demo concepts.
- Track physical, operator, power, cooling, and radio assumptions.

Boundaries:

- Meshtastic and LoRa are low-bandwidth control channels.
- Hardware work must not claim broadband-over-LoRa, ISP replacement, production mesh, or manufacturing readiness.
- Firmware production, final CAD, RF certification, manufacturing files, and production deployment are out of scope.

## Research

Status: research-only.

Responsibilities:

- Define AI memory artifact taxonomy.
- Separate hypotheses, experiments, accepted decisions, and committed artifacts.
- Track neural geometry, retrieval, continuity, compression, reliability, and proof-carrying receipt research.

Boundaries:

- Heavy memory and model artifacts stay off-chain.
- No model training pipeline is implied by architecture docs.
- Research notes do not authorize protocol implementation.

## Devnet And Appchain Research

Status: local no-value devnet prototype implemented; broader appchain/L1 work
remains gated research.

Responsibilities:

- Define no-value local devnet criteria.
- Define Base settlement anchor specs.
- Research bridge/security review requirements.
- Define appchain hardware-node implications.

Boundaries:

- No production L1 or appchain.
- No tokenomics.
- No validator or sequencer deployment.
- No bridge deployment.

## HQ Program Operating System

Responsibilities:

- Keep `docs/CURRENT_STATE.md`, `docs/ROADMAP.md`, this architecture doc, and `docs/ISSUE_BACKLOG.md` current.
- Keep agent prompts and PR process enforceable.
- Maintain labels, milestones, review flow, and daily runbook.
- Prevent agents from overlapping folders or expanding into gated work.

## FlowChain Private/Local Testnet Packaging

Status: Windows-first wrapper command layer implemented for merged surfaces.

Responsibilities:

- Provide one second-computer command path for prerequisites, init, bounded
  start/stop, demo, smoke, export/import, and workbench dev mode.
- Keep wrappers pointed at the existing Rust devnet, launch-core generator,
  dashboard, hardware simulator, and guardrail scripts.
- Record remaining subsystem blockers in `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md`
  and `docs/ISSUE_BACKLOG.md`.

Boundaries:

- The wrapper layer does not create a second devnet, dashboard, crypto package,
  verifier pipeline, object model, or setup path.
- The current `flowchain:start` command is a bounded local CLI readiness path,
  not a long-running node.
- Production public-chain, token, bridge, and audited-cryptography claims remain
  outside this milestone.

## Data Flow

1. A local or future deployed contract action emits FlowPulse and updates compact on-chain state.
2. The local harness or chain client produces receipts and logs.
3. The indexer reads logs and receipts, then derives `txHash`, `logIndex`, block metadata, and observation identity.
4. The indexer constructs MemorySignal and Rootflow transition candidates.
5. The verifier consumes indexed observations and checks commitments against allowed off-chain evidence.
6. Crypto schemas define receipt ids, report digests, attestations, commitments, transition ids, and domain separation.
7. Dashboard models consume Rootfield, Rootflow, MemorySignal, MemoryReceipt, and AgentMemoryView states.
8. Hardware sidecars may exchange compact control messages or receipt references, but not heavy data.
9. Research artifacts stay off-chain and become protocol-relevant only through explicit commitments or accepted decision records.

## Source Of Truth Flow

GitHub issues define planned work. Pull requests propose changes. Merged files update source truth. `docs/CURRENT_STATE.md` summarizes what is actually merged. Unmerged worktree changes are not source truth.
