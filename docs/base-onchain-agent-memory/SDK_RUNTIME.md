# SDK and Runtime

## SDK objective

The SDK should make the agent memory state machine legible and safe:

- reads must be easy;
- previews must be clearly read-only;
- mutations must require explicit calls and limits;
- event decoding must preserve receipt metadata boundaries;
- replay helpers must expose enough evidence for reviewers and future agents.

The SDK is not a hidden off-chain runtime that decides actions and later stamps a hash on-chain. Its job is to prepare, preview, submit, decode, and replay deterministic contract behavior.

## Package shape

Recommended TypeScript package layout once implementation begins:

```text
services/flowmemory-agent-sdk/
  src/
    client.ts
    config.ts
    contracts.ts
    observations.ts
    preview.ts
    step.ts
    memory.ts
    replay.ts
    events.ts
    views.ts
    errors.ts
  test/
    client.test.ts
    preview.test.ts
    replay.test.ts
  README.md
```

If this is folded into an existing SDK package, keep the module boundary equivalent.

## Configuration

```ts
export type AgentMemorySdkConfig = {
  chainId: 8453 | 84532 | number;
  rpcUrl: string;
  contracts: {
    agentRegistry: `0x${string}`;
    memoryStore: `0x${string}`;
    stepRouter: `0x${string}`;
    flowPulse?: `0x${string}`;
  };
  mode: "local" | "base-sepolia" | "base-canary";
};
```

Rules:

- never persist RPC URLs or API keys in committed files;
- reject mismatched chain IDs;
- require explicit address configuration;
- keep canary/testnet modes separate from local fixture mode;
- do not default to a broad block scan.

## Core client API

```ts
const fixtureClient = new AgentMemoryClient({
  chainId: 84532,
  fixturePath: "fixtures/base-agent-memory/task-scout-v0.json",
});

const agent = fixtureClient.getAgent(agentId);
const memory = fixtureClient.getHotMemory(agentId);
const observation = fixtureClient.encodeTaskObservation(taskState);
const preview = fixtureClient.previewStep({ agentId, observation });
const tx = fixtureClient.step({
  agentId,
  observation,
  expectedPreview: preview,
  maxValue: preview.maxValue,
  expectedSequence: preview.sequence,
});
const receipt = fixtureClient.waitForStepReceipt(tx.hash);
const replay = fixtureClient.replayStep(receipt);
```

## Read-only APIs

### `getAgent`

Returns chain-side agent config:

```ts
type AgentConfig = {
  agentId: Hex32;
  owner: Address;
  kernel: Address;
  policyRoot: Hex32;
  toolAllowlistRoot: Hex32;
  latestMemoryRoot: Hex32;
  sequence: bigint;
  status: AgentStatus;
};
```

### `getHotMemory`

Returns current bounded working memory:

```ts
type HotMemoryView = {
  agentId: Hex32;
  latestMemoryRoot: Hex32;
  activeGoal: Hex32;
  lastActionReceiptId: Hex32;
  lastVerifierReportId: Hex32;
  sequence: bigint;
  failureCount: bigint;
  spendUsedThisEpoch: bigint;
};
```

### `getAgentMemoryView`

Returns a projected view from indexed data when available:

```ts
type AgentMemoryView = {
  agentId: Hex32;
  chainId: number;
  latestMemoryRoot: Hex32;
  sequence: bigint;
  hotMemory: HotMemoryView;
  recentTransitions: RootflowTransition[];
  verifiedMemory: MemoryCell[];
  pendingMemory: MemoryCell[];
  failedOrCorrectedMemory: MemoryCell[];
  nextActionPreview?: StepPreview;
};
```

If the view is fixture-backed, the SDK must label it as fixture-backed instead of implying live service state.

## Preview APIs

### `previewStep`

```ts
type PreviewStepInput = {
  agentId: Hex32;
  observation: EncodedObservation;
};


Current repo implementation path:
- `services/agent-memory-sdk/` provides two local/test task-scout SDK surfaces:
  - `AgentMemoryClient` for direct fixture-backed use;
  - `AgentMemoryRpcClient` for control-plane-backed local operator reads.
- `docs/base-onchain-agent-memory/SDK_REFERENCE.md` documents the exact current API.
type StepPreview = {
  agentId: Hex32;
  sequence: bigint;
  observationRoot: Hex32;
  action: AgentAction;
  toolId: Hex32;
  target: Address;
  selector: Hex4;
  callDataHash: Hex32;
  memoryDeltaRoot: Hex32;
  reasonCode: bigint;
  maxValue: bigint;
  previewHash: Hex32;
};
```

`previewStep` must use `eth_call` or an equivalent read-only local simulation. It must not send a transaction or alter memory.

## Mutation APIs

### `step`

