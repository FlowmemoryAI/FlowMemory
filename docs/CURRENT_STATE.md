# Current State

Last updated: 2026-05-13

This file is the beginner-friendly source of truth for what exists in FlowMemory right now. It should stay factual, dated, and conservative. GitHub issues, pull requests, and merged files remain the final project record.

## Repo Phase

FlowMemory is in foundation hardening.

The bootstrap repository operating system and first contracts foundation have merged. The next major target is a runnable local V0 stack that connects contract fixtures, local indexing/verifier specs or fixtures, crypto schema vocabulary, and operator-facing data models without production deployment.

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
- `contracts/FLOWPULSE_SCHEMA.md` documents event fields, receipt boundaries, and URI/log-data limitations.
- `tests/RootfieldRegistry.t.sol` contains initial Foundry tests.
- `tests/README.md` documents the current test command.

Launch-core specifications:

- `docs/ROOTFLOW_V0.md` defines the Rootflow V0 transition model, status vocabulary, agent ownership, and launch acceptance.
- `docs/FLOW_MEMORY_V0.md` defines MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, work-lane vocabulary, and dashboard display expectations.
- `docs/V0_LAUNCH_ACCEPTANCE.md` maps the Rootflow and Flow Memory objective to concrete artifacts and evidence.
- `docs/DECISIONS/rootflow-v0.md` records the V0 decision and non-goal boundaries.
- `docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md` tracks evidence and missing work for the active launch-core goal.
- `docs/LAUNCH_CORE_AGENT_GOALS.md` provides copy-ready goals for the contracts, crypto, indexer/verifier, dashboard, and review worktrees.

## Conceptual Or Not Implemented Yet

- Production protocol deployment.
- Production ownership, upgrade, governance, fee, token, or incentive mechanics.
- Dynamic fees or tokenomics.
- Production Uniswap v4 hook deployment.
- Complete Rootflow runtime implementation.
- Complete Flow Memory runtime implementation.
- Canonical JSON schema package for Rootflow and Flow Memory objects.
- End-to-end fixture-backed Rootflow acceptance run.
- Completed launch-core acceptance audit.
- Indexer or verifier service runtime.
- Persistence layer, live RPC reader, production APIs, or hosted services.
- Dashboard, explorer, or hardware console implementation.
- FlowRouter hardware implementation, firmware, manufacturing, final enclosure work, or field deployment.
- Meshtastic or LoRa integration.
- Cryptographic proof systems, GPU proofs, verifier networks, or verifier economics.
- Appchain/L1 implementation, validator planning, sequencer planning, bridge deployment, or mainnet deployment.

## Active GitHub Work Shape

Issues #6 through #55 define the current foundation-hardening backlog. They are organized into program milestones in `docs/ISSUE_BACKLOG.md`.

Closed issue notes:

- #16 was closed as not planned because its scope was folded into other architecture/status issues.
- #39 was closed; future on-chain verifier adapter work should stay gated behind accepted verifier and crypto boundaries.

Open PRs should be treated as review candidates only after their changed files match the issue's allowed folders and forbidden folders.

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
2. Finish contracts foundation hardening without production deployment or token mechanics.
3. Build deterministic local fixtures for FlowPulse, receipts, Rootflow transitions, verifier reports, and dashboard state.
4. Define canonical crypto and JSON schema vocabulary before proof systems or verifier economics.
5. Keep dashboard work fixture-backed until indexer/verifier outputs stabilize.
6. Keep chain/appchain work no-value and local until explicit gates are passed.

## Update Rule

Update this file whenever merged repository state changes in a way that affects new agents. Keep it concrete, dated, and conservative.
