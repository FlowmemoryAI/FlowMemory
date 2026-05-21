# FlowMemory

**FlowMemory is the accountability layer for autonomous agents.**

Agents are becoming economic actors: they take tasks, call tools, spend budgets, produce artifacts, and need a memory trail other systems can inspect. FlowMemory turns that work into replayable receipts, compact on-chain commitments, verifier reports, reputation state, and task-scoped recourse records.

The public repo is built around one core idea:

> **Agent work should leave a memory trail that can be priced, challenged, replayed, and reused.**

FlowMemory is not “AI memory” as vague storage. It is a protocol workbench for **Proof-of-Useful-Memory**: agent actions, task outcomes, evidence roots, execution receipts, and reputation signals that can move across applications.

## What Is In The Public Repo

FlowMemory currently ships a local/test implementation of the main protocol surfaces:

| Surface | What it does |
| --- | --- |
| **FlowPulse** | Event spine for protocol activity, task lifecycle events, memory updates, and reliability checkpoints. |
| **Rootflow / Rootfield** | State-transition and commitment layers for replayable agent memory. |
| **Flow Memory V0** | Generates MemorySignal, MemoryReceipt, RootflowTransition, RootfieldBundle, and AgentMemoryView objects from receipts and verifier reports. |
| **Base On-Chain Agent Memory** | Bounded agent runtime that previews deterministic next steps, commits compact memory deltas, and emits FlowPulse. |
| **Agent Bonds** | Bonded task acceptance, escrow, verifier confirmation, challenge/slash flows, signed recourse quotes, credit attestations, and reputation updates. |
| **Public Agent Network** | Local/test contracts for agent classes, tool sets, profiles, launch intents, memory fuel, lineage, receipts, and swarms. |
| **Indexer / Verifier / Control Plane** | Fixture-first services that reconstruct facts from logs, generate reports, expose local JSON-RPC methods, and power the dashboard/SDKs. |
| **Dashboard** | Vite/React public workbench for Flow Memory, Agent Bonds, canary reads, local devnet state, public agents, and swarm projections. |
| **FlowRouter research** | Hardware/resilience track for local connectivity, LoRa/Meshtastic sidecar signaling, and operator-facing hardware experiments. |

## Why It Matters

Today, most agent output is ephemeral: a transcript, a tool call, maybe a database row. FlowMemory makes agent work composable:

- **Memory becomes verifiable** through receipts, roots, and replayable state transitions.
- **Agent work becomes accountable** through bonded tasks, verifier reports, challenge windows, and slashing paths.
- **Reputation becomes machine-readable** through passports, execution receipts, score attestations, and public task history.
- **Compute and inference become traceable** through memory-attested work, not vague claims that a model “did something.”
- **Markets become possible** because tasks, recourse, evidence, and reliability have explicit objects and lifecycle states.

## Agent Bonds: The First Economic Wedge

Agent Bonds is the most concrete product surface in this repo.

It gives objective agent work a real lifecycle:

```text
requester opens task
  -> agent accepts with stake / capacity
  -> verifier checks objective result
  -> receipt updates reputation
  -> valid work settles
  -> invalid work can be challenged, slashed, and routed through capped recourse
```

Current Agent Bonds surfaces include:

- task-scoped escrow and settlement
- stake-gated agents and verifiers
- evidence-availability commitments
- independent verifier confirmation paths
- challenge bonds and slash accounting
- Passport / Envelope / Receipt primitives
- signed recourse-policy quote attestations
- credit-attestation registry
- USDC-style recourse pools with concentration caps, epoch loss caps, and withdrawal cooldowns
- requester quote/create SDK helpers for the API/data pilot lane
- public dashboard view at `/agent-bonds`

The public-safe claim is:

**FlowMemory provides bounded agent-work accountability with task-scoped, capital-backed recourse records.**

This is not described as insurance, a guarantee, or a finished public financial product.

## Public Agent Network

The public-agent network workstream shows how FlowMemory can launch agents with memory, fuel, tools, and lineage:

```text
registered class + approved tool set
  -> owner-signed launch intent
  -> shared BaseOnchainAgentMemory runtime registration
  -> launch bond + memory fuel account
  -> profile + lineage + receipt anchor
  -> optional swarm membership and budget lifecycle
```

Run the local/test contract and e2e checks:

```powershell
npm run public-agent-network:contracts
npm run public-agent-network:local-e2e
```

## Quickstart

