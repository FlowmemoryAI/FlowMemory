# Data Flow

## End-to-end flow

```text
Task / Chain State
  |
  v
Typed Observation
  |
  v
previewStep via eth_call
  |
  v
KernelOutput + PreviewHash
  |
  v
step transaction with expected preview and limits
  |
  v
AgentToolRouter executes allowed action or records no-op/escalation
  |
  v
AgentMemoryStore commits MemoryDelta
  |
  v
FlowPulse + agent events
  |
  v
Indexer derives receipt/log identity
  |
  v
Verifier checks action, policy, caps, and roots
  |
  v
RootflowTransition
  |
  v
AgentMemoryView
```

## Step 1: task or chain state exists

The first observation source is a task/bond/work-state contract. The agent does not need to know the internet. It needs a typed on-chain fact.

Example source fields:

```text
taskContract
taskId
taskKind
rewardToken
rewardAmount
evidenceRequirement
deadline
currentStatus
```

## Step 2: observation is encoded

The SDK or indexer canonicalizes the source fields.

```text
TaskObservation
-> canonical encoding
-> observationRoot
```

The observation root is passed to preview and commit paths. Display strings and UI labels should not be canonical state unless the schema explicitly includes them.

## Step 3: preview reads current agent state

`previewStep` reads:

- agent config;
- current memory root;
- hot memory;
- policy root;
- tool allowlist root;
- current sequence;
- observation root.

It returns:

- action enum;
- tool id;
- target;
- selector;
- call data hash;
- memory delta root;
- reason code;
- max value;
- preview hash.

Preview is read-only.

## Step 4: caller submits step

The caller submits the expected preview with limits.

```text
step(agentId, observationRoot, expectedOutput, maxValue, expectedSequence)
```

The contract rejects stale sequence, mismatched preview, paused status, unknown tool, or cap excess before unsafe mutation.

## Step 5: action routing

The router maps action enum and tool id to a specific allowed contract call.

Possible outcomes:

- action executed successfully;
- action reverted and the step records failure if safe;
- action is rejected before call;
- no-op is recorded;
- escalation is recorded;
- self-pause is recorded.

## Step 6: memory delta

After the action path, the memory store commits a delta.

```text
parentMemoryRoot
+ memoryDeltaRoot
+ actionReceiptId
+ sourceObservationRoot
= newMemoryRoot
```

The delta should explain what changed in compact typed form.

## Step 7: event emission

Contracts emit events sufficient for replay.

Event families:

- agent registered;
- step committed;
- action executed or skipped;
- memory committed;
- agent paused;
- memory corrected later.

FlowPulse should remain the shared event spine when adding new pulse types.

## Step 8: indexer derives observation identity

The indexer reads the receipt and logs.

Derived fields:

- chain id;
- block number;
- block hash;
- transaction hash;
- log index;
- contract address;
- event signature;
- payload hash.

The indexer persists canonical state and marks duplicates, rejected logs, and reorgs explicitly.

## Step 9: verifier checks transition

The verifier applies deterministic rules.

Checks include:

- event schema;
- agent status;
- sequence;
- parent root;
- kernel output;
- tool allowlist;
- caps;
- action receipt;
- memory delta;
- evidence availability;
- reorg state.

The verifier emits or writes a report with status.

## Step 10: Rootflow transition

The verified or pending transition is projected:

```text
RootflowTransition
- sourceObservationId
- agentId
- parentRoot
- newRoot
- actionReceiptId
- verifierReportId
- status
```

Rootflow is the durable memory-state transition layer.

## Step 11: AgentMemoryView

The agent-facing projection is updated.

View buckets:

- current hot memory;
- verified memory;
- pending memory;
- failed memory;
- corrected/superseded memory;
- unsupported memory;
- stale/expired memory;
- recent actions;
- next preview.

The view is a projection, not the source of truth.

## Diagram: On-Chain Task Scout accepts a task

```text
Open Task
  |
  | encodeTaskObservation
  v
ObservationRoot A
  |
  | previewStep(agent, A)
  v
ACCEPT_TASK, reason TASK_KIND_ALLOWED, deltaRoot D
  |
  | step(agent, A, expectedPreview, maxValue=0)
  v
Task contract acceptTask(taskId)
  |
  v
ActionReceipt R
  |
  v
MemoryDelta: prior success/failure counters, active task id
  |
  v
FlowPulse: AGENT_STEP_COMMITTED / AGENT_MEMORY_COMMITTED
  |
  v
Indexer observation O
  |
  v
VerifierReport verified
  |
  v
RootflowTransition parentRoot -> newRoot
  |
  v
AgentMemoryView shows task accepted and next deadline
```

## Diagram: task is rejected from memory

```text
Open Task kind: external-audit
  |
  v
Memory says external-audit requires human review
  |
  v
previewStep returns ESCALATE, reason HUMAN_REVIEW_REQUIRED
  |
  v
step records escalation with no external task acceptance
  |
  v
MemoryDelta records task skipped/escalated
  |
  v
AgentMemoryView shows pending human review
```

## Diagram: failure becomes scar tissue

```text
Accepted task
  |
  v
Evidence unavailable before deadline
  |
  v
Outcome observation encoded
  |
  v
previewStep returns UPDATE_MEMORY_ONLY
  |
  v
MemoryDelta increments failureCount and records reason
  |
  v
Future previews penalize same task kind
```

## Data that must not be silently inferred

The system must not infer these without an explicit source:

- off-chain task completion;
- private evidence content;
- subjective quality judgment;
- model review result;
- social reputation;
- human approval;
- external website state.

Each must enter through a signed receipt, content commitment, verifier report, oracle, or explicit operator transaction.

## File and schema outputs for MVP

MVP fixture should produce or update:

- fixture task observation;
- fixture agent config;
- fixture hot memory;
- fixture preview output;
- fixture action receipt;
- fixture memory delta;
- fixture verifier report;
- fixture Rootflow transition;
- fixture AgentMemoryView;
- dashboard-readable fixture state.

These artifacts should be deterministic and checked for drift.
