# 2026-05-21 On-chain AI agents with on-chain memory

## Corrected intent

The stronger idea is not only “AI agents with off-chain memory commitments.” The target is closer to:

> AI agents that live on-chain, carry on-chain memory, and use blockchain infrastructure as their runtime: contracts for identity and policy, storage/data contracts for memory, events for observation, `eth_call` for free simulation, transactions for committed actions, and indexers/verifiers for replay.

This is closer to Quill than the earlier conservative framing. Quill proves a small fixed model can run as deterministic EVM computation with weights stored on-chain. The FlowMemory version can use the same discipline for agents: fixed bounded agent classes, compact on-chain memory, deterministic step functions, and public replay.

The key correction: FlowMemory can still keep heavy/private data off-chain when needed, but this idea intentionally includes a public on-chain memory layer. Anything stored there is public, durable, and expensive, so the memory has to be compressed, typed, and agent-useful.

## Related research

A full Nookplot research note now exists at `inbox/unsorted/2026-05-21-nookplot-agent-coordination-research.md`.

Nookplot validates the broader agent-coordination need: wallet/DID identity, reputation, bounties, marketplace escrow, skills, MCP, memory, mining, and knowledge attribution on Base. It also clarifies FlowMemory’s sharper wedge: contract-resident or root-committed on-chain memory transitions and deterministic replayable agent steps, not a broad social/economy network first.

## One-line idea

**On-chain AI agents with on-chain memory:** each agent is a smart-contract actor with a deterministic agent kernel, compact memory cells stored on-chain, and a replayable action loop that can observe chain state, recall memory, decide the next action, act through approved contract calls, and write new memory.

## What “on-chain AI agent” means here

An on-chain AI agent is not DeepSeek or Codex running in full on the EVM. That is not the right first target.

It is a bounded autonomous actor with:

1. **Identity**: an `AgentAccount` or contract address.
2. **Brain/kernel**: deterministic decision logic, possibly a tiny quantized model like Quill, a rule engine, or a fixed policy network.
3. **Memory**: public compact memory cells stored in contract storage, bytecode data contracts, roots, and event logs.
4. **Tools/actions**: allowlisted on-chain calls it can make.
5. **Budget/caps**: hard spend limits, rate limits, task limits, and emergency pause.
6. **Receipts**: every action and memory write emits replayable events.
7. **Verifier path**: indexers reconstruct what happened and whether it matched the agent policy.

Codex and DeepSeek are used to design, train, compress, audit, and deploy these agents. The deployed agent itself is on-chain.

## Existing blockchain infrastructure to use

This should use what already exists in EVM/Base-style infrastructure:

- contract storage for hot mutable state;
- event logs as the chronological memory/action journal;
- smart-contract bytecode/data contracts for cheap-ish immutable memory pages or tiny model weights;
- `eth_call` for free read-only simulation of the next step;
- transactions for committed state transitions;
- `CREATE2` for deterministic agent/memory addresses;
- ERC-20/ERC-721/ERC-1155/contract calls as tools;
- account or contract ownership for permissions;
- indexers for reconstruction;
- verifiers for policy/status checks;
- Rootfield/FlowPulse/Rootflow as the FlowMemory state spine.

## Agent loop

The core loop is:

```text
observe
-> recall
-> decide
-> act
-> write memory
-> emit receipt
-> index/replay
```

### 1. Observe

The agent can observe only on-chain facts directly:

- balances;
- contract state;
- events/logs indexed into memory;
- task/bond state;
- prior memory cells;
- verifier reports;
- Rootfield state.

Anything off-chain must enter through an explicit oracle, user submission, signed receipt, or committed evidence pointer. The agent should not pretend it knows external facts unless an on-chain source or receipt supports them.

### 2. Recall

The agent reads its on-chain memory:

- latest memory root;
- hot memory slots;
- compact facts;
- prior action receipts;
- open goals;
- failures/slashes;
- known constraints;
- verifier statuses.

Memory is not a normal vector database. It should be an on-chain memory graph / memory tape made of small typed records.

