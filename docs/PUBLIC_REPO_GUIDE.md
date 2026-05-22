# Public Repository Guide

Status: public-reader guide for the current local/test repository release.

FlowMemory is a Base-native agent memory and accountability protocol workbench. It is public so builders, reviewers, and operators can inspect the agent-memory, Agent Bonds, public-agent, service, SDK, and dashboard surfaces; reproduce the local flows; and see the exact gaps that remain. Separate chain-devnet research also exists in this repository, but it is not the public-reader starting point.

## The Short Version

FlowMemory makes agent work explicit, replayable, and economically accountable without pretending heavy AI state belongs on-chain.

The repository currently contains:

- local/test Solidity contracts for FlowPulse, Rootfield, Base on-chain agent memory, Agent Bonds, and the public-agent network;
- fixture-first indexer, verifier, Flow Memory, control-plane, SDK, and dashboard packages;
- deterministic Rootflow and Flow Memory V0 fixtures;
- signed Agent Bonds quote attestations, recourse-policy fixtures, and requester quote/create SDK helpers;
- a public-agent launch and swarm stack with Foundry tests and a local e2e script;
- a developing mobile operator surface, with an Android Capacitor shell committed today and iOS documented as a product track that still needs an Xcode project;
- FlowRouter hardware/resilience research materials;
- public docs that describe what exists, what works locally, and what must be verified before broader value-bearing claims are allowed.

## Public Release Snapshot

| Area | Current public status | Evidence |
| --- | --- | --- |
| Public repo | Live and reader-oriented | `README.md`, `docs/PUBLIC_REPO_GUIDE.md` |
| Public test lanes | Reproducible locally | `npm run public:test:all` |
| Agent Bonds | Local/test and challengeable | `docs/AGENT_BONDS_PHASE2_ARCHITECTURE.md` |
| Mobile apps | Android shell committed, iOS documented as planned | `docs/MOBILE_APPS.md` |
| Production claims | Explicitly blocked until more evidence exists | `docs/PRODUCTION_READINESS_CHECKLIST.md` |

## How The Pieces Fit Together

```text
contracts emit compact events and store compact state
  -> indexer reads logs and derives receipt metadata
  -> verifier produces local/test reports
  -> Flow Memory generates MemorySignal, MemoryReceipt, RootflowTransition, RootfieldBundle, and AgentMemoryView objects
  -> control-plane exposes JSON-RPC style local APIs
  -> SDK and CLI wrap those APIs
  -> dashboard and mobile shells render the generated and projected state
```

The public-agent network adds this path:

```text
registered class + approved tool set
  -> public launch preview / intent roots
  -> owner-signed AgentFactory launch intent
  -> shared BaseOnchainAgentMemory runtime registration
  -> launch bond + memory fuel account
  -> profile + lineage + receipt anchor projection
  -> optional swarm membership, mission root, shared memory root, and budget lifecycle
```

## Start With These Documents

| Reader goal | Read this |
| --- | --- |
| Understand the repo boundary | `README.md`, `docs/CURRENT_STATE.md`, `docs/MARKETING_CLAIMS_GUARDRAILS.md` |
| Understand the public-agent release | `docs/PUBLIC_AGENT_NETWORK_RELEASE.md`, `docs/PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md` |
| Test what works locally | `docs/PUBLIC_TESTER_GUIDE.md`, `npm run public:test:all` |
| See exactly what is still missing | `docs/PUBLIC_RELEASE_GAPS.md` and GitHub issues #164-#168 plus #174 |
| Understand Base on-chain agent memory | `docs/base-onchain-agent-memory/README.md` |
| Understand Rootflow and Flow Memory V0 | `docs/ROOTFLOW_V0.md`, `docs/FLOW_MEMORY_V0.md`, `docs/V0_LAUNCH_ACCEPTANCE.md` |
| Understand mobile apps | `docs/MOBILE_APPS.md`, `apps/dashboard/WALLET_DISTRIBUTION.md` |
| Operate or contribute safely | `AGENTS.md`, `docs/START_HERE.md`, `CONTRIBUTING.md`, `SECURITY.md` |
| Check deployment and claim boundaries | `docs/PRODUCTION_READINESS_CHECKLIST.md`, `contracts/DEPLOYMENT_BOUNDARY.md`, `contracts/ACCESS_CONTROL_REVIEW.md` |

