# Roadmap

This roadmap is the project-management view of FlowMemory. Use GitHub issues for execution and `docs/DECISIONS/` for durable decisions.

Production L1, tokenomics, mainnet deployment, production Uniswap v4 hook deployment, hardware manufacturing, and full dashboard implementation are later gated work. They are not approved by this roadmap.

## Immediate Major Milestone: Rootflow And Flow Memory V0 Launch Core

Goal: make a local developer able to run the smallest FlowMemory loop without production deployment.

The launch-core V0 stack means:

- Contracts compile and tests run locally.
- FlowPulse fixtures can be produced or consumed deterministically.
- The V0 hook adapter can emit a swap-derived `SWAP_MEMORY_SIGNAL` FlowPulse for the launch fixture path.
- Rootflow transitions link FlowPulse observations, parent state, receipts, verifier reports, and new roots.
- Flow Memory objects expose MemorySignal, MemoryReceipt, RootfieldBundle, and AgentMemoryView shapes.
- MemorySignals and RootflowTransitions preserve explicit `IFlowPulse.FlowPulse` contract-event semantics while keeping receipt-only fields indexer-derived.
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

Status: implemented as a local/test foundation; hardening still active.

- Minimal Foundry config and contract tests exist.
- `FlowPulse`, `RootfieldRegistry`, hook-adapter scaffold, artifact/cursor/worker/verifier/work registries, receipt verifier, work receipt registry, verifier report registry, and scheduler skeletons exist.
- `forge test` currently runs 36 passing tests.
- FlowPulse v0 and Rootfield URI/log-data decisions are documented.
- Static-analysis runner, deployment boundary, and access-control review docs exist.
- Define status lifecycle, ownership/recovery, and namespace policy before expanding deployment scope.
- Keep dynamic fees, tokenomics, production deployment, and production hooks out of scope.

### Phase 2: V0 Local Stack

Status: implemented as fixture-first services plus generated launch-core state; production services still gated.

- Canonical FlowPulse observation identity is specified and implemented in crypto/services.
- Verifier statuses and report JSON schema exist for local fixture reports.
- Rootflow transition schema and parent/child state-linking behavior exist as generated local fixtures.
- Flow Memory schemas for MemorySignal, MemoryReceipt, RootfieldBundle, and AgentMemoryView exist under `schemas/flowmemory/`.
- Generated MemorySignal and RootflowTransition fixtures expose contract-event linkage through `contractEvent` and `contractEventRef`.
- Fixture-based parser and reorg-state tests exist in the indexer/verifier packages.
- Deterministic persistence exists for fixture state and the constrained Base Sepolia reader checkpoint.
- A Base Sepolia reader path exists for explicit RPC URLs and explicit FlowPulse contract addresses; it rejects non-Base-Sepolia chain ids.
- Base Sepolia deploy/read commands exist for the current V0 testnet contract set.
- Runtime schema validation and generated fixture drift checks exist for launch-core outputs.
- Local devnet smoke-test gates exist as a no-value Rust prototype, without mainnet or production deployment.

### Phase 3: V0 Review/Audit

Status: active.

- Define foundation PR review rules.
- Add security reporting guidance.
- Enforce claim guardrails in CI for README/docs/marketing surfaces.
- Keep Slither required for audit environments and available through `npm run contracts:hardening:slither`.
- Enforce allowed-folder and forbidden-folder boundaries.

## Mid-Term Phases

### Phase 4: V0 Crypto Schema Layer

Status: implemented for crypto V0 primitives and local Flow Memory object schemas.

- Receipt, attestation, commitment, root, and proof vocabulary exists in `crypto/` docs and helpers.
- Domain separation and replay boundaries exist for the V0 helper package.
- Canonical ids for MemorySignal, MemoryReceipt, RootflowTransition, RootfieldBundle, AgentMemoryView, and verifier reports exist in local V0 fixtures.
- Validate test vectors through verifier specs and keep cross-language checks passing.
- Keep proof circuits, GPU proofs, verifier economics, and production crypto infrastructure out of scope.

### Phase 5: V0 Dashboard Data Model And Display Path

Status: implemented as a generated fixture-backed local app.

- App-facing entities exist in `apps/dashboard`.
- Observed, pending, finalized, verified, failed, unresolved, unsupported, reorged, offline, and stale states are modeled for display.
- Dashboard renders local fixture views for overview, Flow Memory / Rootflow, FlowPulse stream, Rootfields, work receipts, verifier reports, devnet blocks, hardware nodes, alerts, and raw JSON.
- The Flow Memory / Rootflow view includes launch-demo summaries for contract event linkage, transition status counts, root bundle state, and agent memory warnings.
- The dashboard fixture is generated from services, local devnet, and hardware POC outputs by `npm run launch:v0`.
- Keep hosted production APIs and deployment out of scope until the local stack stabilizes.

### Phase 6: V0 Hardware POC

Status: bounded POC specs and simulator implemented; real hardware integration still future work.

- FlowRouter v0 is defined as research hardware.
- Meshtastic/LoRa control-message candidates are documented.
- Enclosure concepts, NFC memory cartridge concepts, light-pipe indicators, two-node demos, packet schemas, and simulator validation exist.
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

The initial merge sequence has completed for repo OS, contracts foundation, crypto foundation, indexer/verifier fixtures, dashboard V0, hardware POC, and local devnet prototype.

Next merge preference:

1. Base Sepolia reader soak tests against explicit testnet deployments.
2. Dashboard polish and explorer/hardware-console separation.
3. Static analysis follow-up findings triaged for any public testnet deployment.
5. Production-gated research only after V0 local acceptance stays green.
