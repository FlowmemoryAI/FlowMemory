# Architecture

FlowMemory is a layered system for commitment-oriented AI memory, verification,
operator tooling, and bounded hardware research. The public architecture centers
on agent work becoming inspectable through compact commitments, receipts,
verifier reports, Rootflow transitions, Agent Bonds, and operator apps.

## Layer Map

1. Contracts foundation
2. Fixture and verification harness
3. Rootflow and Flow Memory launch core
4. Indexer/verifier
5. Crypto schema layer
6. Dashboard and operator apps
7. Public-agent network
8. Agent Bonds accountability layer
9. Hardware and control signaling
10. Research lab
11. HQ program operating system

## Contracts

Current implementation:

- `contracts/FlowPulse.sol` defines the FlowPulse v0 event interface and pulse type constants.
- `contracts/RootfieldRegistry.sol` registers Rootfield namespaces, accepts root commitments, and emits FlowPulse events.
- Agent Bonds and public-agent contracts provide local/test accountability, launch, fuel, lineage, receipt, and swarm primitives.
- `contracts/FLOWPULSE_SCHEMA.md` documents event semantics.

Responsibilities:

- Emit FlowPulse events.
- Store intentional compact protocol state.
- Store roots, receipts, commitments, attestations, proofs, and work state only when deliberately part of the protocol.

Boundaries:

- Contracts do not store heavy AI memory, model artifacts, media, or raw evidence.
- Contracts do not know final `txHash` or `logIndex`.
- `metadataURI` and `evidenceURI` are advisory log strings in the current skeleton.
- Dynamic fees, tokenomics, production deployment, and production hooks are out of scope.

## Fixture And Verification Harness

Purpose:

- Connect contracts, fixture logs, parser expectations, verifier report shape, and public smoke tests.
- Provide a runnable local/test V0 stack before live service or production deployment work.

Expected artifacts:

- Foundry test output.
- FlowPulse fixture logs.
- Receipt fixture handoff documents.
- Deterministic parser and verifier fixture expectations.

Boundaries:

- No production deployment.
- No production RPC credentials.
- No hosted production services.

## Rootflow And Flow Memory

Status: launch-critical V0 specification with merged local/test implementations across contracts, crypto, indexer/verifier, services, fixtures, and dashboard.

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

- Rootflow is a memory-state transition model, not a deployment environment.
- Flow Memory is not unlimited on-chain storage.
- V0 verification is local/test readiness, not a full trustless verifier network.
- Dashboard-readable state may be fixture-backed until services stabilize.

## Indexer And Verifier

Status: fixture-first local/test package.

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
- Service runtimes, persistence, APIs, and live readers should follow fixture and schema decisions.
- Verifier economics, staking, slashing, and production networks are out of scope.

## Crypto

Status: V0 helpers, schemas, vectors, local wallet boundaries, and attestation primitives exist.

Responsibilities:

- Define receipts, attestations, roots, commitments, proofs, report digests, and signature envelopes.
- Define domain separation, replay boundaries, canonical serialization, and test-vector expectations.
- Support verifier/report schemas without forcing a proof system.

Boundaries:

- No proof circuits.
- No GPU proofs.
- No verifier economics.
- No production cryptographic infrastructure.

## Dashboard And Operator Apps

Status: generated fixture-backed dashboard plus desktop and Android shells.

Responsibilities:

- Present observed, pending, finalized, verified, failed, unresolved, unsupported, and reorged states clearly.
- Expose Agent Bonds, Flow Memory, public-agent, receipt, verifier, wallet/budget, and alert surfaces for operators.
- Keep browser, desktop, and mobile operator surfaces aligned around the same public FlowMemory story.

Boundaries:

- No production APIs until explicitly scoped.
- No production wallet custody claim.
- iOS remains a product track until an Xcode project and CI lane are committed.

## Public-Agent Network

Status: local/test public-agent and swarm stack exists.

Responsibilities:

- Launch agents from supported classes and approved tool sets.
- Track profile, lineage, memory fuel, launch bonds, receipt anchors, and swarm/budget state.
- Provide deterministic preview, intent, replay, SDK/CLI, and dashboard projection surfaces.

Boundaries:

- Users do not upload arbitrary agent Solidity.
- Heavy prompts, artifacts, model outputs, embeddings, and media remain off-chain.
- Direct transaction submission still needs provider-backed SDK completion and readback evidence.

## Agent Bonds

Status: local/test accountability, recourse, and reputation primitives exist.

Responsibilities:

- Model objective task opening, acceptance, verification, settlement, challenge, slash, and capped recourse paths.
- Keep quote attestations, evidence windows, verifier separation, credit scoring, and underwriter-pool constraints explicit.
- Surface task-scoped risk and recourse state to dashboards and future mobile apps.

Boundaries:

- No insurance claim.
- No guaranteed reimbursement claim.
- No uncapped public value flow.

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

## HQ Program Operating System

Responsibilities:

- Keep `docs/CURRENT_STATE.md`, `docs/ROADMAP.md`, this architecture doc, and `docs/ISSUE_BACKLOG.md` current.
- Keep worktree assignments and PR process enforceable.
- Maintain labels, milestones, review flow, and daily runbook.
- Prevent overlapping worktree lanes from editing the same folders or expanding into gated work.

## Data Flow

1. A local/test or future deployed contract action emits FlowPulse and updates compact on-chain state.
2. The local harness or live reader produces receipts and logs.
3. The indexer reads logs and receipts, then derives `txHash`, `logIndex`, block metadata, and observation identity.
4. The indexer constructs MemorySignal and Rootflow transition candidates.
5. The verifier consumes indexed observations and checks commitments against allowed off-chain evidence.
6. Crypto schemas define receipt ids, report digests, attestations, commitments, transition ids, and domain separation.
7. Dashboard and app models consume Rootfield, Rootflow, MemorySignal, MemoryReceipt, AgentMemoryView, Agent Bonds, and public-agent states.
8. Hardware sidecars may exchange compact control messages or receipt references, but not heavy data.
9. Research artifacts stay off-chain and become protocol-relevant only through explicit commitments or accepted decision records.

## Source Of Truth Flow

GitHub issues define planned work. Pull requests propose changes. Merged files update source truth. `docs/CURRENT_STATE.md` summarizes what is actually merged. Unmerged worktree changes are not source truth.