## Public Tester Commands

Start with the low-friction lane:

```powershell
npm run public:test:quick
```

Then add the lanes that match your local tools:

```powershell
npm run public:test:contracts
npm run public:test:e2e
npm run public:test:dashboard
npm run public:test:cli
```

The full public local pass is:

```powershell
npm run public:test:all
```

Generate a paste-ready public tester report:

```powershell
npm run public:test:report
```

Check the public docs/scripts/CI wiring without running every lane:

```powershell
npm run public:hardening
```

See `docs/PUBLIC_TESTER_GUIDE.md` for expected results, CLI/control-plane commands, dashboard review prompts, and the tester-report template.

## Verification Commands

Run the checks for the area you are inspecting. The broad public confidence path is:

```powershell
npm test
npm run build:production
npm run flowmemory:agent-bonds:phase2
npm run flowmemory:agent-bonds:readiness
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Some checks require local tools such as Foundry, Rust, dashboard dependencies, or optional audit tools. Live testnet commands require local, uncommitted environment values.

## Repository Map

| Path | Purpose |
| --- | --- |
| `contracts/` | Solidity contracts for FlowPulse, Rootfield, agent memory, Agent Bonds, bridge lockbox, public agents, and swarms. |
| `tests/` | Foundry tests for protocol, memory, agent-bond, public-agent, swarm, and bridge surfaces. |
| `services/shared/` | Shared TypeScript helpers for canonical JSON, hashes, hex, ABI helpers, FlowPulse decoding, and secret scanning. |
| `services/indexer/` | Fixture-first local indexer and reader scaffolds. |
| `services/verifier/` | Local/test verifier reports and status projection. |
| `services/flowmemory/` | Launch-core generation, public-agent helpers, Agent Bonds helpers, and deterministic fixture builders. |
| `services/control-plane/` | Local JSON-RPC style control-plane methods and smoke client. |
| `services/flowchain-sdk/` | Client and CLI wrappers for the separate chain-devnet research track; not required for the main public quickstart. |
| `services/agent-memory-sdk/` | Agent-memory client for fixture-backed and local control-plane flows. |
| `apps/dashboard/` | Vite/React fixture-backed dashboard, desktop shell, Android Capacitor shell, and future shared mobile UI. |
| `fixtures/` | Deterministic local/test outputs used by services and dashboard. |
| `schemas/` | JSON schemas for Flow Memory, Rootflow, Base agent memory, Agent Bonds, and related objects. |
| `docs/` | Source-of-truth architecture, runbooks, reviews, decisions, public release docs, and gap register. |
| `infra/scripts/` | Local gates, validation scripts, deployment planning, and safety checks. |
| `hardware/` | FlowRouter and LoRa/Meshtastic research materials. |

## Security And Trust Boundary

- Heavy AI, model, memory, media, and artifact data stays off-chain.
- Contracts store compact roots, commitments, receipts, attestations, counters, and intentionally bounded work state.
- Transaction hash and log index fields are indexer-derived after receipts/logs exist.
- Agents launch from registered supported classes; users do not upload arbitrary agent Solidity.
- Current verifier and dashboard surfaces are local/test or fixture-backed unless a specific document says otherwise.
- Live credentials, RPC URLs, deployer keys, API keys, webhooks, and mnemonics must stay out of Git.

## Open Public Gaps

The repo publishes remaining gaps instead of hiding them:

- #164 Base Sepolia public-agent deployment and readback evidence
- #165 keeper runtime automation and replay-safe lifecycle jobs
- #166 direct contract-backed public launch SDK
- #167 live dashboard discovery, fuel, bond, and swarm budget views
- #168 swarm-born agents and memory inheritance
- #174 mobile operator apps and iOS shell

A gap is closed only when code, docs, tests, and public-safe evidence are merged or linked through GitHub history.
