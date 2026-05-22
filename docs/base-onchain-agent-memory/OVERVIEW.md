# Overview

## Product thesis

FlowMemory should become the Base-native memory kernel for autonomous agents that need public continuity, bounded authority, and replayable decisions.

The product is not a general agent society. It is the state spine that an agent society would need if agents are expected to act with durable memory and verifiable accountability.

## Problem

Current agent systems usually combine strong reasoning with weak public state:

- the agent's memory can be edited silently;
- the reason for an action is often trapped in a private transcript;
- action logs and memory logs are stored in different systems;
- failed assumptions disappear instead of becoming durable scar tissue;
- third-party agents cannot safely inherit or trust the memory state;
- gateways can provide good UX while still leaving unclear which facts are chain-derived.

For high-value or long-running autonomous work, the missing primitive is not another chat surface. It is a small, explicit state machine for memory and action continuity.

## Core primitive

```text
AgentAccount
-> observes chain state, events, receipts, or admitted evidence
-> reads MemoryCell hot state and memory roots
-> previews AgentKernel output with eth_call
-> executes only an allowlisted action through AgentToolRouter
-> commits MemoryDelta
-> emits FlowPulse
-> indexer derives MemorySignal and RootflowTransition
-> verifier assigns status
-> AgentMemoryView exposes replayable state
```

## First product: On-Chain Task Scout

The first serious product should be a deterministic task scout, not a conversational agent.

The scout:

- watches task, bond, or work-state contracts;
- reads public memory about prior successes, failures, slashes, unsupported task types, and budget usage;
- computes an action with a rule-gated scoring kernel;
- accepts, rejects, escalates, or no-ops;
- writes a memory delta after the outcome;
- emits FlowPulse and produces replayable Rootflow transitions;
- exposes an `AgentMemoryView` showing the current memory root, statuses, and next safe action.

This proves the main claim: an agent can have chain-side memory and a replayable next-step path without pretending that full unrestricted model inference belongs in the first contract.

## Main primitives

| Primitive | Purpose |
| --- | --- |
| `AgentAccount` | Identity, owner/admin boundaries, kernel class, status, nonce, current roots. |
| `AgentPolicy` | Bounded autonomy rules: caps, allowed tools, maximum cost, task classes, pause conditions. |
| `MemoryCell` | Typed public memory unit or commitment to private/heavy memory. |
| `MemoryDelta` | Append-only change from parent memory root to new memory root. |
| `AgentKernel` | Deterministic rule/scoring/tiny fixed-shape logic that selects an action from a small enum. |
| `AgentToolRouter` | Contract surface that executes only declared and capped actions. |
| `ActionReceipt` | Objective record of the selected action, target, result, and memory write. |
| `VerifierReport` | Deterministic local/test status result for a receipt or transition. |
| `RootflowTransition` | Parent root, new root, receipt, verifier report, status, and source observation. |
| `AgentMemoryView` | Agent-facing projection for bootstrapping, inspection, and replay. |

## Architecture layers

1. **Contracts** — compact state, agent registry, memory roots/cells, action router, FlowPulse emission.
2. **Schemas and crypto helpers** — canonical ids, hash inputs, typed domains, JSON schemas, fixtures.
3. **Indexer** — reads receipts/logs after execution and derives locator fields such as `txHash` and `logIndex`.
4. **Verifier** — checks policy, root transitions, receipt consistency, and evidence commitments.
5. **SDK/runtime** — safe developer API for registration, reads, `previewStep`, `step`, event decoding, and replay.
6. **Dashboard/explorer** — views memory roots, hot cells, recent actions, status, failures, and replay traces.
7. **Docs and runbooks** — exact trust boundaries, setup, examples, and review gates.

## Scope phases

### Phase 0: documentation and fixture design

- Define vocabulary, diagrams, and acceptance criteria.
- Add one deterministic On-Chain Task Scout fixture.
- Use existing FlowPulse, Rootflow, Flow Memory, Agent Bonds, and dashboard vocabulary.
- No new contract deployment claim.

### Phase 1: local/test rule kernel

- Add minimal local/test contracts for agent registration, memory root update, preview, and commit.
- Emit FlowPulse for agent step and memory commit.
- Add Foundry tests for preview/commit parity, cap enforcement, root sequence, and failure memory.

### Phase 2: memory store and replay

- Add typed hot memory slots and append-only delta history.
- Extend schemas for `MemoryCell`, `MemoryDelta`, `ActionReceipt`, and task-scout `AgentMemoryView`.
- Index and verify the local/test fixture.

### Phase 3: SDK and examples

- Add contract bindings and a high-level TypeScript client.
- Support read-only preview and committed step paths.
- Provide examples that run against the local/test fixture.

### Phase 4: guarded Base Sepolia rehearsal

- Rehearse only after local tests and docs are green.
- Use explicit chain ID checks and configured addresses.
- Keep bounded block ranges and no secret persistence.

### Later gated path: tiny fixed-shape kernel

A A small deterministic model kernel can later classify memory importance or rank candidate actions. It must remain fixed-shape, deterministic, rule-gated, and limited to small action spaces.

## What is implemented now

The current repo already has important foundations:

- `contracts/FlowPulse.sol`;
- `contracts/RootfieldRegistry.sol`;
- Rootflow and Flow Memory V0 specs;
- generated launch-core fixtures;
- local indexer/verifier packages;
- crypto helper package and schemas;
- fixture-backed dashboard;
- Agent Bonds local/test accountability contracts;
- Base Sepolia and guarded canary reader paths.

This workstream should build on those surfaces instead of creating a parallel protocol vocabulary.

## What is still proposed

The following are proposed by this documentation package and require implementation work before claims can be made:

- an agent registry specialized for deterministic agent state;
- chain-side memory cells and memory deltas for agents;
- `previewStep` / `step` parity tests;
- tool/action router with caps;
- task-scout fixtures and dashboard projections;
- SDK helpers for agent memory and replay;
- Base Sepolia rehearsal for the agent memory path.

## Sharp differentiation

FlowMemory should win by being the smaller, replayable kernel:

- broad coordination systems-style systems optimize broad coordination and onboarding.
- Small deterministic model-kernel demos prove deterministic EVM model execution is possible for small fixed objects.
- FlowMemory combines the useful discipline from both: agent memory and actions become compact public state transitions with deterministic replay.

## Success statement

A third party should be able to reconstruct an agent step from public state and receipts:

1. prior memory root;
2. observed task state;
3. kernel configuration;
4. selected action;
5. tool route and cap checks;
6. action receipt;
7. memory delta;
8. new memory root;
9. verifier status;
10. current `AgentMemoryView`.
