# FlowMemory

FlowMemory is a Base-native AI memory, neural-geometry, reliability, decentralized hardware, and future appchain/L1 research project.

This repository contains the FlowMemory V0 foundation: project operating docs, local/test contracts, fixture-first services, Rootflow and Flow Memory launch-core generation, a fixture-backed dashboard, crypto helpers, a local no-value devnet prototype, and FlowRouter hardware POC materials. Do not treat the current repo as containing production product features yet.

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

For a second computer or a non-technical local test, use the beginner Windows
installer. It installs missing tools, clones the repo, installs dependencies,
runs the local setup, and opens the local control plane and dashboard:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command '$p=Join-Path $env:TEMP "INSTALL_FLOWCHAIN_WINDOWS.ps1"; Invoke-WebRequest "https://raw.githubusercontent.com/FlowmemoryAI/FlowMemory/main/INSTALL_FLOWCHAIN_WINDOWS.ps1" -OutFile $p; & powershell -NoProfile -ExecutionPolicy Bypass -File $p'
```

Detailed guide: `docs/EASY_SECOND_COMPUTER_SETUP.md`.

Every contributor and agent should read:

1. `AGENTS.md`
2. `docs/START_HERE.md`
3. `docs/FLOWMEMORY_HQ_CONTEXT.md`
4. `docs/CURRENT_STATE.md`
5. `docs/ROOTFLOW_V0.md`
6. `docs/FLOW_MEMORY_V0.md`
7. `docs/V0_LAUNCH_ACCEPTANCE.md`
8. `docs/PRODUCTION_READINESS_CHECKLIST.md`
9. `docs/MARKETING_CLAIMS_GUARDRAILS.md`
10. `docs/DAILY_HQ_RUNBOOK.md` if operating HQ or coordinating agents

Then work only inside the assigned scope.

## HQ Operating System

FlowMemory is managed as a multi-agent program. The management layer is part of the repo and should be kept current before large subsystem work begins.

- `docs/ISSUE_BACKLOG.md`: maps issues into milestones, dependencies, and agent worktrees
- `docs/AGENT_PROMPTS.md`: copy-ready prompts for each worktree
- `docs/LAUNCH_CORE_AGENT_GOALS.md`: copy-ready Rootflow V0 and Flow Memory V0 launch-core goals
- `docs/reviews/OPEN_PR_MERGE_READINESS.md`: historical merge-readiness evidence for the merged V0 foundation PRs
- `docs/PR_PROCESS.md`: branch, draft PR, review, merge, conflict, and issue-closing rules
- `docs/DAILY_HQ_RUNBOOK.md`: morning review, triage, agent launch, PR monitoring, merge order, and handoff
- `docs/PRODUCTION_READINESS_CHECKLIST.md`: blocking checklist before any production language is allowed
- `docs/MARKETING_CLAIMS_GUARDRAILS.md`: allowed and blocked launch claims for docs and marketing
- `infra/scripts/status-report.ps1`: read-only local worktree, PR, and issue status report

Immediate major milestone: keep the Rootflow V0 and Flow Memory V0 launch core green while packaging the FlowChain private/local L1 testnet path for second-computer validation. This means local contracts/tests, FlowPulse fixtures, Uniswap swap-derived memory-signal fixtures, Rootflow transitions, Flow Memory schemas, verifier reports, crypto fixtures, dashboard-readable state, Base Sepolia testnet read/deploy commands, Windows-first wrapper scripts, and local smoke-test gates. It does not mean production deployment.

Run the local launch-core path:

```powershell
npm run launch:v0
```

This regenerates local/test Rootflow and Flow Memory V0 fixtures, including `fixtures/launch-core/flowmemory-launch-v0.json`, `fixtures/launch-core/rootflow-transitions.json`, and the dashboard fixture at `fixtures/dashboard/flowmemory-dashboard-v0.json`.

Run the stricter local launch-candidate gate:

```powershell
npm run launch:candidate
```

That command runs contract hardening, the launch flow, runtime schema validation, fixture drift checks, and claim guardrails.

Run the current FlowChain private/local wrapper path:

```powershell
npm run flowchain:prereq
npm run flowchain:init
npm run flowchain:start
npm run flowchain:demo
npm run flowchain:export
```

Run the merged-surface smoke path when Foundry, Python, dashboard dependencies,
and crypto dependencies are installed:

```powershell
npm install --prefix apps/dashboard
npm install --prefix crypto
npm run flowchain:smoke
```

Run the existing dashboard as the local workbench:

```powershell
npm run workbench:dev
```

Build the dashboard after regenerating launch data:

```powershell
npm run build:production
```

Base Sepolia testnet commands require local environment values from `.env.example`:

```powershell
npm run deploy:base-sepolia
npm run deploy:base-sepolia:broadcast
npm run read:base-sepolia -- --rpc-url <base-sepolia-rpc-url> --address <flowpulse-contract> --from-block <n> --to-block <n>
```

## What Not To Claim

- Do not claim FlowMemory has production contracts or a mainnet deployment.
- Do not claim FlowMemory is production-ready or mainnet-ready.
- Do not claim the current hook adapter is a production Uniswap v4 hook.
- Do not claim explorer, hardware console, production FlowRouter hardware, or Meshtastic integration exists yet.
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
- `schemas/flowmemory/`: canonical Flow Memory and Rootflow JSON schemas

## Implemented Foundation

- Repo operating system: `AGENTS.md`, start-here docs, current state, roadmap, architecture, security model, agent roles, and decision-record home
- GitHub issue and pull request templates
- Repository hygiene CI scaffold
- Worktree setup script
- `contracts/FlowPulse.sol`
- `contracts/RootfieldRegistry.sol`
- contract skeletons for artifacts, cursors, workers, verifiers, receipts, verifier reports, hook adapter, and work scheduling
- contracts hardening docs and static-analysis runner
- `contracts/FLOWPULSE_SCHEMA.md`
- `tests/RootfieldRegistry.t.sol`
- Foundry tests for the Rootfield registry foundation and live V0 contract package
- fixture-first indexer/verifier packages and local launch-core generation
- Base Sepolia reader path with explicit RPC URL and durable checkpoint output
- Base Sepolia deployment runner for the current V0 testnet contract set
- FlowMemoryHookAdapter emits a `SWAP_MEMORY_SIGNAL` FlowPulse for the swap-memory fixture path
- Flow Memory V0 schemas and generated Rootflow transition fixtures
- runtime schema validation and generated fixture drift checks for launch-core outputs
- fixture-backed dashboard V0
- crypto helper package and test vectors
- local no-value devnet prototype
- FlowRouter hardware POC docs, schemas, and simulator fixture
- Documented URI/log-data limitations for the current contract skeleton

## Still Conceptual

- Production Uniswap v4 hook integration
- Production indexer and verifier services
- Production Rootflow runtime implementation
- Production Flow Memory runtime implementation
- FlowRouter hardware implementation
- Meshtastic integration
- Explorer and hardware console applications
- Cryptographic proof systems
- Appchain/L1 design and implementation

## Current Status

See `docs/CURRENT_STATE.md` for the latest repo state.
