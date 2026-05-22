# Examples

## Example 1: On-Chain Task Scout accepts a safe task

### Starting memory

```json
{
  "agentId": "0xagent",
  "latestMemoryRoot": "0xroot001",
  "sequence": 7,
  "activeGoal": "accept-low-risk-public-docs-review-tasks",
  "taskKindStats": {
    "docs-review": {
      "successCount": 8,
      "failureCount": 1,
      "requiresHumanReview": false
    }
  },
  "spendUsedThisEpoch": "0"
}
```

### Observation

```json
{
  "kind": "task",
  "taskContract": "0xtask",
  "taskId": "0x1234",
  "taskKind": "docs-review",
  "rewardToken": "0x0000000000000000000000000000000000000000",
  "rewardAmount": "0",
  "evidenceRequirement": "public-link",
  "deadline": "18000000"
}
```

### Preview result

```json
{
  "action": "ACCEPT_TASK",
  "reasonCode": "TASK_KIND_ALLOWED",
  "toolId": "TASK_BOND_ACCEPT_V1",
  "target": "0xtask",
  "selector": "acceptTask(bytes32)",
  "maxValue": "0",
  "memoryDeltaRoot": "0xdelta001"
}
```

### Memory delta

```json
{
  "memoryType": "goal",
  "subject": "task:0x1234",
  "contentMode": "COMMITMENT_ONLY",
  "parentMemoryRoot": "0xroot001",
  "newMemoryRoot": "0xroot002",
  "sourceObservationId": "0xobs001",
  "actionReceiptId": "0xreceipt001",
  "status": "pending"
}
```

### Resulting view

```json
{
  "agentId": "0xagent",
  "latestMemoryRoot": "0xroot002",
  "sequence": 8,
  "recentActions": [
    {
      "action": "ACCEPT_TASK",
      "taskId": "0x1234",
      "status": "pending"
    }
  ],
  "pendingMemory": ["0xmemory001"]
}
```

## Example 2: task is escalated because memory says it is risky

### Starting memory

```json
{
  "taskKindStats": {
    "external-audit": {
      "successCount": 0,
      "failureCount": 2,
      "requiresHumanReview": true,
      "lastFailureReason": "evidence-unavailable"
    }
  }
}
```

### Observation

```json
{
  "kind": "task",
  "taskKind": "external-audit",
  "evidenceRequirement": "private-review-notes"
}
```

### Preview result

```json
{
  "action": "ESCALATE",
  "reasonCode": "HUMAN_REVIEW_REQUIRED",
  "toolId": "NONE",
  "target": "0x0000000000000000000000000000000000000000",
  "maxValue": "0",
  "memoryDeltaRoot": "0xdelta002"
}
```

The agent records that the task was seen and escalated, but does not accept it.

## Example 3: failure becomes scar tissue

### Outcome observation

```json
{
  "kind": "task-outcome",
  "taskId": "0x1234",
  "result": "failed",
  "reason": "evidence-unavailable"
}
```

### Preview result

```json
{
  "action": "UPDATE_MEMORY_ONLY",
  "reasonCode": "MEMORY_ONLY_UPDATE",
  "memoryDeltaRoot": "0xdelta003"
}
```

### New memory

```json
{
  "memoryType": "scar_tissue",
  "subject": "task-kind:docs-review",
  "contentMode": "COMMITMENT_ONLY",
  "publicLabel": "evidence unavailable failure; increase caution",
  "failureCountIncrement": 1,
  "supersedes": null
}
```

Future previews use this memory to penalize similar tasks.

## Example SDK usage

```ts
const agent = await client.getAgent(agentId);

const observation = client.encodeTaskObservation({
  taskContract,
  taskId,
  taskKind: "docs-review",
  rewardToken: zeroAddress,
  rewardAmount: 0n,
  evidenceRequirement: "public-link",
  deadline,
});

const preview = await client.previewStep({ agentId, observation });

switch (preview.action) {
  case "ACCEPT_TASK": {
    const submitted = await client.step({
      agentId,
      observation,
      expectedPreview: preview,
      expectedSequence: agent.sequence,
      maxValue: preview.maxValue,
    });

    const receipt = await client.waitForStepReceipt(submitted.hash);
    const replay = await client.replayStep(receipt);

    if (replay.status !== "verified" && replay.status !== "pending") {
      throw new Error(`unexpected replay status: ${replay.status}`);
    }
    break;
  }
  case "ESCALATE":
  case "REJECT_TASK":
  case "NOOP":
    await client.step({
      agentId,
      observation,
      expectedPreview: preview,
      expectedSequence: agent.sequence,
      maxValue: 0n,
    });
    break;
}
```

## Example replay trace

```json
{
  "agentId": "0xagent",
  "transactionHash": "0xtx",
  "logIndex": 3,
  "parentMemoryRoot": "0xroot001",
  "newMemoryRoot": "0xroot002",
  "observationRoot": "0xobsroot",
  "actionReceiptId": "0xreceipt001",
  "status": "verified",
  "checks": [
    { "name": "agent-active", "status": "pass" },
    { "name": "sequence", "status": "pass" },
    { "name": "kernel-output", "status": "pass" },
    { "name": "tool-allowlist", "status": "pass" },
    { "name": "cap", "status": "pass" },
    { "name": "memory-root", "status": "pass" }
  ]
}
```

## Example external review brief

Use this with an external off-chain reviewer. Do not include secrets.

```text
You are reviewing FlowMemory's Base on-chain agent memory architecture.

Context:
- FlowMemory stores compact roots, receipts, commitments, attestations, proofs, and work state on-chain.
- Heavy AI/model/memory artifacts stay off-chain unless intentionally reduced to compact public state.
- The proposed product is a Base-native agent memory kernel, not a broad social network.
- First product: On-Chain Task Scout with deterministic preview/commit, typed memory, FlowPulse, RootflowTransition, and AgentMemoryView.

Review tasks:
1. Find unsafe trust-boundary claims.
2. Find missing contract invariants.
3. Find replay gaps that would let memory drift from receipts.
4. Find memory poisoning and tool-routing attacks.
5. Suggest simplifications that make the first implementation safer.
6. Identify anything that broadens the scope instead of sharpening FlowMemory's memory/replay wedge.

Return:
- critical blockers;
- important improvements;
- optional later ideas;
- exact tests that should be added.
```

## Example human-facing explanation

```text
FlowMemory lets an agent carry public working memory on Base.
The first agent class is small: it watches tasks, previews its next step, acts only through approved contracts, records what happened, and updates memory through replayable roots. You do not trust a private server log; you inspect the receipts, memory transitions, and verifier reports.
```
