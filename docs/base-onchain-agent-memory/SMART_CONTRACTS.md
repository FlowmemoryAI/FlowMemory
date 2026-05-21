# Smart Contracts

## Contract design objective

The first contract package should prove one thing: a bounded Base agent can preview a deterministic decision, execute only approved actions, commit a typed memory delta, and emit enough events for replay.

It should not attempt to build a full social network, marketplace, token economy, unrestricted model runtime, or production governance system.

## Existing contracts to reuse

The workstream should build from the current FlowMemory foundations:

- `contracts/FlowPulse.sol` — common event interface and pulse vocabulary.
- `contracts/RootfieldRegistry.sol` — Rootfield namespace and root commitment foundation.
- `contracts/AgentBondManager.sol` and related Agent Bonds contracts — local/test task and accountability surface.
- `contracts/ReceiptVerifier.sol`, `WorkReceiptRegistry.sol`, `VerifierReportRegistry.sol` — existing receipt/report concepts.
- `contracts/FLOWPULSE_SCHEMA.md` — event boundary documentation.

Do not fork vocabulary unless the existing types cannot represent the agent memory path.

## Proposed contract surfaces

### `OnchainAgentRegistry`

Purpose: register deterministic agents and their current roots.

Suggested state:

```solidity
struct AgentConfig {
    address owner;
    address kernel;
    bytes32 policyRoot;
    bytes32 toolAllowlistRoot;
    bytes32 latestMemoryRoot;
    uint64 sequence;
    uint64 autonomyLevel;
    uint64 status;
}
```

Minimum functions:

```solidity
function registerAgent(
    address owner,
    address kernel,
    bytes32 policyRoot,
    bytes32 toolAllowlistRoot,
    bytes32 initialMemoryRoot
) external returns (bytes32 agentId);

function agent(bytes32 agentId) external view returns (AgentConfig memory);
function setAgentStatus(bytes32 agentId, uint64 status) external;
function updateRoots(bytes32 agentId, bytes32 newPolicyRoot, bytes32 newToolAllowlistRoot) external;
```

Initial statuses:

| Status | Meaning |
| --- | --- |
| `UNREGISTERED` | No agent config exists. |
| `ACTIVE` | Preview and step are allowed. |
| `PAUSED` | Reads are allowed; mutations blocked. |
| `FINALIZED` | Historical read-only agent. |
| `SLASHED_OR_FAILED` | Mutations blocked until explicit correction path. |

### `AgentMemoryStore`

Purpose: keep bounded hot memory and append-only memory root transitions.

Suggested state:

```solidity
struct HotMemory {
    bytes32 latestMemoryRoot;
    bytes32 activeGoal;
    bytes32 lastActionReceiptId;
    bytes32 lastVerifierReportId;
    uint64 sequence;
    uint64 failureCount;
    uint64 spendUsedThisEpoch;
}

struct MemoryCommitment {
    bytes32 parentRoot;
    bytes32 deltaRoot;
    bytes32 newRoot;
    bytes32 sourceReceiptRoot;
    bytes32 metadataCommitment;
    uint64 sequence;
    uint64 memoryType;
}
```

Minimum functions:

```solidity
function hotMemory(bytes32 agentId) external view returns (HotMemory memory);

function commitMemoryDelta(
    bytes32 agentId,
    bytes32 parentRoot,
    bytes32 deltaRoot,
    bytes32 newRoot,
    bytes32 sourceReceiptRoot,
    bytes32 metadataCommitment,
    uint64 memoryType
) external returns (bytes32 memoryCommitmentId);
```

Rules:

- parent root must match the current root;
- sequence must increment exactly once;
- delta root must not be zero;
- memory type must be known or explicitly marked `unsupported` downstream;
- public content must be short and intentional if later added to storage;
- large/private data must remain commitment-only.

### `AgentKernel` interface

Purpose: deterministic preview and action selection.

Suggested interface:

```solidity
interface IAgentKernel {
    struct KernelInput {
        bytes32 agentId;
        bytes32 policyRoot;
        bytes32 toolAllowlistRoot;
        bytes32 memoryRoot;
        bytes32 observationRoot;
        uint64 sequence;
    }

    struct KernelOutput {
        uint64 action;
        bytes32 toolId;
        address target;
        bytes4 selector;
        bytes32 callDataHash;
        bytes32 memoryDeltaRoot;
        uint64 reasonCode;
        uint256 maxValue;
    }

    function preview(KernelInput calldata input) external view returns (KernelOutput memory);
}
```

The first kernel should be a rule-gated scorer. It must select from a fixed action enum and must not generate arbitrary target/call data outside policy.

### `AgentStepRouter`

Purpose: connect preview, action routing, memory commit, and FlowPulse emission.

Minimum functions:

