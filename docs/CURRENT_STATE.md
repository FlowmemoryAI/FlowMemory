# Current State

Last updated: 2026-05-13

This file is the beginner-friendly source of truth for what exists in FlowMemory right now. It should stay factual, dated, and conservative. GitHub issues, pull requests, and merged files remain the final project record.

## Repo Phase

FlowMemory is in foundation hardening.

The bootstrap repository operating system, contracts V0 foundation, crypto V0 foundation, local indexer/verifier fixture package, dashboard V0, FlowRouter hardware POC, and local no-value devnet prototype have merged into `main`.

The launch-core V0 stack now has a single runnable local command that connects contract fixtures, local indexing/verifier outputs, crypto schema vocabulary, Rootflow transitions, Flow Memory objects, generated dashboard state, local no-value devnet output, and hardware POC output without production deployment.

Launch-critical direction: Rootflow V0 and Flow Memory V0 are the core of the next milestone. Rootflow defines memory-state transitions. Flow Memory defines the agent-facing memory objects derived from FlowPulse observations, receipts, verifier reports, and committed roots.

## Implemented In The Merged Repo

Repository operating system:

- `AGENTS.md` with shared agent instructions.
- `docs/START_HERE.md` with required reading order and local multi-agent worktree workflow.
- Source-of-truth docs for context, roadmap, architecture, security model, project charter, agent roles, and current state.
- `docs/DECISIONS/` for durable decision records.
- GitHub issue and pull request templates.
- Conservative repository hygiene CI.
- `infra/scripts/setup-worktrees.ps1` for local multi-agent worktrees under `E:\FlowMemory`.
- Placeholder work areas for `contracts/`, `services/`, `apps/`, `hardware/`, `research/`, `crypto/`, `infra/scripts/`, and `inbox/`.

Contracts foundation:

- `contracts/FlowPulse.sol` defines the FlowPulse v0 event interface and initial pulse type constants.
- `contracts/RootfieldRegistry.sol` registers Rootfield namespaces, accepts committed roots, and emits FlowPulse events.
- `contracts/FlowMemoryHookAdapter.sol` is a compileable V0 hook-adapter scaffold. It is not a production Uniswap v4 hook.
- `contracts/ArtifactRegistry.sol`, `CursorRegistry.sol`, `ReceiptVerifier.sol`, `WorkerRegistry.sol`, `VerifierRegistry.sol`, `WorkReceiptRegistry.sol`, `VerifierReportRegistry.sol`, and `WorkDebtScheduler.sol` provide local/test skeleton surfaces for commitments, cursors, work receipts, verifier reports, and work state.
- `contracts/FLOWPULSE_SCHEMA.md` documents event fields, receipt boundaries, and URI/log-data limitations.
- `tests/RootfieldRegistry.t.sol` and `tests/LiveV0Package.t.sol` contain 33 passing Foundry tests.
- `tests/README.md` documents the current test command.

Crypto foundation:

- `crypto/` contains runnable Keccak-based V0 hash helpers, typed domains, receipt/report/root/artifact/work helpers, attestation helpers, fixtures, and test vectors.
- Crypto tests currently pass with 13 Node tests, 21 vector validations, and a Python FlowPulse vector recompute.

Indexer/verifier local package:

- `services/shared/`, `services/indexer/`, and `services/verifier/` contain fixture-first local packages.
- The local services test suite currently has 24 passing tests.
- `npm run e2e` currently indexes 7 observations, writes 6 cursors, rejects 2 logs, tracks 1 duplicate, and produces 7 verifier reports.
- The verifier uses local fixture evidence only. It is not a production verifier network.

Dashboard V0:

- `apps/dashboard/` contains a Vite/React fixture-backed dashboard.
- It renders overview, Flow Memory / Rootflow, FlowPulse stream, Rootfields, work receipts, verifier reports, devnet blocks, hardware nodes, alerts, and raw JSON views.
- The dashboard uses the generated canonical fixture at `fixtures/dashboard/flowmemory-dashboard-v0.json`.
- Dashboard tests and production build pass after installing `apps/dashboard` dependencies.

Launch-core integration:

- `npm run launch:v0` runs the local end-to-end V0 flow.
- `fixtures/launch-core/flowmemory-launch-v0.json` contains generated MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, and RootflowTransition objects.
- `fixtures/launch-core/rootflow-transitions.json` contains concrete generated RootflowTransition output.
- `schemas/flowmemory/` contains canonical JSON schemas for MemorySignal, MemoryReceipt, RootflowTransition, RootfieldBundle, and AgentMemoryView.
- `services/flowmemory/src/status.ts` implements the explicit verifier-to-Flow-Memory status adapter: `valid` -> `verified`, `invalid` -> `failed`, `unresolved` -> `unresolved`, `unsupported` -> `unsupported`, `reorged` -> `reorged`.
- `.github/workflows/ci.yml` now includes area jobs for contracts, services/launch core, crypto, dashboard, devnet, and hardware.

Local no-value devnet prototype:

