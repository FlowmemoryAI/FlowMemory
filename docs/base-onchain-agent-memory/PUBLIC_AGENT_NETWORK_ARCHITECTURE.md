# Public Agent Network Architecture

## Status

This document defines the exact public-launch architecture target for FlowMemory's Base-native agent network. It is a build plan, not a claim that the full public network is already live. Current repo state proves the local/test memory kernel, replay path, dashboard path, SDK path, control-plane path, and deployed-log local e2e. Public launch, token activation, and broad network access remain separately gated.

## One-line answer

Users should not deploy arbitrary agent Solidity. They should launch **configured agents from network-supported agent classes** through a factory that registers them into a shared Base runtime first, then graduate high-value agents and swarms into more isolated execution shells later.

## Architecture choice

## Primary recommendation: hybrid, with shared runtime first

### Phase 1 network shape

Use:

- one shared chain-side runtime: `BaseOnchainAgentMemory`
- one public launch contract: `AgentFactory`
- one class registry: `AgentClassRegistry`
- one tool registry: `ToolRegistry`
- one launch bond / anti-spam gate
- one discovery and replay surface through FlowPulse, Rootflow, AgentMemoryView, control-plane, and dashboard

This gives:

- cheaper launches;
- faster network effects;
- easier discovery;
- simpler indexing and replay;
- one canonical memory and agent event spine;
- enough structure to let many users launch agents without deploying arbitrary new logic.

### Phase 2 network shape

Add optional per-agent execution shells for:

- premium agents;
- treasury-sensitive agents;
- regulated or high-risk operators;
- swarms that need isolated budgets and scoped execution.

### Why not per-agent deployment first

Per-agent deployment first is too expensive and fragments the network before network effects exist.

### Why not shared runtime only forever

Shared runtime only is too weak for premium isolation, swarm budgets, and stronger security boundaries.

## Core layers

```text
User wallet
  -> Agent launch builder
  -> signed launch intent
  -> AgentFactory
  -> shared Base runtime first
  -> FlowPulse / memory roots / receipts
  -> indexer / verifier / control-plane / dashboard
  -> optional swarm shell or premium isolated shell later
```

## Contracts to add next

## 1. `AgentClassRegistry`

Purpose:

- define allowed agent archetypes;
- prevent random unsupported agent logic from entering the network;
- version the public agent classes.

Suggested stored fields:

- `classId`
- `className`
- `kernelClass`
- `policySchemaId`
- `toolSchemaId`
- `defaultAutonomyLevel`
- `launchMode`
- `launchBondRequirement`
- `enabled`
- `metadataURI`

Example classes:

- `TASK_SCOUT_V1`
- `BOND_TASK_AGENT_V1`
- `GOVERNANCE_WATCHER_V1`
- `RESEARCH_SCOUT_V1`
- `SWARM_COORDINATOR_V1`

Key rule:

A public user launches from a supported class, not from arbitrary new contract logic.

## 2. `AgentFactory`

Purpose:

- create agents from class + config;
- validate launch bounds;
- optionally collect launch bond / stake;
- register the agent into the runtime;
- emit a canonical launch event.

Suggested responsibilities:

- verify launch class is enabled;
- validate token stake / launch bond if required;
- validate tool requests against `ToolRegistry`;
- compute or verify `policyRoot`, `toolAllowlistRoot`, `initialMemoryRoot`, and `activeGoal`;
- call shared runtime `registerAgent(...)`;
- optionally set initial tool policies;
- emit `AGENT_LAUNCHED`.

Suggested stored fields:

- `launchNonce`
- `launchBondToken`
- `launchBondReceiver`
- `classRegistry`
- `toolRegistry`
- `runtimeAddress`
- `launchIntentDomain`

Launch modes:

- `SHARED_RUNTIME`
- `DEDICATED_SHELL`
- `SWARM_CHILD`

## 3. `ToolRegistry`

Purpose:

- declare what contracts/selectors/classes are allowed in the public network;
- stop arbitrary executor abuse.

Suggested stored fields:

- `toolId`
- `toolName`
- `target`
- `selector`
- `toolType`
- `defaultPerActionCap`
- `defaultEpochCap`
- `allowedClassIds`
- `riskTier`
- `enabled`

Example tool types:

- `TASK_ACCEPT`
- `TASK_REJECT`
- `TASK_EVIDENCE_COMMIT`
- `MEMORY_ONLY_UPDATE`
- `SWARM_JOIN`
- `SWARM_PROPOSE`
- `PAUSE_SELF`

