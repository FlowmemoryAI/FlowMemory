# Base On-Chain Agent Memory Execution Pack

## Purpose

Use this pack to launch coordinated Codex worktrees for the Base On-Chain Agent Memory workstream. It decomposes the professional docs package into buildable tracks with shared constraints, handoff contracts, and acceptance evidence.

Primary docs:

- `docs/base-onchain-agent-memory/README.md`
- `docs/base-onchain-agent-memory/OVERVIEW.md`
- `docs/base-onchain-agent-memory/ARCHITECTURE.md`
- `docs/base-onchain-agent-memory/SMART_CONTRACTS.md`
- `docs/base-onchain-agent-memory/SDK_RUNTIME.md`
- `docs/base-onchain-agent-memory/MEMORY_MODEL.md`
- `docs/base-onchain-agent-memory/AGENT_MODEL.md`
- `docs/base-onchain-agent-memory/VERIFICATION_REPLAY.md`
- `docs/base-onchain-agent-memory/SECURITY_TRUST_BOUNDARIES.md`
- `docs/base-onchain-agent-memory/DATA_FLOW.md`
- `docs/base-onchain-agent-memory/LOCAL_DEV_AND_SIMULATION.md`
- `docs/base-onchain-agent-memory/EXAMPLES.md`
- `docs/base-onchain-agent-memory/ACCEPTANCE_MATRIX.md`

## Shared constraints for every track

```text
Read AGENTS.md, docs/START_HERE.md, docs/FLOWMEMORY_HQ_CONTEXT.md, docs/CURRENT_STATE.md, docs/ARCHITECTURE.md, docs/ROOTFLOW_V0.md, docs/FLOW_MEMORY_V0.md, docs/V0_LAUNCH_ACCEPTANCE.md, and the docs/base-onchain-agent-memory package before editing.

Build the On-Chain Task Scout as the first proof. Do not widen into social graph, broad marketplace, tokenomics, mining, unrestricted model inference, production infrastructure, or hidden gateway memory.

Keep heavy AI/model/memory artifacts off-chain unless deliberately reduced to compact public state or commitments. Do not store secrets. Do not claim production or mainnet readiness. Contracts must not assume txHash or logIndex during execution. Indexers derive receipt metadata after execution.

Every mutation must be replayable from state, receipts, events, and admitted evidence. Every track must update docs if it changes architecture, terms, schemas, or trust boundaries.
```

## Track 1: HQ orchestrator

### Target files

- `docs/base-onchain-agent-memory/ACCEPTANCE_MATRIX.md`
- `docs/ISSUE_BACKLOG.md` if creating milestone entries
- `docs/AGENT_PROMPTS.md` if adding reusable worktree prompt text
- `docs/reviews/` for completion audits

### Goal

Coordinate the workstream without building product logic in the HQ track.

### Tasks

1. Convert the acceptance matrix into issues or PR checklists.
2. Assign worktree ownership and allowed folders.
3. Prevent overlap between contracts, services, SDK, dashboard, and docs tracks.
4. Track evidence for fixture, contracts, schemas, replay, SDK, dashboard, and guardrails.
5. Maintain a risk log for unresolved design questions.

### Acceptance

- Each implementation track has exact allowed/forbidden folders.
- Acceptance criteria map back to `docs/base-onchain-agent-memory/ACCEPTANCE_MATRIX.md`.
- No track is allowed to claim completion without test/check evidence.

## Track 2: contracts

### Target files

- `contracts/`
- `tests/`
- `contracts/FLOWPULSE_SCHEMA.md` if new pulse types are added
- contract-specific docs when needed

### Goal

Implement the local/test contract spine for the task-scout memory loop.

### Required surfaces

1. Agent registry.
2. Memory store or root-only memory delta store.
3. Rule/scoring task-scout kernel.
4. Step/tool router.
5. FlowPulse emission for step and memory commit.

### Required tests

- registration;
- read-only preview;
- preview/commit parity;
- stale sequence rejection;
- parent root mismatch;
- disabled tool rejection;
- cap exceeded;
- paused agent mutation blocked;
- failure/no-op/escalation path;
- event fields sufficient for indexer replay.

### Non-goals

- no tokenomics;
- no broad marketplace;
- no generic arbitrary-call executor;
- no tiny model kernel in first contract PR;
- no production or mainnet readiness claim.

## Track 3: crypto and schemas

### Target files

- `crypto/`
- `schemas/flowmemory/` or `schemas/base-agent-memory/`
- fixture vectors
- crypto/schema docs

