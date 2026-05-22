# Local Development and Simulation

## Purpose

The first build must be reproducible locally before any wider network rehearsal. The local path proves the state machine, not the market or production operation.

## Existing commands to preserve

Do not break the current baseline:

```powershell
npm run launch:v0
npm run launch:candidate
npm run flowchain:smoke
npm run flowchain:full-smoke
```

Use the existing launch-core fixtures, schemas, indexer/verifier packages, dashboard fixture generation, and Agent Bonds local/test surfaces wherever possible.

## MVP 0: fixture-only proof

Before writing contracts, create a deterministic fixture package for one On-Chain Task Scout.

Required fixture objects:

1. `AgentConfig`;
2. `HotMemory`;
3. `TaskObservation`;
4. `StepPreview`;
5. `ActionReceipt`;
6. `MemoryDelta`;
7. `FlowPulse`-like event object;
8. `VerifierReport`;
9. `RootflowTransition`;
10. `AgentMemoryView`.

Acceptance:

- fixture validates against schemas;
- replay fails if any critical field changes;
- dashboard can display the view;
- docs and examples match fixture fields.

## MVP 1: local/test contracts

Add small contracts only after fixture semantics are accepted.

Suggested contract test flow:

```text
register agent
-> read hot memory
-> preview open task
-> commit step
-> emit events
-> update memory root
-> decode receipt
-> verify transition
```

Required Foundry tests:

- registration stores initial root;
- preview does not mutate state;
- accepted task branch works;
- rejected task branch works;
- escalation branch works;
- stale sequence rejected;
- parent root mismatch rejected;
- disabled tool rejected;
- cap exceeded rejected;
- paused agent cannot mutate;
- FlowPulse fields are emitted for replay.

## MVP 2: service replay

Extend local services to index and verify the new event path.

Required service checks:

- decode agent events;
- derive observation identity from receipts/logs;
- construct task-scout `MemorySignal`;
- construct `ActionReceipt`;
- construct `MemoryDelta`;
- construct `RootflowTransition`;
- map verifier status into `AgentMemoryView`;
- reject drift from deterministic fixture output.

## MVP 3: SDK example

Add a runnable TypeScript example against the local fixture or local test chain.

Example flow:

```text
create client
-> get agent
-> encode task observation
-> preview step
-> submit step with expected preview
-> wait for receipt
-> replay step
-> print AgentMemoryView
```

The example must make preview vs mutation obvious.

Current repo implementation path:
- fixture generation: `npm run flowmemory:agent-memory:local`
- launch-core regeneration: `npm run launch:v0`
- live local operator/read path through control-plane RPC: `AgentMemoryRpcClient`
- Base Sepolia rehearsal plan: `npm run deploy:base-agent-memory:base-sepolia:plan`

## MVP 4: dashboard view


Actual deployed-log local proof now exists:

```powershell
npm run flowmemory:agent-memory:e2e
```

It:
- starts a local Anvil chain;
- deploys `BaseOnchainAgentMemory` and a task target mock;
- executes real on-chain `registerAgent`, `setToolPolicy`, `step`, `setAgentPaused`, and `correctMemory` calls;
- captures actual emitted FlowPulse receipts;
- indexes and verifies the deployed step receipt path;
- writes local e2e artifacts under `devnet/local/base-agent-memory-e2e/`.
Add or extend fixture-backed dashboard views only after the data model is stable.

Minimum fields:

- agent id;
- status;
- memory root;
- sequence;
- active goal;
- recent actions;
- memory buckets by status;
- last verifier report;
- previewed next action;
- replay trace link or panel.

## Base Sepolia rehearsal gate

Base Sepolia rehearsal can occur only after local fixture, contracts, service replay, SDK example, and docs are coherent.

Required safety gates:

- explicit chain ID check;
- explicit configured addresses;
- no secret persistence;
- bounded read ranges;
- dry-run or plan artifact before broadcast;
- source verification plan if contracts are deployed;
- rollback/pause instructions;
- dashboard mode separate from local fixture mode.

## External model review workflow

If using an external model for architecture review:

1. Do not paste secrets.
2. Give it this documentation package and ask for adversarial review.
3. Ask for concrete failure modes, missing invariants, unsafe claims, and simplifications.
4. Summarize accepted review findings into a local artifact.
5. Do not store API keys or raw private transcripts in the repo.
6. Convert accepted findings into issues, tests, docs changes, or memory-review commitments.

Suggested environment variable names if a local script is later added:

```text
MODEL_REVIEW_API_KEY
```

These variables must remain local and uncommitted.

## Suggested local fixture path

```text
fixtures/base-agent-memory/task-scout-v0.json
fixtures/base-agent-memory/task-scout-agent-memory-view.json
fixtures/base-agent-memory/task-scout-replay-report.json
```

Suggested schema path:

```text
schemas/base-agent-memory/agent-config.schema.json
schemas/base-agent-memory/hot-memory.schema.json
schemas/base-agent-memory/task-observation.schema.json
schemas/base-agent-memory/step-preview.schema.json
schemas/base-agent-memory/action-receipt.schema.json
schemas/base-agent-memory/memory-delta.schema.json
schemas/base-agent-memory/agent-memory-view.schema.json
```

Use existing `schemas/flowmemory/` objects when they already fit.

## Local acceptance command direction

The local acceptance command now exists:

```powershell
npm run flowmemory:agent-memory:local
```

Current behavior:

- generate deterministic task-scout fixture;
- run replay checks during fixture generation;
- write:
  - `fixtures/base-agent-memory/task-scout-v0.json`
  - `fixtures/base-agent-memory/task-scout-agent-memory-view.json`
  - `fixtures/base-agent-memory/task-scout-replay-report.json`

Broader local acceptance still uses:

```powershell
npm run launch:v0
npm run launch:candidate
```

## Operator checklist for local proof

- [ ] Current launch-core baseline passes.
- [ ] Agent fixture generation is deterministic.
- [ ] Contract tests pass if contracts changed.
- [ ] Service replay tests pass if services changed.
- [ ] SDK tests pass if SDK changed.
- [ ] Dashboard build/tests pass if dashboard changed.
- [ ] Claim guardrails pass for docs.
- [ ] `git diff --check` passes.
- [ ] PR summary names remaining gates.

## Scope discipline

The local proof should not introduce:

- a new token;
- a broad marketplace;
- production infrastructure;
- hosted services;
- a generic arbitrary-call executor;
- unrestricted model inference;
- private memory storage in public logs.