### 3. Decide

The agent kernel computes the next action deterministically.

Possible kernel classes:

1. **Rule agent**: if/then policy over memory and chain state.
2. **Scoring agent**: integer scoring over candidate actions and memory facts.
3. **Tiny model agent**: Quill-like int8 model with fixed dimensions and on-chain weights.
4. **Hybrid bounded agent**: rules gate a tiny model’s output.

The first serious design should prefer a hybrid bounded agent: rules enforce safety; tiny model/scoring logic helps rank actions or recall memory.

### 4. Act

The agent can only execute allowed actions:

- open task;
- accept task;
- commit evidence;
- update root;
- vote;
- transfer within cap;
- call allowlisted contracts;
- pay or slash through existing bond logic;
- emit FlowPulse.

Every action is a transaction or event with a receipt.

### 5. Write memory

After action, the agent writes a new compact memory cell or memory delta:

- what was observed;
- what decision was made;
- what action was taken;
- what outcome happened;
- what should be remembered next time.

This updates memory root/state and emits a FlowPulse/receipt.

### 6. Replay

Anyone can replay:

- agent state before step;
- memory read set;
- decision kernel;
- action output;
- memory write;
- emitted receipts.

That is the trust story: not “believe the agent,” but “recompute the agent.”

## On-chain memory design

### Memory should be typed

Do not store arbitrary chat logs as primary memory. Store typed records:

```text
MemoryCell
- memoryCellId
- agentId
- memoryType
- subject
- contentCommitment or short public content
- confidence/status
- parentMemoryRoot
- newMemoryRoot
- sourceReceiptRoot
- createdAt
- expiresAt or supersededBy
```

### Memory types

1. **Episodic memory**
   - prior actions;
   - task attempts;
   - transaction outcomes;
   - challenges;
   - failures.

2. **Semantic memory**
   - short public facts;
   - project rules;
   - known constraints;
   - approved claims;
   - rejected claims.

3. **Procedural memory**
   - tool permissions;
   - action policies;
   - safety gates;
   - spending limits.

4. **Goal memory**
   - active goals;
   - blocked goals;
   - next actions;
   - owner instructions.

5. **Scar tissue memory**
   - slashes;
   - failed actions;
   - reorged observations;
   - stale assumptions;
   - “never do this again” constraints.

### Hot/cold memory split

Use a two-tier memory layout:

#### Hot memory

Contract storage for current working state:

- current goal;
- latest memory root;
- active task id;
- active policy root;
- current nonce/sequence;
- spend used this epoch;
- small recent memory slots.

#### Cold memory

Append-only memory pages:

- event logs;
- SSTORE2-style data contracts;
- immutable bytecode pages;
- Merkleized memory archives;
- public short summaries.

The agent keeps hot state small and reads cold memory through roots/pages when needed.

### Public memory rule

If memory is truly on-chain, it is public. Therefore:

- never write private prompts unless public by intent;
- never write secrets;
- use short public memory summaries;
- use commitments for private or heavy evidence;
- make “public memory write” a deliberate action.

## On-chain brain design

### Class 1: rule kernel

A rule kernel is the safest first on-chain agent.

Example:

```text
if task.status == OPEN
and agent.reputation >= required
and budget.remaining >= maxCost
and memory.hasNoRecentFailure(task.kind)
then ACCEPT_TASK
else NOOP
```

This is not a full LLM, but it is a real autonomous on-chain agent.

### Class 2: scoring kernel

A scoring kernel ranks possible actions using integer weights:

```text
score(action) =
  w_goal * goalMatch
+ w_reward * expectedReward
- w_risk * riskScore
- w_failure * recentFailurePenalty
- w_budget * budgetCost
```

All inputs are on-chain or memory-derived. The highest valid action wins.

### Class 3: tiny neural kernel

A Quill-like tiny model can be used for bounded tasks:

- classify memory cell importance;
- rank next action candidates;
- choose whether to store or ignore an observation;
- map a compact observation vector to an action id;
- generate very short public memory labels.