Prerequisites:

- Node.js compatible with this repo’s TypeScript test runner
- npm
- Foundry (`forge`) for Solidity tests and local scripts
- Rust/Cargo if you run the full launch candidate path

Clone and install:

```powershell
git clone https://github.com/FlowmemoryAI/FlowMemory.git
cd FlowMemory
npm install
npm install --prefix apps/dashboard
```

Run the quickest public tester lane:

```powershell
npm run public:test:quick
```

Generate a paste-ready GitHub tester report:

```powershell
npm run public:test:report
```

Run the public hardening gate that checks docs, scripts, CI, and issue-template wiring:

```powershell
npm run public:hardening
```

Run the core public checks if you also have Foundry and dashboard dependencies:

```powershell
npm run public:test:contracts
npm run public:test:e2e
npm run public:test:dashboard
```

Run every public tester lane plus the hardening and claim guards:

```powershell
npm run public:test:all
```

Run the full local launch/readiness gate:

```powershell
npm run build:production
npm run flowmemory:agent-bonds:phase2
npm run flowmemory:agent-bonds:readiness
```

Run safety checks before publishing changes:

```powershell
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

The old Windows installer path has been removed from the public quickstart; it was for a separate chain-devnet track and is not needed to understand or test FlowMemory.

If you want to help test, start with `docs/PUBLIC_TESTER_GUIDE.md` and open a **Public Tester Report** issue with your exact commands and environment.

## Documentation Map

| Reader goal | Start here |
| --- | --- |
| Understand the repo boundary | `docs/PUBLIC_REPO_GUIDE.md`, `docs/CURRENT_STATE.md` |
| Understand Agent Bonds | `docs/AGENT_BONDS_PHASE2_ARCHITECTURE.md`, `docs/AGENT_BONDS_PUBLIC_LAUNCH_BOUNDARY.md`, `docs/AGENT_BONDS_UNDERWRITER_POOLS.md` |
| Understand public agents | `docs/PUBLIC_AGENT_NETWORK_RELEASE.md`, `docs/PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md` |
| Test what works locally | `docs/PUBLIC_TESTER_GUIDE.md` |
| Understand Base agent memory | `docs/base-onchain-agent-memory/README.md` |
| See open public gaps | `docs/PUBLIC_RELEASE_GAPS.md` |
| Review claim rules | `docs/MARKETING_CLAIMS_GUARDRAILS.md` |
| Contribute safely | `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md` |

## Repository Map

| Path | Purpose |
| --- | --- |
| `contracts/` | FlowPulse, Rootfield, Agent Bonds, Base agent-memory, public-agent, bridge, and swarm contracts. |
| `tests/` | Foundry tests for protocol, memory, Agent Bonds, public-agent, swarm, and bridge surfaces. |
| `services/flowmemory/` | Launch-core generation, Flow Memory objects, Agent Bonds helpers, public-agent helpers, and deterministic fixture builders. |
| `services/control-plane/` | Local JSON-RPC style API over generated state and deterministic fixtures. |
| `services/agent-memory-sdk/` | Agent-memory and Agent Bonds client helpers for fixture-backed and local control-plane flows. |
| `services/indexer/`, `services/verifier/` | Fixture-first log reconstruction and verifier-report generation. |
| `apps/dashboard/` | Public workbench and dashboard projection views. |
| `fixtures/` | Deterministic generated state used by services, tests, and dashboard. |
| `schemas/` | Canonical JSON schemas for Flow Memory, Rootflow, Base agent memory, Agent Bonds, and related objects. |
| `docs/` | Public guides, architecture, runbooks, reviews, decisions, and gap register. |
| `hardware/` | FlowRouter and LoRa/Meshtastic research materials. |

## What Not To Claim

FlowMemory is public and substantial, but public claims still need to match what is actually implemented.

Do not claim:

- broad real-value launch approval
- trustless arbitrary AI correctness
- guaranteed reimbursement
- insurance
- permanent artifact availability
- finished tokenomics
- deployed public verifier network
- deployed public appchain
- completed hardware product

## Current Status

FlowMemory is a public local/test protocol workbench with working contracts, services, dashboard fixtures, SDK helpers, public-agent flows, Agent Bonds recourse primitives, and reproducible verification gates.

The next external blockers for real value-bearing launch are owner inputs, live deployment addresses, operator evidence, and independent review/signoff. Repo-side public review and local experimentation are open now.