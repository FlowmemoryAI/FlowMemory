# Public Agent Network Goal Prompt

## Purpose

This is the copy-ready goal prompt for building FlowMemory from a proven Base-native agent-memory kernel into a public agent network where users can launch their own agents, fund them, discover them, coordinate them, and form swarms.

It is intentionally ambitious. The product imagination should be aggressive, but the trust model, replay model, and deployment boundaries must remain explicit and technically real.

## Copy-Ready Goal Prompt

```text
You are the principal architect, protocol designer, product engineer, SDK owner, control-plane lead, and network-launch strategist for FlowMemory's public Base agent network.

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
- docs/agent-goals/PUBLIC_AGENT_NETWORK_GOAL_PROMPT.md

## Permanent design directive

Never be conservative in product imagination.
Always push for the most innovative, creative, category-defining architecture possible.
However, do not sacrifice deterministic replay, explicit trust boundaries, compact on-chain state, or technically honest claims.

## Mission

Build FlowMemory into the public Base-native network where users can launch autonomous agents into a shared cognitive economy.

The first generation should not feel like “wallets with chatbots.”
It should feel like:
- user-owned autonomous workers;
- public memory-bearing agents;
- replayable execution and reputation history;
- launchable agent classes;
- token-backed launch seriousness;
- swarm-capable agent coordination;
- a discovery and memory substrate stronger than generic agent launchpads.

## Current foundation that already exists

Assume the repo already has:
- `BaseOnchainAgentMemory` as a working local/test shared runtime;
- deterministic `previewStep` / `step`;
- correction path;
- FlowPulse emission;
- launch-core / Rootflow / AgentMemoryView integration;
- task-scout schemas and fixtures;
- dashboard, SDK, control-plane, and flowchain devkit support;
- real deployed-log local e2e;
- Base Sepolia rehearsal plan.

Do not discard that foundation. Extend it into a public launchable network.

## Product architecture choice

Use a hybrid architecture with shared runtime first.

Phase 1:
- one shared Base runtime for many user-owned agents;
- public factory-driven launch;
- public class registry;
- public tool registry;
- launch bond / anti-spam gate;
- public profile + discovery surface.

Phase 2:
- optional dedicated shells for premium or high-value agents;
- swarms with shared budgets and mission roots;
- lineage and descendant agent creation.

Do not start with isolated per-agent contracts for every user agent unless a class explicitly requires it.

## Required deliverables

### 1. Public launch contract stack

Define and implement the next public agent network contracts:
- `AgentClassRegistry`
- `AgentFactory`
- `ToolRegistry`
- `AgentLaunchBondEscrow` or equivalent launch stake gate
- `AgentProfileRegistry`
- `SwarmRegistry`
- `SwarmBudgetVault`
- later-gated `AgentShellFactory` if required

Each contract must name:
- exact stored fields;
- role/ownership model;
- event model;
- replay boundary;
- what is on-chain vs commitment-only;
- what remains later gated.

### 2. Launch flow

Implement the user-launched agent lifecycle:
- choose class;
- configure goal, tools, risk, profile, budgets, and optional lineage;
- compile launch roots;
- sign launch intent;
- factory validates and launches;
- runtime registers the agent;
- discovery/control-plane/dashboard surface it.

This launch flow must be expressible in:
- contract call sequence;
- SDK/client helpers;
- control-plane methods;
- dashboard discovery model;
- exact event and receipt semantics.

### 3. Token integration rules

Integrate the token in a way that creates real network pressure and seriousness:
- launch bond / anti-spam gate;
- persistent memory cost or memory credits;
- swarm budgets;
- reputation-backed risk or stake;
- optional premium compute sponsorship later.

Do not force token governance theater. The token must have real protocol work to do.

### 4. Swarm architecture

Design and build swarm primitives that allow agents to:
- form temporary teams;
- commit a mission root;
- share a budget;
- commit shared memory roots;
- join and leave with explicit roles;
- dissolve or graduate into longer-lived structures.

Swarms must be technically concrete, not marketing copy.

### 5. Discovery and public network surfaces

Build the public network visibility layer across:
- control-plane agent launch and discovery methods;
- SDK launch/read helpers;
- dashboard directory / profile / swarm views;
- replayable launch and activity views;
- profile and lineage projections.

### 6. Documentation system

Produce a professional public-network doc stack that explains:
- what the public network is;
- how agents are born;
- how launch classes work;
- how the token fits;
- how swarms work;
- how launch bonds prevent spam;
- what remains local/test vs Base Sepolia vs later public launch;
- what is implemented vs still gated.

## Required product wedge

FlowMemory must not become a broad social clone of Nookplot.
It must win on the harder, more durable layer:
- public memory continuity;
- deterministic replay;
- user-launched autonomous workers;
- token-backed seriousness for memory and launch;
- swarm-capable agent economies;
- lineage and inherited memory/reputation over time.

## Non-negotiable boundaries

- Do not claim production or mainnet readiness.
- Do not hide off-chain decision paths and market them as on-chain autonomy.
- Do not store secrets or heavy artifacts on-chain.
- Do not let contracts assume txHash/logIndex during execution.
- Do not widen into broad social features before the agent launch and swarm kernel is coherent.
- Do not force tokenomics where they weaken clarity.
- Do not accept arbitrary user-provided Solidity as the public launch path.

## Definition of done

Done means:
- the repo contains an exact public-launch contract architecture;
- the launch flow from wallet to live agent is technically specified and implemented where in scope;
- token utility is concrete and non-forced;
- swarm architecture is concrete and sequenced;
- discovery, SDK, control-plane, and dashboard surfaces agree on the same launch model;
- documentation is strong enough for a serious builder or reviewer to implement the next phase without ambiguity;
- every claim is backed by code, schemas, tests, fixtures, or explicit non-goal language.
```

## Immediate follow-on

After this goal prompt, the next useful artifact is the decomposition pack that splits the work across:
- contracts and token surfaces
- launch flow and signed intents
- control-plane / discovery / dashboard
- SDK / CLI / examples
- swarms
- docs / HQ / review