Constraints:

- fixed architecture;
- int8 weights;
- small vocabulary or action space;
- deterministic greedy decode/classification;
- no unbounded text generation in the first version;
- rules must gate all external actions.

### Recommended first real target

Do not start with “chat agent on-chain.” Start with:

> an on-chain task agent that has public memory, can accept small on-chain tasks, remembers outcomes, updates its risk policy, and emits replayable receipts.

That is narrow enough to build and strong enough to prove the concept.

## Contract surface concept

This is conceptual, not an approved implementation.

### `OnchainAgentRegistry`

Registers agent identity and configuration:

```text
Agent
- agentId
- owner
- kernelClass
- kernelAddress
- memoryRoot
- policyRoot
- toolAllowlistRoot
- status
- nonce
```

### `AgentMemoryStore`

Stores hot memory and commits cold pages:

```text
commitMemoryDelta(agentId, parentRoot, deltaRoot, receiptRoot, uri)
readHotMemory(agentId)
latestMemoryRoot(agentId)
```

### `AgentKernel`

Shared deterministic engine:

```text
previewStep(agentId, observation) view returns (action, memoryDelta)
step(agentId, observation, maxCost) returns (actionReceipt, newMemoryRoot)
```

For tiny models, the kernel reads weights from data contracts, like Quill.

### `AgentToolRouter`

Executes only approved calls:

```text
execute(agentId, toolId, target, calldata, value)
```

Rules:

- target must be allowlisted;
- value must be capped;
- action must match kernel output;
- receipt emitted before/after call;
- failure becomes memory.

### FlowPulse integration

Use existing FlowPulse concepts before adding new types.

Possible later pulse types:

```text
AGENT_REGISTERED
AGENT_STEP_COMMITTED
AGENT_MEMORY_COMMITTED
AGENT_ACTION_EXECUTED
AGENT_MEMORY_CORRECTED
AGENT_PAUSED
```

But first local/test version can model these as Rootfield root commitments and task lifecycle pulses.

## How Codex and DeepSeek fit

### Codex as agent compiler

Codex helps create:

- agent policy;
- memory schema;
- action allowlist;
- tests;
- deployment script;
- fixtures;
- verifier rules;
- dashboard view.

Codex is not the deployed runtime. Codex is the factory engineer.

### DeepSeek as adversarial compiler/auditor

DeepSeek-style review tries to break:

- unsafe action routing;
- memory poisoning;
- prompt/summary leakage;
- over-broad allowlists;
- spend caps;
- stale memory;
- correction logic;
- owner/admin roles;
- liveness and griefing.

The review becomes an on-chain or committed audit/memory receipt only after reconciliation.

### Optional future: agents trained by off-chain models

DeepSeek/Codex can train or synthesize a small on-chain kernel:

```text
raw experience
-> off-chain model/compiler
-> compressed policy/weights
-> adversarial review
-> deployment as on-chain kernel/data
-> replayable on-chain execution
```

This keeps full LLMs off-chain while making the final deployed behavior on-chain.

## User experience

### Create agent

1. Choose agent class:
   - rule agent;
   - scoring agent;
   - tiny model agent.
2. Define purpose:
   - task taker;
   - verifier assistant;
   - treasury-safe operator;
   - memory curator;
   - governance watcher.
3. Define allowed tools and spend caps.
4. Generate policy/kernel with Codex.
5. Attack it with DeepSeek-style review.
6. Deploy registry entry, memory store, and kernel config.

### Run agent

1. Anyone calls `previewStep` through `eth_call`.
2. If output is safe/useful, anyone or an authorized keeper calls `step`.
3. The agent executes an allowed action.
4. The agent writes memory.
5. FlowPulse emits the state transition.
6. Indexer updates `AgentMemoryView`.

### Inspect agent

Dashboard shows:

- current memory root;
- hot memory slots;
- recent memories;
- active goals;
- allowed tools;
- last actions;
- failed actions;
- spend used;
- verifier status;
- replay button.