```ts
type StepInput = {
  agentId: Hex32;
  observation: EncodedObservation;
  expectedPreview: StepPreview;
  expectedSequence: bigint;
  maxValue: bigint;
};

type SubmittedStep = {
  hash: Hex32;
  agentId: Hex32;
  expectedSequence: bigint;
  previewHash: Hex32;
};
```

`step` must require the caller to pass the expected preview and sequence. The SDK should not auto-refresh and silently submit a different action.

## Observation encoding

The first observation type should be task-scout focused.

```ts
type TaskObservation = {
  taskContract: Address;
  taskId: Hex32;
  taskKind: Hex32;
  rewardToken: Address;
  rewardAmount: bigint;
  evidenceRequirement: Hex32;
  deadline: bigint;
  sourceBlockNumber?: bigint;
};
```

Encoding output:

```ts
type EncodedObservation = {
  kind: "task";
  root: Hex32;
  encoded: Hex;
  fields: TaskObservation;
};
```

Rules:

- hash canonical fields, not display strings;
- include chain id or domain where replay risk exists;
- keep private evidence out of the observation unless explicitly committed;
- use existing crypto canonicalization helpers where possible.

## Event decoding

The SDK should decode:

- FlowPulse events;
- agent registered events;
- step committed events;
- action receipt events;
- memory committed events;
- pause/correction events when added.

Receipt metadata must come from the transaction receipt and log position, not from contract payload fields.

## Replay APIs

```ts
type ReplayTrace = {
  agentId: Hex32;
  chainId: number;
  transactionHash: Hex32;
  logIndex: number;
  parentMemoryRoot: Hex32;
  newMemoryRoot: Hex32;
  observationRoot: Hex32;
  kernelInputHash: Hex32;
  kernelOutputHash: Hex32;
  actionReceiptId: Hex32;
  verifierReportId?: Hex32;
  status: "pending" | "verified" | "failed" | "unresolved" | "unsupported" | "reorged";
  checks: ReplayCheck[];
};

type ReplayCheck = {
  name: string;
  status: "pass" | "fail" | "not_applicable";
  detail?: string;
};
```

Minimum replay helper:

```ts
const trace = await client.replayStep(receiptOrObservationId);
```

Replay must distinguish:

- contract state reconstruction;
- indexer receipt metadata;
- verifier status;
- off-chain evidence availability.

## Error model

Use explicit errors; do not collapse protocol failures into generic exceptions.

| Error | Meaning |
| --- | --- |
| `CHAIN_ID_MISMATCH` | RPC chain differs from config. |
| `AGENT_NOT_ACTIVE` | Agent is paused/finalized/failed. |
| `SEQUENCE_STALE` | Caller previewed an old state. |
| `PREVIEW_MISMATCH` | Submitted output differs from current kernel output. |
| `TOOL_NOT_ALLOWED` | Target/selector/tool id not allowed. |
| `CAP_EXCEEDED` | Action or epoch budget exceeded. |
| `MEMORY_PARENT_MISMATCH` | Parent root is not current root. |
| `EVIDENCE_UNAVAILABLE` | Off-chain committed evidence cannot be fetched. |
| `UNSUPPORTED_EVENT` | Event is valid but outside current decoder support. |
| `REORGED_OBSERVATION` | Prior receipt/log no longer canonical. |

## Example developer flow

```ts
import { AgentMemoryRpcClient } from "../../services/agent-memory-sdk/src/index.ts";

const client = new AgentMemoryRpcClient({
  chainId: 84532,
  rpcUrl: "http://127.0.0.1:8787/rpc",
});

const agent = await client.getAgent(agentId);
const observation = client.encodeTaskObservation(task);
const preview = await client.previewStep({ agentId, observation });

if (preview.action === "ACCEPT_TASK" && preview.maxValue === 0n) {
  const submitted = await client.step({
    agentId,
    observation,
    expectedPreview: preview,
    expectedSequence: preview.sequence,
    maxValue: preview.maxValue,
  });

  const receipt = await client.waitForStepReceipt(submitted.hash, agent.agentId);
  const trace = await client.replayStep(receipt, agent.agentId);
  console.log(trace.status);
}
```

## Runtime boundary

A runtime process may watch tasks and submit transactions, but it must not be the source of hidden agent decisions. Its responsibilities are operational:

- poll or subscribe to task state;
- call preview;
- apply local operator filters;
- submit transactions within configured limits;
- collect receipts;
- run replay and verifier checks;
- update dashboard files or APIs.

If a runtime chooses different actions than the chain-side preview, that is an off-chain operator policy decision and must be labeled as such.

## Documentation requirements for SDK release

Before exposing this SDK as a serious developer surface, provide:

- install instructions;
- local/test fixture command;
- contract address config format;
- no-secret environment guidance;
- preview vs mutation examples;
- event decoding examples;
- replay trace example;
- common errors table;
- version compatibility with contracts and schemas.
