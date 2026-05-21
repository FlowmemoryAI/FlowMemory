# SDK Reference

## Package

`services/agent-memory-sdk/` now exposes two local/test developer surfaces for the first Base On-Chain Task Scout proof.

- `AgentMemoryClient` — synchronous fixture-backed client for deterministic local artifact work.
- `AgentMemoryRpcClient` — async control-plane-backed client for live local operator/read paths.

Both are intentionally narrow:

- read one deterministic task-scout proof;
- encode a task observation;
- preview the deterministic next step;
- submit the expected preview into a bounded local/test `step` path;
- replay the resulting receipt;
- return the projected `AgentMemoryView`.

It does not hide trust boundaries or simulate a hosted runtime.

## Main exports
- `AgentMemoryClient`
- `AgentMemoryRpcClient`
- `AgentMemoryError`
- `AgentConfig`
- `HotMemory`
- `TaskObservationInput`
- `EncodedTaskObservation`
- `StepPreview`
- `SubmittedStep`
- `ReplayTrace`
- `ReplayCheck`
- `AgentMemoryView`

## Constructor

```ts
const client = new AgentMemoryClient({
  chainId: 84532,
  fixturePath: "fixtures/base-agent-memory/task-scout-v0.json",
});
```

Control-plane-backed local mode:

```ts
const client = new AgentMemoryRpcClient({
  chainId: 84532,
  rpcUrl: "http://127.0.0.1:8787/rpc",
});
```

Options:

- `chainId` — defaults to the fixture chain id.
- `fixturePath` — defaults to `fixtures/base-agent-memory/task-scout-v0.json`.
- `rpcUrl` — required for `AgentMemoryRpcClient`.

## Errors

| Code | Meaning |
| --- | --- |
| `CHAIN_ID_MISMATCH` | The configured chain id does not match the loaded fixture. |
| `AGENT_NOT_FOUND` | Unknown agent id for this fixture. |
| `OBSERVATION_MISMATCH` | The supplied observation root does not match the task-scout fixture. |
| `SEQUENCE_STALE` | Caller tried to step with the wrong expected sequence. |
| `PREVIEW_MISMATCH` | Caller submitted a preview hash different from the fixture preview. |
| `CAP_EXCEEDED` | The supplied max value does not match the fixture path. |
| `RECEIPT_NOT_FOUND` | Unknown transaction hash for the fixture. |
| `REPLAY_NOT_FOUND` | Unknown action receipt for replay. |

## Read methods

### `getAgent(agentId)`

Returns the compact chain-side config for the fixture agent.

### `getHotMemory(agentId)`

Returns current working memory: latest root, active goal, last receipt/report references, sequence, failure count, and spend counter.

### `getAgentMemoryView(agentId)`

Returns the projected view: current root, sequence, verified/pending/failed memory ids, recent actions, and replay warnings.

## Observation encoding

### `encodeTaskObservation(input)`

Creates a typed task observation and the canonical observation root used by preview/replay.

Required input fields:

- `taskContract`
- `taskId`
- `taskKind`
- `taskKindName`
- `evidenceRequirement`
- `evidenceRequirementName`
- `rewardToken`
- `rewardAmount`
- `deadlineBlock`
- `taskStatus`
- `recentFailureCount`
- `humanReviewRequired`

The first fixture expects the low-risk public docs-review shape from `fixtures/base-agent-memory/task-scout-v0.json`.

## Preview and step

### `previewStep({ agentId, observation })`

Returns:

- action enum;
- tool id;
- target;
- selector;
- call data hash;
- memory delta root;
- reason code;
- preview hash;
- max value.

### `step({ agentId, observation, expectedPreview, expectedSequence, maxValue })`

Requires an exact expected preview and exact expected sequence. It returns a submitted fixture transaction hash.

This preserves the intended contract semantics:

- preview is read-only;
- mutation must be explicit;
- callers do not silently accept changed state.

## Receipt and replay

### `waitForStepReceipt(hash)`

Returns the deterministic fixture action receipt associated with the submitted hash.

### `replayStep(receiptOrId)`

Returns a replay trace with:

- transaction hash;
- log index;
- parent root;
- new root;
- observation root;
- action receipt id;
- verifier report id;
- overall replay status;
- individual checks.

## Example

```ts
import { AgentMemoryClient } from "../../services/agent-memory-sdk/src/index.ts";

const client = new AgentMemoryClient();
const agent = client.getAgent("0x54b047dd7daa6ef87caefa5e0ad8e38051c899bff154438d77bd1d02545512f9");

const observation = client.encodeTaskObservation({
  taskContract: "0x3000000000000000000000000000000000000003",
  taskId: "0x939bceec9246a8c9ddb76aa07937b32d767f97ef91846c1ff28d6e96afdae9cd",
  taskKind: "0xc9e6d2fdcdd866ffc316ab98456f2ddaa565949a49c74b3866afccf3f8d96daa",
  taskKindName: "docs-review",
  evidenceRequirement: "0x26e2697356633bb0f5aede8e3740160536621b5f39c3fa17b0fbe3e8ebd40a34",
  evidenceRequirementName: "public",
  rewardToken: "0x0000000000000000000000000000000000000000",
  rewardAmount: 1000000000000000000n,
  deadlineBlock: 18000000n,
  taskStatus: "open",
  recentFailureCount: 0,
  humanReviewRequired: false,
});

const preview = client.previewStep({ agentId: agent.agentId, observation });
const submitted = client.step({
  agentId: agent.agentId,
  observation,
  expectedPreview: preview,
  expectedSequence: preview.sequence,
  maxValue: preview.maxValue,
});

const receipt = client.waitForStepReceipt(submitted.hash);
const replay = client.replayStep(receipt);
const view = client.getAgentMemoryView(agent.agentId);
```