### Goal

Define canonical ids, hash domains, schemas, and negative vectors for the task-scout loop.

### Required schemas

- `AgentConfig`;
- `HotMemory`;
- `TaskObservation`;
- `StepPreview`;
- `ActionReceipt`;
- `MemoryCell`;
- `MemoryDelta`;
- `VerifierReport`;
- `RootflowTransition` extension or fixture mapping;
- `AgentMemoryView` extension or fixture mapping.

### Required negative tests

Replay or validation must fail when these are changed:

- parent memory root;
- task kind;
- selected action;
- target/selector;
- memory delta root;
- sequence;
- evidence requirement.

## Track 4: indexer and verifier

### Target files

- `services/indexer/`
- `services/verifier/`
- `services/flowmemory/` when projecting Flow Memory objects
- related fixtures

### Goal

Decode task-scout events, derive observation identity, verify transitions, and project `AgentMemoryView`.

### Required behavior

1. Decode agent/FlowPulse events.
2. Derive transaction hash, log index, block metadata, and observation id from receipts/logs.
3. Build memory signal/action receipt/memory delta objects.
4. Verify kernel/action/policy/cap/root consistency.
5. Produce deterministic verifier reports.
6. Project Rootflow transitions.
7. Project AgentMemoryView buckets.
8. Handle duplicate/reorg/unsupported/unresolved states explicitly.

### Non-goals

- no hosted service runtime;
- no verifier economics;
- no hidden off-chain decision logic.

## Track 5: SDK and runtime examples

### Target files

- existing SDK package if extended, or a scoped new SDK folder if approved
- `docs/base-onchain-agent-memory/SDK_RUNTIME.md`
- examples/fixtures for local/test flow

### Goal

Expose safe developer APIs for reads, preview, step, event decoding, replay, and examples.

### Required APIs

- `AgentMemoryClient` and `AgentMemoryRpcClient`;
- `getAgent`;
- `getHotMemory`;
- `encodeTaskObservation`;
- `previewStep`;
- `step`;
- `waitForStepReceipt`;
- `replayStep`;
- `getAgentMemoryView`;
- flowchain devkit access for task-scout list/get/replay.

### Required safety

- chain id mismatch rejected;
- contract addresses explicit;
- preview never mutates;
- mutation requires expected preview and sequence;
- errors are typed;
- examples do not store secrets.

## Track 6: dashboard and explorer model

### Target files

- `apps/dashboard/`
- dashboard fixtures
- dashboard docs when relevant

### Goal

Show the task-scout state in a fixture-backed local view.

### Required views

- agent identity/status;
- current memory root and sequence;
- hot memory fields;
- policy/tool roots;
- recent actions and reason codes;
- memory buckets by status;
- verifier report checks;
- replay trace from parent root to new root;
- clear local/test/fixture boundary label.

### Non-goals

- no hosted production API;
- no broad explorer redesign outside the task-scout fixture unless separately scoped.

## Track 7: docs and external model review

### Target files

- `docs/base-onchain-agent-memory/`
- `docs/agent-goals/BASE_ONCHAIN_AGENT_MEMORY_GOAL_PROMPT.md`
- review notes under `docs/reviews/` if accepted

### Goal

Keep the docs professional, internally consistent, and adversarially reviewed.

### External review process

1. Use the brief in `docs/base-onchain-agent-memory/EXAMPLES.md`.
2. Do not paste secrets.
3. Do not commit API keys or raw private transcripts.
4. Summarize accepted findings.
5. Convert findings into concrete tests, docs edits, or issue criteria.

### Acceptance

- Docs match implemented contracts, schemas, SDK names, and statuses.
- Claim guardrails pass.
- Remaining gaps are explicit gates.

## Cross-track handoff contract

Every track handoff must include:

```text
Changed files:
Checks run:
Objects/contracts/schemas added:
Terms changed:
Events emitted/decoded:
Fixture paths:
Known gaps:
Blocked claims:
Next smallest safe task:
```

## Done for the whole workstream

The whole workstream is done only when:

1. deterministic local/test task-scout fixture exists;
2. contracts implement preview, commit, memory, and route gates;
3. contracts tests cover safety invariants;
4. schemas and vectors validate fixture objects;
5. indexer/verifier reconstruct and verify the transition;
6. SDK runs the example flow;
7. dashboard shows the agent memory view;
8. docs match implementation;
9. guardrails pass;
10. acceptance matrix evidence is complete.
