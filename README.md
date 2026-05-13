# FlowMemory

FlowMemory is a Base-native AI memory, neural-geometry, reliability, decentralized hardware, and future appchain/L1 research project.

This repository has completed the initial bootstrap and contracts-foundation passes. It contains project context, collaboration rules, planning documents, GitHub templates, a CI scaffold, worktree setup, placeholder work areas, and an initial FlowPulse/Rootfield contracts foundation. Do not treat the current repo as containing production product features yet.

## What FlowMemory Is Exploring

- Base and future Uniswap v4 hook integrations
- FlowPulse event schema v0 and future event expansion
- Rootflow and Rootfield state commitments
- AI memory and neural geometry research
- FlowRouter decentralized internet hardware
- Meshtastic and LoRa sidecar signaling
- 3D-printed hardware enclosures
- Dashboard, explorer, and hardware console applications
- Indexer, verifier, and worker services
- Cryptographic receipts, attestations, roots, and proofs
- Future FlowMemory appchain/L1 research

## Important Boundaries

- AI does not run on-chain.
- Storage is not free.
- Transaction hashes do not store arbitrary data.
- Uniswap v4 hooks cannot know `txHash` or `logIndex`.
- Indexers and verifiers derive `txHash` and `logIndex` after reading receipts and logs.
- Heavy AI, model, memory, and artifact data stays off-chain.
- On-chain state stores roots, receipts, commitments, attestations, proofs, and work state.
- `metadataURI` and `evidenceURI` values are emitted as on-chain log bytes and are not contract-enforced as short pointers.
- Meshtastic and LoRa are low-bandwidth control signaling paths, not normal internet bandwidth.

## Start Here

Every contributor and agent should read:

1. `AGENTS.md`
2. `docs/START_HERE.md`
3. `docs/FLOWMEMORY_HQ_CONTEXT.md`
4. `docs/CURRENT_STATE.md`
5. `docs/ROOTFLOW_V0.md`
6. `docs/FLOW_MEMORY_V0.md`
7. `docs/V0_LAUNCH_ACCEPTANCE.md`
8. `docs/DAILY_HQ_RUNBOOK.md` if operating HQ or coordinating agents

Then work only inside the assigned scope.

## HQ Operating System

FlowMemory is managed as a multi-agent program. The management layer is part of the repo and should be kept current before large subsystem work begins.

- `docs/ISSUE_BACKLOG.md`: maps issues into milestones, dependencies, and agent worktrees
- `docs/AGENT_PROMPTS.md`: copy-ready prompts for each worktree
- `docs/LAUNCH_CORE_AGENT_GOALS.md`: copy-ready Rootflow V0 and Flow Memory V0 launch-core goals
- `docs/PR_PROCESS.md`: branch, draft PR, review, merge, conflict, and issue-closing rules
- `docs/DAILY_HQ_RUNBOOK.md`: morning review, triage, agent launch, PR monitoring, merge order, and handoff
- `infra/scripts/status-report.ps1`: read-only local worktree, PR, and issue status report

Immediate major milestone: build the Rootflow V0 and Flow Memory V0 launch core. This means local contracts/tests, FlowPulse fixtures, Rootflow transitions, Flow Memory schemas, verifier reports, crypto fixtures, dashboard-readable state, and local smoke-test gates. It does not mean production deployment.

## What Not To Claim

- Do not claim FlowMemory has production contracts or deployment automation.
- Do not claim Uniswap v4 hook integration exists yet.
- Do not claim indexer, verifier, dashboard, explorer, hardware console, FlowRouter hardware, or Meshtastic integration exists yet.
- Do not claim cryptographic proof systems, tokenomics, or appchain/L1 implementation exists yet.
- Do not claim URI fields enforce off-chain storage. Current URI values are caller-supplied log data.

## Repository Map

- `apps/`: future dashboard, explorer, and hardware console applications
- `contracts/`: FlowPulse schema/interface, RootfieldRegistry foundation, and future on-chain protocol and hook contracts
- `crypto/`: future cryptographic receipt, proof, and attestation work
- `docs/`: project context, architecture, roadmap, security model, and decisions
- `hardware/`: future FlowRouter, LoRa, Meshtastic, and enclosure work
- `infra/scripts/`: worktree setup and future automation or repository maintenance scripts
- `inbox/`: staging area for imported prompts, notes, and unsorted context
- `research/`: future AI memory, neural geometry, and appchain/L1 research
- `services/`: future indexer, verifier, worker, and API services

## Implemented Foundation

- Repo operating system: `AGENTS.md`, start-here docs, current state, roadmap, architecture, security model, agent roles, and decision-record home
- GitHub issue and pull request templates
- Repository hygiene CI scaffold
- Worktree setup script
- `contracts/FlowPulse.sol`
- `contracts/RootfieldRegistry.sol`
- `contracts/FLOWPULSE_SCHEMA.md`
- `tests/RootfieldRegistry.t.sol`
- Initial Foundry tests for the Rootfield registry foundation
- Documented URI/log-data limitations for the current contract skeleton

## Still Conceptual

- Uniswap v4 hook integration
- Indexer and verifier services
- Complete Rootflow runtime implementation
- Complete Flow Memory runtime implementation
- FlowRouter hardware implementation
- Meshtastic integration
- Dashboard, explorer, and hardware console applications
- Cryptographic proof systems
- Appchain/L1 design and implementation

## Current Status

See `docs/CURRENT_STATE.md` for the latest repo state.
