# Base On-Chain Agent Memory Goal Prompt

## Purpose

This is the copy-ready goal prompt for building FlowMemory into a Base-native agent memory/runtime system with documentation and product depth at or above the level of Nookplot, while staying sharper, more rigorous, and more truly chain-native in the memory core.

Use this prompt when assigning the full workstream to a principal Codex agent or when decomposing the work into specialized worktree goals.

## Copy-Ready Goal Prompt

```text
You are the principal architect, product engineer, protocol designer, SDK owner, and documentation lead for FlowMemory's Base-native agent memory platform.

Read first:
- AGENTS.md
- docs/START_HERE.md
- docs/FLOWMEMORY_HQ_CONTEXT.md
- docs/CURRENT_STATE.md
- docs/ROADMAP.md
- docs/ARCHITECTURE.md
- docs/ISSUE_BACKLOG.md
- docs/ROOTFLOW_V0.md
- docs/FLOW_MEMORY_V0.md
- docs/V0_LAUNCH_ACCEPTANCE.md
- docs/agent-goals/BASE_ONCHAIN_AGENT_MEMORY_GOAL_PROMPT.md
- inbox/unsorted/2026-05-21-onchain-ai-agents-with-onchain-memory.md
- inbox/unsorted/2026-05-21-nookplot-agent-coordination-research.md
- inbox/unsorted/2026-05-21-quill-for-onchain-agent-memory.md

## Mission

Build FlowMemory as the memory/runtime kernel for serious Base agents.

This is not a broad clone of Nookplot. Nookplot already covers coordination breadth: wallet identity, reputation, messaging, marketplace, bounties, MCP access, and gateway-backed agent operations.

FlowMemory must be better at the narrower, harder, more defensible thing:
- contract-resident or root-committed agent memory;
- deterministic replayable agent state transitions;
- `eth_call` previewable next-step execution;
- compact on-chain hot memory plus append-only cold memory pages;
- verifier-scoped memory admission and challenge/correction history;
- Rootflow/FlowPulse/AgentMemoryView as the canonical memory spine.

## Product Thesis

The product is:
- Base-native autonomous agents with chain-side memory;
- public memory cells, memory roots, and memory deltas;
- deterministic agent kernels with previewable steps;
- replayable receipts and memory transitions;
- professional developer surfaces that make the system usable: contracts, SDK, docs, home page, overview, architecture, examples, and operator/developer runbooks.

The product is not:
- a generic social network for agents;
- a tokenomics experiment;
- a vague chain-agent marketing site without a reproducible state machine;
- a gateway-first memory product that only anchors hashes after the fact.

## Required Standard

Build this to a level that is at least as comprehensive and professional as Nookplot's public architecture and docs, but more rigorous in scope control and more honest in trust boundaries.

Everything must be built out professionally and consistently across:
- home;
- overview;
- architecture;
- smart contracts;
- SDK;
- docs;
- examples;
- schemas;
- tests;
- verification notes.

No placeholders. No TODO docs pretending to be finished. No marketing claims that code and tests do not support.

## Required Deliverables

### 1. Home

Produce a first-class Home surface that explains, with high-end professional clarity:
- what FlowMemory is;
- why Base is the right chain;
- why this is different from Nookplot and generic agent frameworks;
- what “Base-native agents with chain-side memory” actually means;
- the core loop: observe -> recall -> decide -> act -> write memory -> emit receipt -> replay;
- what is on-chain vs off-chain;
- why deterministic replay matters.

At minimum this must exist in the repo as:
- root `README.md` aligned with the real implementation;
- docs home/index content if a docs app/site exists;
- no contradictions with architecture or current-state docs.

### 2. Overview

Produce an Overview that gives a clean, executive and technical summary of:
- protocol purpose;
- problem statement;
- core primitives;
- architecture layers;
- what exists in v0 / MVP / later phases;
- exact boundaries on privacy, trust, and execution.

### 3. Architecture

Produce a full architecture package that is deeper than Nookplot's architecture page and names:
- system layers;
- on-chain memory model;
- hot/cold memory split;
- agent kernel model;
- preview/commit flow;
- Rootflow transition lifecycle;
- verifier/replay path;
- tool/action routing;
- off-chain evidence/commitment path;
- Base-native infra choices;
- trust boundaries;
- failure modes;
- upgrade boundaries;
- data flow diagrams.

### 4. Smart Contracts

Specify and build the smart-contract layer needed for the first serious Base-native on-chain agent/memory path.

At minimum define, and implement if in scope, the contract surfaces for:
- agent identity/account registry;
- memory cell storage or root commitments;
- deterministic agent kernel or step router;
- tool/action router with allowlists and caps;
- FlowPulse emission for memory/action transitions;
- verifier admission / report linkage;
- challenge/correction/finality semantics when memory is disputed.

The contracts must preserve these truths:
- compact intentional state only on-chain;
- no raw heavy prompts/transcripts/embeddings/model outputs on-chain by default;
- contracts do not know final `txHash` or `logIndex` during execution;
- hot memory must stay bounded;
- every state transition must be replayable from public state and receipts.

### 5. SDK

Produce a professional SDK surface that is not an afterthought.

It must explain and, if in scope, implement:
- agent registration/bootstrap;
- memory read/write/query helpers;
- `previewStep` / `step` flow;
- contract bindings;
- event/receipt decoding;
- verifier/report reads;
- memory replay helpers;
- example integrations;
- clear distinction between read-only simulation and committed mutation.

The SDK should make the protocol legible to serious developers and agent builders.

### 6. Documentation System

Build all core documentation needed for the product to stand on its own.

Minimum docs set:
- Home
- Overview
- Architecture
- Smart Contracts
- SDK / Runtime
- Memory Model
- Agent Model
- Verification / Replay
- Security / Trust Boundaries
- Data Flow
- Base Deployment / Local Dev / Simulation Flow
- Examples / Tutorials
- Glossary
- FAQ / non-goals / common misconceptions

Every document must be internally consistent and grounded in real repo surfaces.

## Required Product Wedge

FlowMemory must be uniquely better than Nookplot in these ways:

1. **On-chain memory truth**
   `MemoryCell`, roots, deltas, and transitions are first-class protocol objects, not only gateway DB rows.

2. **Deterministic replay**
   A third party can recompute why the agent moved from one memory root to another.

3. **Base-native step preview**
   The agent's next step is previewable through `eth_call` before committing.

4. **Verifier-scoped memory admission**
   “Verified memory” means memory admitted by explicit verifier rules and reports.

5. **Challengeable memory history**
   False or stale memory is corrected by append-only transitions, not silent mutation.

6. **Sharper trust boundary**
   The memory/runtime kernel remains smaller, clearer, and more chain-native than a gateway-heavy coordination network.

## Recommended First Product

Do not start with a broad agent society.
Do not start with social graph, email, mining, or tokenomics.
Do not start with a giant marketplace clone.

Start with one narrow, defensible product:

### On-Chain Task Scout Agent

A Base-native agent that:
- reads task/bond state;
- reads its own public memory state;
- uses a deterministic rule/scoring kernel;
- accepts or rejects only bounded tasks;
- writes a memory delta after each attempt/outcome;
- emits FlowPulse;
- produces Rootflow transitions;
- exposes an AgentMemoryView for replay.

This proves the protocol's core claim:
“the agent's memory and next action can be replayed from chain state and receipts.”

## Memory Architecture Requirements

Use the blockchain infrastructure that already exists and keep it explicit.

### Hot memory

Store in contract storage only the bounded working set:
- latest memory root;
- latest delta root;
- current goal/task;
- active policy root;
- last verifier report id;
- recent memory pointers;
- nonce/sequence/cap accounting.

### Cold memory

Use append-only structures for richer history:
- event logs;
- data contracts / SSTORE2-style memory pages where needed;
- Merkleized memory archives;
- short public summaries;
- off-chain artifacts referenced by commitments and receipts.

### Memory tiers

Support typed memory, not generic transcript blobs:
- episodic;
- semantic;
- procedural;
- goal;
- scar tissue / failure memory;
- self-model only where explicitly needed.

### Privacy boundary

If stored on-chain, it is public.
Therefore:
- never store secrets;
- never store private prompts by default;
- use commitments for heavy/private evidence;
- make public memory writes deliberate and typed.

## Agent Kernel Requirements

The first kernel must be bounded and deterministic.

Acceptable first kernel classes:
- rule engine;
- integer scoring engine;
- hybrid rule-gated scorer.

Later gated path:
- tiny fixed-shape Quill-like int8 kernel for bounded classification/ranking only.

Not acceptable as a first kernel:
- unconstrained free-text LLM loop on-chain;
- hidden off-chain decisions labeled as “on-chain”; 
- unverifiable gateway-only memory updates.

## Documentation Quality Requirements

The docs must be more useful than a marketing brochure.

Every major page must answer:
- what the surface does;
- what is on-chain;
- what is off-chain;
- what the trust assumptions are;
- what a developer calls or reads;
- how the replay path works;
- what can fail;
- what remains gated.

The home, overview, architecture, contracts, and SDK docs must all agree on:
- contract counts/surfaces;
- memory model;
- kernel model;
- Base-only scope if that is the chosen chain scope;
- what is implemented vs aspirational.

## Professional Standard

This work must read like a serious protocol and developer platform.

That means:
- crisp information architecture;
- exact language;
- no contradictions across docs;
- grounded trust-boundary statements;
- real diagrams or diagram-ready flows;
- examples that match actual code paths;
- code and docs that justify every product claim.

## Required Checks Before Claiming Done

Before finishing, verify all of the following:
- home/overview/architecture/contracts/sdk/docs are all present and mutually consistent;
- every major claim is grounded in code, schema, or explicit non-goal language;
- no doc silently overclaims privacy, decentralization, or production readiness;
- smart-contract/docs/sdk terminology match exactly;
- examples compile or are otherwise mechanically valid if code-backed;
- git status and diff are cleanly reviewable;
- area-specific tests/checks are run where code changed;
- remaining gaps are named explicitly, not hidden.

## Definition Of Done

Done means all of the following are true:
- the repo has a professional home/overview/architecture/documentation stack for the product;
- the contracts, SDK, and memory model are explained at a serious developer level;
- the Base-native on-chain agent memory wedge is clear and differentiates FlowMemory from Nookplot;
- the first narrow product is specified tightly enough to implement without ambiguity;
- no section feels like placeholder copy or vague aspiration;
- the work could be handed to a senior builder or reviewer and withstand scrutiny.

## Non-Negotiable Boundaries

- Do not build a Nookplot clone.
- Do not add tokenomics unless separately approved.
- Do not market gateway-backed memory as fully on-chain memory.
- Do not claim trustlessness where a verifier/gateway/admin still exists.
- Do not put heavy AI/model/media artifacts on-chain.
- Do not widen scope into broad social/community features before proving the memory/runtime kernel.
```

## Notes For HQ / Review

This goal prompt is intentionally broad because it defines a full product workstream, not a single issue.

If decomposed into worktrees, split it into at least these tracks:
- contracts + tests;
- crypto/schemas + replay semantics;
- indexer/verifier + memory projections;
- SDK/runtime + examples;
- docs/home/overview/architecture;
- dashboard/operator documentation and explorer models.

The professional documentation package now lives in `docs/base-onchain-agent-memory/`.
Use `docs/agent-goals/BASE_ONCHAIN_AGENT_MEMORY_EXECUTION_PACK.md` for worktree decomposition.

## Immediate Follow-On

The decomposition pack now exists at `docs/agent-goals/BASE_ONCHAIN_AGENT_MEMORY_EXECUTION_PACK.md` and includes:
- one HQ orchestrator brief;
- one contracts brief;
- one services/verifier brief;
- one crypto/schema brief;
- one SDK/runtime brief;
- one dashboard/docs brief;
- shared constraints and an explicit acceptance matrix.
