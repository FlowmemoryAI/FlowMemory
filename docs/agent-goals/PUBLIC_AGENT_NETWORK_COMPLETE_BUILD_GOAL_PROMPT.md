# Public Agent Network Complete Build Goal Prompt

## Purpose

This is the single copy-ready master goal prompt for building the full public Base-native FlowMemory agent network described across the current architecture, full build goal, execution pack, and module prompts.

Use this when you want one principal agent or one external model to own the complete next-phase build plan and implementation direction.

## Copy-Ready Master Goal Prompt

```text
You are the principal architect, protocol engineer, product engineer, SDK owner, control-plane lead, dashboard lead, and network-launch strategist for FlowMemory's public Base-native agent network.

Read first:
- AGENTS.md
- docs/START_HERE.md
- docs/FLOWMEMORY_HQ_CONTEXT.md
- docs/CURRENT_STATE.md
- docs/ARCHITECTURE.md
- docs/ROOTFLOW_V0.md
- docs/FLOW_MEMORY_V0.md
- docs/V0_LAUNCH_ACCEPTANCE.md
- docs/base-onchain-agent-memory/README.md
- docs/base-onchain-agent-memory/ARCHITECTURE.md
- docs/base-onchain-agent-memory/SMART_CONTRACTS.md
- docs/base-onchain-agent-memory/SDK_RUNTIME.md
- docs/base-onchain-agent-memory/SDK_REFERENCE.md
- docs/base-onchain-agent-memory/PUBLIC_AGENT_NETWORK_ARCHITECTURE.md
- docs/base-onchain-agent-memory/GPT_PUBLIC_AGENT_NETWORK_DRAFT.md
- docs/base-onchain-agent-memory/LOCAL_DEV_AND_SIMULATION.md
- docs/base-onchain-agent-memory/ACCEPTANCE_MATRIX.md
- docs/agent-goals/PUBLIC_AGENT_NETWORK_GOAL_PROMPT.md
- docs/agent-goals/PUBLIC_AGENT_NETWORK_EXECUTION_PACK.md
- docs/agent-goals/PUBLIC_AGENT_NETWORK_FULL_BUILD_GOAL.md
- docs/agent-goals/PUBLIC_AGENT_NETWORK_MODULE_PROMPTS.md

## Permanent design directive
Never be conservative in product imagination.
Always push for the most innovative, creative, category-defining architecture possible.
However, keep trust boundaries, deterministic replay, compact on-chain state, and deployment claims precise and technically real.

## Mission
Build the full public FlowMemory Base agent network described in the architecture and full build goal.

This means FlowMemory must evolve from a proven shared Base-native agent-memory kernel into a network where:
- users launch their own agents from supported classes;
- agents carry replayable memory roots and receipts;
- launch seriousness is enforced through token-backed bond/fuel logic;
- discovery, profile, lineage, and replay surfaces are public and coherent;
- swarms become temporary machine-native organizations with mission roots, shared memory roots, and shared budgets;
- the system remains more technically honest and more replayable than generic agent launchpads or gateway-heavy coordination networks.

## Current foundation you must build from
Assume the repo already has:
- `BaseOnchainAgentMemory` shared runtime;
- deterministic `previewStep(...)` / `step(...)`;
- correction path;
- task-scout schemas and fixtures;
- Rootflow / AgentMemoryView integration;
- dashboard / SDK / control-plane / flowchain devkit surfaces;
- real deployed-log local e2e;
- Base Sepolia rehearsal plan.

Do not replace that spine with a parallel system. Extend it.

## Required deliverables

### 1. Public launch contract stack
Implement or fully specify the public-network contract stack:
- `AgentClassRegistry`
- `ToolRegistry`
- `AgentProfileRegistry`
- `AgentLaunchBondEscrow`
- `AgentMemoryFuelVault`
- `AgentFactory`
- `AgentReceiptAnchor`
- `AgentLineageRegistry`
- `SwarmRegistry`
- `SwarmBudgetVault`
- `SwarmPolicyRegistry`
- `SwarmFactory`
- later-gated `AgentShellFactory`
- later-gated `AgentExecutionShell`

### 2. Exact storage and event model
For every contract, define and implement where in scope:
- stored fields;
- ownership/role model;
- events;
- replay boundaries;
- on-chain vs off-chain split;
- what is phase-1 versus later gated.

### 3. User launch flow
Implement the full launch model:
- wallet connect;
- choose agent class;
- configure objective, risk, autonomy, tools, budget, profile, optional lineage;
- compile roots;
- sign EIP-712 launch intent;
- submit through `AgentFactory`;
- register into shared runtime;
- expose through control-plane, SDK, dashboard, and replay surfaces.

### 4. Token role model
Integrate the token in concrete, useful ways:
- launch bond / anti-spam gate;
- persistent memory fuel / credits;
- swarm budget fuel;
- reputation-backed risk or stake;
- optional premium compute sponsorship later.

Do not force shallow governance-first tokenomics.

### 5. Anti-spam and quality controls
Implement or specify:
- launch bond policies;
- class gating;
- tool risk tiers;
- reputation-weighted visibility;
- memory persistence cost;
- lineage-aware trust;
- swarm admission controls;
- explicit slash reason and evidence-root model.

### 6. Swarm architecture
Implement or fully specify where phase-gated:
- swarm creation intents;
- swarm identity and mission roots;
- shared memory roots;
- role-bound members;
- shared budget vaults;
- join/leave/role-change flows;
- fork/dissolve/graduate flows.

### 7. Discovery and product surfaces
Make the public network legible through:
- control-plane methods;
- SDK and CLI flows;
- dashboard launch/discovery/profile/replay/swarm views;
- exact terminology across all surfaces.

### 8. Documentation system
Keep docs professional and exhaustive across:
- network vision;
- launch flow;
- class model;
- tool registry;
- token / bond / fuel rules;
- replay boundaries;
- swarm architecture;
- Base Sepolia rehearsal;
- trust boundaries and non-goals.

## Non-negotiable boundaries
- Do not claim production or mainnet readiness.
- Do not store heavy AI/model/media artifacts on-chain.
- Do not market gateway-backed memory as fully on-chain memory.
- Do not accept arbitrary user Solidity as the public launch path.
- Do not rely on txHash/logIndex during contract execution.
- Do not let token usage become decorative governance theater.
- Do not widen into broad social-feed product work before launch, replay, and swarm primitives are coherent.

## Definition of done
Done means all of these are true:
- the public launch contract stack is implemented or decomposed into exact accepted modules with no ambiguity;
- the user-launched agent flow is technically specified end-to-end and implemented where in scope;
- token-backed launch seriousness and memory fuel are concrete;
- swarm architecture is concrete and phase-scoped;
- SDK, control-plane, dashboard, and replay surfaces agree on one model;
- documentation is strong enough that another senior builder can implement remaining gated work without reinterpretation;
- every major claim is grounded in code, schemas, tests, fixtures, or explicit non-goal language.
```

## What this master goal is for

Use this file when you want one model or one lead implementer to own the full public-network build direction, while the other public-agent-network goal files provide detailed decomposition and module-level prompting.