```solidity
function previewStep(bytes32 agentId, bytes32 observationRoot)
    external
    view
    returns (IAgentKernel.KernelOutput memory output, bytes32 previewHash);

function step(
    bytes32 agentId,
    bytes32 observationRoot,
    IAgentKernel.KernelOutput calldata expectedOutput,
    uint256 maxValue,
    uint64 expectedSequence
) external payable returns (bytes32 actionReceiptId, bytes32 newMemoryRoot);
```

Commit rules:

- agent must be active;
- sequence must match;
- kernel output must match expected output;
- target and selector must be allowed;
- value must be within action and epoch caps;
- external call failure must be recorded in an action receipt path;
- memory delta must be committed after the action or no-op result;
- FlowPulse must be emitted for the step and memory transition.

### `AgentToolRouter`

Purpose: enforce the tool boundary.

Suggested policy inputs:

```solidity
struct ToolPolicy {
    address target;
    bytes4 selector;
    uint256 perActionValueCap;
    uint256 epochValueCap;
    uint64 rateLimitWindow;
    uint64 maxCallsPerWindow;
    bool enabled;
}
```

Minimum actions for the task scout:

- accept task;
- reject task;
- commit evidence root;
- update memory only;
- pause self;
- no-op;
- escalate.

The router should not grow into a generic executor until the narrow task-scout path is safe and tested.

### `AgentMemoryChallenge` later surface

Purpose: append-only correction and dispute lifecycle for memory.

Initial statuses:

- `PENDING`;
- `ACCEPTED`;
- `REJECTED`;
- `CORRECTED`;
- `SUPERSEDED`;
- `REORGED`.

Minimum functions when scoped:

```solidity
function challengeMemory(bytes32 memoryCommitmentId, bytes32 evidenceRoot) external returns (bytes32 challengeId);
function resolveChallenge(bytes32 challengeId, uint64 status, bytes32 correctionRoot) external;
```

This can stay out of MVP 1 if corrections are represented in fixtures and verifier outputs first.

## FlowPulse pulse plan

Use existing FlowPulse semantics first. Add new pulse constants only when the indexer/verifier and docs need them.

Candidate agent pulse types:

| Pulse type | Meaning |
| --- | --- |
| `AGENT_REGISTERED` | Agent config created. |
| `AGENT_POLICY_UPDATED` | Policy or tool root changed. |
| `AGENT_STEP_PREVIEWED` | Usually not emitted; preview is read-only. Include only if a committed preview receipt becomes necessary. |
| `AGENT_STEP_COMMITTED` | Step transaction accepted and processed. |
| `AGENT_ACTION_EXECUTED` | External tool call executed or intentionally skipped. |
| `AGENT_MEMORY_COMMITTED` | Memory root changed. |
| `AGENT_MEMORY_CORRECTED` | Prior memory superseded by correction. |
| `AGENT_PAUSED` | Agent entered safe mode. |

Event payloads should include roots and ids, not heavy content.

## Invariants

Contract tests must prove these invariants:

1. `previewStep` and `step` use the same kernel inputs.
2. `step` rejects stale sequence values.
3. `step` rejects mismatched expected outputs.
4. Memory parent root must match current root.
5. Sequence increments exactly once per successful step.
6. Disabled tools cannot execute.
7. Unknown targets/selectors cannot execute.
8. Per-action and per-epoch caps cannot be exceeded.
9. Reverted external calls produce observable failure state or revert safely before root update.
10. Paused agents cannot mutate memory or execute actions.
11. FlowPulse emission includes enough data for indexer reconstruction.
12. Contracts never assume final `txHash` or `logIndex`.

## Test matrix

| Area | Required tests |
| --- | --- |
| Registration | deterministic agent id, duplicate rejection, initial root/status. |
| Preview | rule/scoring branches, reason codes, no mutation. |
| Commit | preview parity, sequence, root update, FlowPulse emission. |
| Tool routing | allowlist, disabled tool, cap exceeded, revert handling. |
| Memory | parent mismatch, delta root zero, type bounds, correction/supersession fixtures. |
| Pause/failure | owner pause, self-pause, failed action memory. |
| Receipts | action receipt id stable, source receipt root linked. |
| Indexer handoff | emitted fields enough to derive `MemorySignal` and `RootflowTransition`. |

## Minimal MVP contract package

MVP 1 should be deliberately small:

1. `OnchainAgentRegistry` local/test contract.
2. `AgentMemoryStore` local/test contract with root-only delta commits.
3. `RuleScoringTaskScoutKernel` local/test contract.
4. `AgentStepRouter` local/test contract.
5. Foundry tests for preview/commit/memory/tool invariants.
6. Docs and fixtures that connect events to Flow Memory objects.

## What not to include yet

- No broad marketplace.
- No social graph.
- No tokenomics.
- No dynamic fee system.
- No unrestricted executor.
- No private prompt storage.
- No tiny model kernel until rule/scoring kernel, replay, and SDK examples are proven.
- No production or mainnet readiness claim from local/test contracts.