## Example agent

### Agent: on-chain task scout

Purpose:

- watches Agent Bond tasks;
- accepts only low-risk tasks;
- remembers failures;
- avoids task classes that caused slashing;
- escalates ambiguous tasks to a human or off-chain reviewer.

Memory:

```text
- task kind: docs-review, success count 8, fail count 1
- task kind: external-audit, unsupported without human review
- last slash reason: evidence unavailable
- budget remaining this epoch: 40 units
- current policy: conservative-v1
```

Decision:

```text
if task.kind == docs-review
and evidenceRequirement == public
and budgetRemaining > taskMaxCost
and recentFailureRate < threshold
then accept
else skip or escalate
```

After action:

```text
MemoryDelta
- accepted task 0x...
- reason: policy matched docs-review low-risk task
- budget remaining updated
- next review deadline stored
```

Everything is on-chain except any heavy supporting documents, which are referenced by commitment/URI.

## Why this is different from normal agent frameworks

Normal AI-agent systems:

- run on a server;
- keep private mutable memory;
- produce unverifiable outputs;
- lose continuity across runs;
- require trust in logs.

This design:

- gives the agent an on-chain identity;
- makes memory public and replayable when intentionally committed;
- makes the decision kernel deterministic;
- makes actions constrained by contracts;
- makes failures part of memory;
- lets future agents inherit a verified state.

## What should be on-chain vs off-chain

### On-chain

- agent id;
- policy root;
- tool allowlist root;
- current memory root;
- compact public memory cells;
- action receipts;
- verifier statuses;
- failure/correction records;
- small model weights if using tiny kernel;
- short public summaries when intentional.

### Off-chain or commitment-only

- full Codex/DeepSeek transcripts;
- private prompts;
- large documents;
- embeddings;
- vector indexes;
- screenshots/media;
- training data;
- full model checkpoints;
- private evidence.

## Hard boundaries

- Full DeepSeek/Codex-class LLM inference should not be the first on-chain target.
- On-chain memory is public; do not store secrets or private user memory.
- Agent actions must be allowlisted and capped.
- Tiny neural kernels must be deterministic and fixed-shape.
- Indexers derive receipt metadata; contracts do not know `txHash` or `logIndex` while executing.
- Do not introduce tokenomics just because Quill has tokenomics.
- Do not claim production trustlessness until replay/verifier paths are implemented and tested.

## MVP path

### MVP 0: concept fixture

Create one fixture for an on-chain task scout agent:

- agent config;
- hot memory;
- one observed task;
- deterministic decision;
- memory delta;
- FlowPulse-like receipt;
- reconstructed AgentMemoryView.

No new contracts yet.

### MVP 1: rule-based on-chain agent

Add a small local/test Solidity contract:

- register agent;
- store memory root;
- preview deterministic action;
- commit memory delta;
- emit FlowPulse.

No tiny neural model yet.

### MVP 2: memory store

Add on-chain hot memory plus append-only memory pages:

- memory cell writes;
- memory correction;
- root transitions;
- indexer reconstruction;
- dashboard view.

### MVP 3: tiny model kernel

Add Quill-like fixed-shape engine only for bounded classification/ranking:

- action scoring;
- memory importance scoring;
- no unconstrained free-text actions;
- all actions gated by rules.

### MVP 4: agent bond integration

Let agents accept/perform/challenge small bounded tasks through existing Agent Bonds surfaces.

This is where on-chain agents become economically meaningful, but only after safety gates exist.

## Smallest useful next step

Build a local/test fixture for one **on-chain task scout agent**:

1. agent identity/config;
2. public hot memory cells;
3. observed task input;
4. deterministic rule/scoring decision;
5. action receipt;
6. memory delta;
7. reconstructed `AgentMemoryView`.

Then compare it against existing `AgentAccount`, `MemoryCell`, `WorkReceipt`, `MemorySignal`, `MemoryReceipt`, `RootflowTransition`, and `AgentMemoryView` before adding any new contract surface.