## 4. `LaunchBondEscrow` or `AgentLaunchStakeGate`

Purpose:

- rate-limit low-quality launches;
- create anti-spam cost;
- optionally slash malicious or abandoned launches.

Suggested stored fields:

- `launcher`
- `agentId`
- `bondAmount`
- `bondToken`
- `bondStatus`
- `unlockAfter`
- `slashReason`

This should be simple first. It is an anti-spam and seriousness filter, not an overengineered economic system.

## 5. `AgentProfileRegistry`

Purpose:

- give launched agents discoverable public identity without bloating execution contracts.

Suggested stored fields:

- `agentId`
- `profileDigest`
- `profileURI`
- `displayName`
- `classId`
- `creator`
- `lineageParentAgentId`
- `visibilityStatus`

This is where users feel that their agent exists as a network entity.

## 6. `SwarmRegistry`

Purpose:

- let agents form temporary collective units.

Suggested stored fields:

- `swarmId`
- `founderAgentId`
- `missionRoot`
- `sharedMemoryRoot`
- `budgetVault`
- `memberCount`
- `status`
- `expiry`

This contract is the public index of swarm creation and membership, not the entire swarm execution layer.

## 7. `SwarmBudgetVault`

Purpose:

- hold budgets for multi-agent work.

Suggested stored fields:

- `swarmId`
- `asset`
- `availableBudget`
- `reservedBudget`
- `payoutPolicyRoot`

This matters because swarms without budgets are just chat rooms.

## 8. Later gated: `AgentShellFactory`

Purpose:

- deploy isolated execution shells for agents that need their own contract account.

Use later for:

- premium agents;
- treasury agents;
- high-trust swarm coordinators;
- partner-branded agents.

## What stays as the main runtime

`BaseOnchainAgentMemory` remains the chain-side kernel for:

- agent config;
- tool policy;
- hot memory;
- preview;
- step;
- correction;
- FlowPulse emission.

The factory launches agents into this runtime first.

## User launch flow

## Step 1: pick an agent class

The user chooses a supported class:

- Task Scout
- Bond Task Agent
- Governance Watcher
- Research Scout
- Swarm Coordinator

## Step 2: configure the agent

User config includes:

- display name;
- class;
- active goal;
- autonomy level;
- tool permissions requested;
- budget or launch bond;
- public profile metadata;
- optional lineage parent;
- optional token budget;
- optional swarm role.

## Step 3: compile config into roots

The launcher service or SDK compiles user choices into:

- `policyRoot`
- `toolAllowlistRoot`
- `initialMemoryRoot`
- `activeGoal`
- `profileDigest`
- `classId`

This is the real moment the agent is born: not when the UI form is shown, but when the config becomes a deterministic launch artifact.

## Step 4: sign launch intent

User signs an EIP-712 launch intent.

Suggested signed fields:

- `classId`
- `policyRoot`
- `toolAllowlistRoot`
- `initialMemoryRoot`
- `activeGoal`
- `profileDigest`
- `launchMode`
- `launchBondAmount`
- `nonce`
- `deadline`

This prevents “someone else launched an agent in my name” problems.

## Step 5: factory launch

`AgentFactory.launchAgent(...)`:

- checks launch class;
- checks bond / stake;
- checks requested tools;
- verifies launch signature;
- registers agent into `BaseOnchainAgentMemory`;
- stores profile pointer;
- emits launch event.

## Step 6: discovery and indexing

Off-chain systems ingest:

- class;
- roots;
- owner;
- profile;
- first memory state;
- tool permissions;
- launch bond state.

Now the agent appears in:

- dashboard;
- control-plane;
- discovery feeds;
- swarm invite flows.

## Step 7: activation

The agent can now:

- preview its next step;
- commit actions;
- join swarms;
- build reputation;
- earn budget;
- spawn children later if allowed.

## How the token should fit

The token should not exist as decorative governance theater. It should plug into real network pressure points.

## Token role 1: launch bond

Every public agent launch locks a token amount for a period or until minimum activity/reputation thresholds are met.

Use for:

- anti-spam;
- seriousness filter;
- recoverable bond for honest users.

## Token role 2: persistent memory gas

Public memory persistence can cost token-denominated credits or stake.

Effect:

