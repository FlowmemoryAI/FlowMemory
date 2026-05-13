# Roadmap

This roadmap is the project-management view of FlowMemory. Use GitHub issues for execution and `docs/DECISIONS/` for durable decisions.

Production L1, tokenomics, mainnet deployment, production Uniswap v4 hook deployment, hardware manufacturing, and full dashboard implementation are later gated work. They are not approved by this roadmap.

## Immediate Major Milestone: Rootflow And Flow Memory V0 Launch Core

Goal: make a local developer able to run the smallest FlowMemory loop without production deployment.

The launch-core V0 stack means:

- Contracts compile and tests run locally.
- FlowPulse fixtures can be produced or consumed deterministically.
- Rootflow transitions link FlowPulse observations, parent state, receipts, verifier reports, and new roots.
- Flow Memory objects expose MemorySignal, MemoryReceipt, RootfieldBundle, and AgentMemoryView shapes.
- Indexer/verifier specs define observation identity, reorg states, and report shape.
- Crypto vocabulary defines receipts, attestations, roots, commitments, and proof boundaries.
- Dashboard can consume fixture-backed observed, pending, verified, failed, unsupported, and reorged states.
- Hardware and research tracks have bounded specs but do not block local software validation.

Non-goals:

- No tokenomics.
- No dynamic fees.
- No production deployments.
- No production L1/appchain.
- No production hook deployment.
- No hardware manufacturing.
- No hosted production dashboard or production API.

## Near-Term Phases

### Phase 0: V0 Repo OS

Status: active maintenance.

- Keep source-of-truth docs accurate.
- Keep agent prompts, PR process, daily runbook, and issue backlog current.
- Keep issue templates and PR templates enforcing scope boundaries.
- Keep status scripts read-only and safe.
- Keep labels and milestones aligned with agent ownership.

### Phase 1: V0 Contracts Foundation

Status: active.

- Add minimal Foundry config and contract test workflow.
- Harden existing RootfieldRegistry tests.
- Lock FlowPulse v0 and Rootfield URI/log-data decisions.
- Define status lifecycle, ownership/recovery, namespace policy, and static-analysis plan before implementation.
- Keep dynamic fees, tokenomics, production deployment, and production hooks out of scope.

### Phase 2: V0 Local Stack

Status: active as specs and local fixtures before services.

- Specify canonical FlowPulse observation identity.
- Define verifier statuses and report JSON schema.
- Define Rootflow transition schema and parent/child state-linking behavior.
- Define Flow Memory schemas for MemorySignal, MemoryReceipt, RootfieldBundle, and AgentMemoryView.
- Define fixture-based parser and reorg-state tests.
- Define persistence and local RPC reader boundaries only after fixture behavior stabilizes.
- Define local devnet smoke-test gates without mainnet or production deployment.

### Phase 3: V0 Review/Audit

Status: active.

- Define foundation PR review rules.
- Add security reporting guidance.
- Add static-analysis planning before claiming audit readiness.
- Enforce allowed-folder and forbidden-folder boundaries.

## Mid-Term Phases

### Phase 4: V0 Crypto Schema Layer

Status: active as launch-core schema and fixture work.

- Define receipt, attestation, commitment, root, and proof vocabulary.
- Define domain separation and replay boundaries.
- Define canonical ids for MemorySignal, MemoryReceipt, RootflowTransition, RootfieldBundle, and verifier reports.
- Validate test vectors through verifier specs.
- Keep proof circuits, GPU proofs, verifier economics, and production crypto infrastructure out of scope.

### Phase 5: V0 Dashboard Data Model And Display Path

Status: active as fixture-backed local display work.

- Define app-facing entities for dashboard and explorer.
- Model observed, pending, finalized, verified, invalid, unresolved, unsupported, and reorged states.
- Render Rootfield, Rootflow transition, MemorySignal, MemoryReceipt, verifier report, and AgentMemoryView fixtures.
- Keep hosted production APIs and deployment out of scope until the local stack stabilizes.

### Phase 6: V0 Hardware POC

Status: planning and bounded research.

- Define FlowRouter v0 as research hardware.
- Document Meshtastic/LoRa control-message candidates.
- Explore enclosure concepts, NFC memory cartridge concepts, light-pipe indicators, and two-node demos as specs or prototypes only when scoped.
- Keep manufacturing, firmware production, RF certification work, and field deployment out of scope.

## Research Phases

### Phase 7: V0 Research Lab

Status: research-only.

- Define AI memory artifact taxonomy.
- Define no-value devnet/appchain research criteria.
- Compare Base settlement anchors and local devnet smoke-test requirements.
- Research bridge/security review requirements before any chain design.

### Phase 8: Later Gated Work

Status: blocked until explicit go/no-go decisions exist.

- Production L1 or appchain.
- Tokenomics or value-bearing systems.
- Mainnet deployment.
- Production Uniswap v4 hook deployment.
- Verifier networks, staking, slashing, or incentives.
- Hardware manufacturing or production decentralized internet claims.

## Merge Order Preference

1. Repo OS and review process changes.
2. Rootflow and Flow Memory specs, current state, roadmap, architecture, and decision records.
3. Contracts foundation hardening.
4. Crypto schema vocabulary and test-vector validation.
5. Indexer/verifier fixture, Rootflow transition, and report schema work.
6. Dashboard data model and fixture-backed display path.
7. Hardware POC specs.
8. Research lab documents.
