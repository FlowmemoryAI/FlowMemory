# Roadmap

This roadmap is the project-management view of FlowMemory. Use GitHub issues for execution and `docs/DECISIONS/` for durable decisions.

No production L1, tokenomics, mainnet deployment, production Uniswap v4 hook
deployment, hardware manufacturing, or production bridge work is approved by
this roadmap; those areas remain later gated work.

## Immediate Major Milestone: FlowChain Private/Local Testnet Package

Goal: make a clean second computer able to run the FlowChain private/local L1
testnet package for second-computer validation, building on the existing V0
launch-core, local devnet, contracts spine, crypto package, fixture
indexer/verifier, dashboard, hardware simulator, and research gates.

The private/local package must preserve the launch-core V0 stack and add one
obvious second-computer path for:

- prerequisite checks and install commands;
- local operator key generation or import guidance;
- private/local genesis initialization;
- single-node local runtime start;
- local runtime stop/reset behavior;
- deterministic block and state-root production;
- native object transactions for agents, models, receipts, artifacts, verifier reports, memory cells, challenges, and finality;
- local control-plane API queries;
- local workbench inspection through the existing dashboard surface;
- export/import or snapshot bundles;
- a full deterministic smoke command.

The required source-of-truth planning docs are:

- `docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md`
- `docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md`
- `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md`
- `docs/FLOWCHAIN_AGENT_INTEGRATION_MAP.md`

Completion gate: the milestone is not accepted until `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md`
marks the private/local package path implemented and records the exact commands,
generated outputs, deterministic replay evidence, control-plane query evidence,
workbench evidence, and `git diff --check` result. The HQ wrapper command layer
now exists, but the native object lifecycle, long-running runtime behavior,
control-plane coverage, and workbench entity coverage still have to land behind
those wrappers.

Non-goals:

- No tokenomics.
- No public validator onboarding.
- No production mainnet or production L1 claim.
- No production bridge.
- No production hook deployment.
- No hardware manufacturing.
- No audited-cryptography claim.
- No hosted production dashboard or production API.

Rootflow V0 and Flow Memory V0 remain launch-critical baseline requirements.
The private/local testnet milestone is not allowed to fork or duplicate those
surfaces.

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
- Deterministic persistence exists for fixture state, the constrained Base Sepolia reader checkpoint, and the guarded Base mainnet canary checkpoint.
- A Base Sepolia reader path exists for explicit RPC URLs and explicit FlowPulse contract addresses; it rejects non-Base-Sepolia chain ids.
- A guarded Base mainnet canary reader exists for explicit RPC URLs, explicit known canary addresses, and small explicit block ranges; it rejects non-Base-mainnet chain ids and marks output as canary-only.
- Base Sepolia deploy/read commands exist for the current V0 testnet contract set.
- A Base mainnet V0 canary deployment has been performed for testing only and is documented under `docs/DEPLOYMENTS/`.
- Runtime schema validation and generated fixture drift checks exist for launch-core outputs.
- Local devnet smoke-test gates exist as a no-value Rust prototype, without mainnet or production deployment.

### Phase 3: FlowChain Private/Local Testnet Package

Status: active packaging and next-wave build coordination. The Windows-first
root wrapper layer exists for current merged surfaces; subsystem completion is
still required for the full private/local object lifecycle.

- Extend the existing Rust devnet into the single private/local runtime surface.
- Extend the existing service packages into one local control-plane API.
- Extend the existing crypto package with object IDs, envelopes, schemas, and vectors for private testnet objects.
- Extend the existing dashboard into the local workbench/explorer.
- Keep hardware signals optional and fixture-backed.
- Keep contracts as optional settlement/event spine, not the core private runtime.
- Keep Windows-first second-computer setup, scripts, command aliases, smoke tests, and troubleshooting current as subsystem commands land.
- Keep all production mainnet, tokenomics, public validator, audited-cryptography, and bridge claims blocked.

### Phase 4: V0 Review/Audit

Status: active.

- Define foundation PR review rules.
- Add security reporting guidance.
- Enforce claim guardrails in CI for README/docs/marketing surfaces.
- Keep Slither required for audit environments and available through `npm run contracts:hardening:slither`.
- Enforce allowed-folder and forbidden-folder boundaries.

## Mid-Term Phases

### Phase 5: V0 Crypto Schema Layer

Status: implemented for crypto V0 primitives and local Flow Memory object schemas.

- Receipt, attestation, commitment, root, and proof vocabulary exists in `crypto/` docs and helpers.
- Domain separation and replay boundaries exist for the V0 helper package.
- Canonical ids for MemorySignal, MemoryReceipt, RootflowTransition, RootfieldBundle, AgentMemoryView, and verifier reports exist in local V0 fixtures.
- Validate test vectors through verifier specs and keep cross-language checks passing.
- Keep proof circuits, GPU proofs, verifier economics, and production crypto infrastructure out of scope.

### Phase 6: V0 Dashboard Data Model And Display Path

Status: implemented as a generated fixture-backed local app.

- App-facing entities exist in `apps/dashboard`.
- Observed, pending, finalized, verified, failed, unresolved, unsupported, reorged, offline, and stale states are modeled for display.
- Dashboard renders local fixture views for overview, Flow Memory / Rootflow, FlowPulse stream, Rootfields, work receipts, verifier reports, devnet blocks, hardware nodes, alerts, and raw JSON.
- The Flow Memory / Rootflow view includes launch-demo summaries for contract event linkage, transition status counts, root bundle state, and agent memory warnings.
- The dashboard fixture is generated from services, local devnet, and hardware POC outputs by `npm run launch:v0`.
- Keep hosted production APIs and deployment out of scope until the local stack stabilizes.

### Phase 7: V0 Hardware POC

Status: bounded POC specs and simulator implemented; real hardware integration still future work.

- FlowRouter v0 is defined as research hardware.
- Meshtastic/LoRa control-message candidates are documented.
- Enclosure concepts, NFC memory cartridge concepts, light-pipe indicators, two-node demos, packet schemas, and simulator validation exist.
- Keep manufacturing, firmware production, RF certification work, and field deployment out of scope.

## Research Phases

### Phase 8: V0 Research Lab

Status: research-only.

- Define AI memory artifact taxonomy.
- Define no-value devnet/appchain research criteria.
- Compare Base settlement anchors and local devnet smoke-test requirements.
- Research bridge/security review requirements before any chain design.

### Phase 9: Later Gated Work

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

1. HQ private/local testnet acceptance and setup docs.
2. Chain/devnet private testnet runtime extension.
3. Crypto object identity, envelope, and vector extension for the same object set.
4. Control-plane API over existing fixture/devnet outputs.
5. Dashboard/workbench extension of the existing app.
6. Optional hardware signal fixtures after API/object labels are stable.
7. Contracts settlement-spine alignment without moving runtime into Solidity.
8. Refresh packaging scripts and root command aliases whenever subsystem command semantics change.
9. Canary ingestion and Base Sepolia follow-ups, still gated from production claims.