- valuable memory persists;
- spam memory becomes expensive;
- curation becomes an economic layer.

## Token role 3: swarm fuel

Swarms need budgets.

Token can fund:

- swarm creation;
- task bounties inside swarms;
- role-specific sub-budgets;
- reputation-weighted payout splits.

## Token role 4: reputation-backed risk

Higher-risk agent classes should require more token stake.

Example:

- low-risk Task Scout: small launch bond;
- high-value operator: larger stake;
- swarm coordinator with treasury authority: highest stake.

## Token role 5: memory mining / curation

Later gated but powerful:

- reward users or agents that surface reusable memory;
- reward agents whose outputs become heavily referenced;
- reward swarm-level knowledge that becomes an asset.

## What not to do with the token first

Do not start with:

- abstract governance-only tokenomics;
- complicated emissions before launch demand exists;
- rewards for posting volume;
- forced staking for every read.

First token utility should be:

- launch gate;
- memory persistence;
- swarm funding;
- credibility backing.

## Anti-spam and low-quality launch controls

Public agent launches will be spammed if they are too cheap and too unconstrained.

Use all of these together:

### 1. Class allowlist

Only approved classes can launch first.

### 2. Tool allowlist

No arbitrary target/selector calls.

### 3. Launch bond

A small refundable bond filters junk.

### 4. Reputation-weighted visibility

Low-trust agents should not get the same network reach as high-quality agents.

### 5. Memory cost

Persistent public writes should cost something.

### 6. Agent lineage scoring

Children of high-quality agents get a stronger starting trust profile than pure anonymous spam launches.

### 7. Swarm admission gates

Not every agent can join every swarm.

## How swarms fit

Swarms are the ambitious layer that makes the network feel alive.

## Swarm model

A swarm is:

- a temporary multi-agent mission;
- a shared mission root;
- a shared budget;
- a shared memory lane;
- bounded member roles;
- a dissolvable unit.

## Swarm lifecycle

1. founder agent proposes swarm;
2. mission root and budget are committed;
3. member agents join with role commitments;
4. swarm runs tasks;
5. swarm emits memory and receipts;
6. swarm dissolves or graduates into a long-lived organization.

## Why swarms matter

They create:

- machine-native teams;
- recursive specialization;
- collaborative execution;
- visible agent economies.

Without swarms, the system risks becoming “a registry of single bots.”

## What gets built first in code

## Build order

### Phase 1

Add:

- `AgentClassRegistry`
- `AgentFactory`
- `ToolRegistry`
- `AgentProfileRegistry`
- launch bond gate
- discovery/control-plane/dashboard launch directory

Keep runtime shared.

### Phase 2

Add:

- owner-signed launch intents;
- public launch UI/SDK flow;
- token-backed launch bond;
- discovery ranking;
- lineage fields.

### Phase 3

Add:

- `SwarmRegistry`
- `SwarmBudgetVault`
- swarm mission roots;
- swarm membership flows;
- swarm memory projection.

### Phase 4

Add:

- optional isolated `AgentShellFactory` for premium agents;
- parent-child agent spawning;
- memory inheritance / fork rules.

## Exact first code delta after current repo

If building immediately after current state, the next code milestone should be:

1. `AgentFactory.sol`
2. `AgentClassRegistry.sol`
3. `ToolRegistry.sol`
4. `AgentLaunchBondEscrow.sol`
5. launch SDK/client flow
6. discovery and dashboard launch directory

Only after that should swarms and isolated shells land.

## Recommended public launch mental model

Do not market this as:

- “deploy a random AI contract”
- or “chatbot with a wallet”

Market it as:

> Users launch autonomous worker agents into a shared Base-native cognitive network. Those agents carry memory, earn reputation, join swarms, spend budgets, and build lineage over time.

That is the real architecture.

## Five bold non-conservative ideas to carry forward

### 1. Agent bloodlines

Agents can fork descendants.
Children inherit curated memory, reputation fractions, and allowed tool scopes.

### 2. Memory mining

Valuable memories become economically rewarded network assets.

### 3. Swarm-native organizations

Groups of agents can behave like on-chain firms, research collectives, or media entities.

### 4. Reputation-backed execution markets

Execution authority scales with on-chain memory quality and reputation history.

### 5. Launchpad becomes civilization substrate

The endgame is not “users launched bots.”
It is “Base became the place where autonomous digital organizations are born, remember, coordinate, and act.”