- `crates/flowmemory-devnet/` contains a Rust local devnet prototype.
- It models deterministic local transactions, blocks, state roots, and handoff output.
- It has 7 passing Rust tests.
- It is not a production L1, token system, sequencer, validator set, or bridge.

FlowRouter hardware POC:

- `hardware/` contains FlowRouter V0 POC docs, BOM/assembly/enclosure concepts, LoRa sidecar message inventory, NFC cartridge concepts, field-test notes, JSON packet schemas, and a simulator.
- The simulator validates `hardware/fixtures/flowrouter_sample_seed42.json`.
- Hardware is still a research POC, not manufactured or field-deployed product hardware.

Launch-core specifications:

- `docs/ROOTFLOW_V0.md` defines the Rootflow V0 transition model, status vocabulary, agent ownership, and launch acceptance.
- `docs/FLOW_MEMORY_V0.md` defines MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, work-lane vocabulary, and dashboard display expectations.
- `docs/V0_LAUNCH_ACCEPTANCE.md` maps the Rootflow and Flow Memory objective to concrete artifacts and evidence.
- `docs/DECISIONS/rootflow-v0.md` records the V0 decision and non-goal boundaries.
- `docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md` tracks evidence and missing work for the active launch-core goal.
- `docs/reviews/OPEN_PR_MERGE_READINESS.md` is now historical merge-readiness evidence for PRs that have merged.
- `docs/LAUNCH_CORE_AGENT_GOALS.md` provides copy-ready goals for the contracts, crypto, indexer/verifier, dashboard, and review worktrees.

## Conceptual Or Not Implemented Yet

- Production protocol deployment.
- Production ownership, upgrade, governance, fee, token, or incentive mechanics.
- Dynamic fees or tokenomics.
- Production Uniswap v4 hook deployment.
- Production Rootflow runtime implementation.
- Production Flow Memory runtime implementation.
- Hosted launch-core services.
- Rich JSON Schema runtime validation with a dedicated validator dependency.
- Production indexer or verifier service runtime.
- Production persistence layer, production live RPC reader, production APIs, or hosted services.
- Explorer or hardware console implementation.
- FlowRouter firmware, manufacturing, final enclosure work, or field deployment.
- Real Meshtastic or LoRa device integration.
- Cryptographic proof systems, GPU proofs, verifier networks, or verifier economics.
- Production appchain/L1 implementation, validator planning, sequencer planning, bridge deployment, or mainnet deployment.

## Active GitHub Work Shape

Issues #6 through #55 define the current foundation-hardening backlog. They are organized into program milestones in `docs/ISSUE_BACKLOG.md`.

Closed issue notes:

- #16 was closed as not planned because its scope was folded into other architecture/status issues.
- #39 was closed; future on-chain verifier adapter work should stay gated behind accepted verifier and crypto boundaries.

As of this update there are no open PRs in `FlowmemoryAI/FlowMemory`.

Recently merged PRs:

- #56 FlowRouter V0 POC hardware package.
- #57 Contracts V0 foundation.
- #58 Local FlowMemory devnet prototype.
- #59 FlowMemory HQ program manager OS.
- #60 Crypto V0 foundation.
- #61 Indexer/verifier V0 fixture package.
- #62 Dashboard V0.

## Active Local Work

Local worktrees may contain unmerged work. Unmerged files are not source of truth until reviewed and merged.

Use:

```powershell
cd E:\FlowMemory\flowmemory-main
.\infra\scripts\status-report.ps1
```

Before assigning agents, check for dirty worktrees and avoid overlapping folders.

## Active Technical Boundaries

- AI does not run on-chain.
- Storage is not free.
- Transaction hashes do not store arbitrary data.
- Uniswap v4 hooks cannot know `txHash` or `logIndex` during execution.
- Indexers and verifiers derive `txHash` and `logIndex` after receipts and logs exist.
- Heavy AI, model, memory, media, and artifact data stays off-chain.
- On-chain state stores only intentional roots, receipts, commitments, attestations, proofs, and work state.
- `RootfieldRegistry` is a skeleton/foundation contract, not a production protocol surface.
- `metadataURI` and `evidenceURI` are arbitrary caller-supplied strings emitted as log data.
- The current contract does not enforce URI length, content, format, resolvability, or short-pointer behavior.
- Meshtastic and LoRa are low-bandwidth control-signaling paths, not normal internet bandwidth.

## Current Operator Priorities

1. Make Rootflow V0 and Flow Memory V0 pass the launch acceptance matrix in `docs/V0_LAUNCH_ACCEPTANCE.md`.
2. Keep the generated launch-core command stable in CI.
3. Add richer schema validation before live services.
4. Finish contracts hardening without production deployment or token mechanics.
5. Keep dashboard work fixture-backed until a production API is explicitly scoped.
6. Keep chain/appchain work no-value and local until explicit gates are passed.

## Update Rule

Update this file whenever merged repository state changes in a way that affects new agents. Keep it concrete, dated, and conservative.
