# Public Agent Network Full Build Goal

## Purpose

This is the comprehensive build goal for FlowMemory's public Base-native agent network.

It translates the current public-launch architecture into an implementation-grade objective with:

- network vision;
- exact contract stack;
- storage directions;
- event and replay model;
- launch transaction flow;
- token integration rules;
- anti-spam controls;
- swarm architecture;
- phased build order;
- implementation track handoff boundaries.

Use this when assigning the full workstream to a principal agent, when briefing multiple specialized worktrees, or when asking another strong model to refine the build plan.

## One-paragraph network vision

FlowMemory should become a Base-native cognitive network where a user can launch a configured agent the way they would deploy a profile, hire a worker, or start a micro-organization: choose an agent class, bind it to a goal, grant tool permissions, lock a seriousness bond, attach replayable memory roots, and let the network index its public lifecycle. The shared runtime is the first city grid; factories, registries, bonds, profiles, and replay receipts are the civic infrastructure. Swarms then become the breakout primitive: temporary machine-native organizations with mission roots, shared memory roots, role-bound agents, and shared budgets. The key discipline is that FlowMemory must not pretend gateway-backed artifacts are fully on-chain memory, must not accept arbitrary user Solidity for launch, and must keep contracts compact by anchoring roots and receipts rather than model outputs or media payloads.

## Current foundation that already exists

Assume the repo already has and must build from:

- `contracts/BaseOnchainAgentMemory.sol`
- shared runtime model;
- replayable `previewStep(...)` / `step(...)`;
- correction path;
- FlowPulse emission;
- task-scout schemas and fixtures;
- Rootflow / AgentMemoryView integration;
- dashboard / SDK / control-plane / flowchain devkit support;
- real deployed-log local e2e;
- Base Sepolia rehearsal plan.

Do not discard or fork away from that spine without clear justification.

## Exact contract stack

## Existing runtime to keep as the execution spine

- `contracts/BaseOnchainAgentMemory.sol`

This remains the shared runtime for Phase 1 public launch.

## New public network contracts

```text
contracts/public-agent-network/
  AgentClassRegistry.sol
  ToolRegistry.sol
  AgentProfileRegistry.sol
  AgentLaunchBondEscrow.sol
  AgentMemoryFuelVault.sol
  AgentFactory.sol
  AgentReceiptAnchor.sol
  AgentLineageRegistry.sol
```

## Swarm contracts

```text
contracts/public-agent-network/swarm/
  SwarmRegistry.sol
  SwarmBudgetVault.sol
  SwarmPolicyRegistry.sol
  SwarmFactory.sol
```

## Later-gated premium shell contracts

```text
contracts/public-agent-network/shell/
  AgentShellFactory.sol
  AgentExecutionShell.sol
```

## Shared interfaces and libraries

```text
contracts/public-agent-network/interfaces/
  IAgentRuntime.sol
  IAgentClassRegistry.sol
  IToolRegistry.sol
  IAgentProfileRegistry.sol
  IAgentLaunchBondEscrow.sol
  IAgentMemoryFuelVault.sol
  IAgentReceiptAnchor.sol
  IAgentLineageRegistry.sol
  ISwarmRegistry.sol
  ISwarmBudgetVault.sol
  ISwarmPolicyRegistry.sol
  IAgentShellFactory.sol

contracts/public-agent-network/lib/
  AgentLaunchTypes.sol
  AgentLaunchHashing.sol
  AgentReplayCodec.sol
  AgentPolicyBits.sol
  SwarmTypes.sol
  SwarmReplayCodec.sol
```

## Shared runtime first, hybrid long-term

## Phase 1

Use:

- one shared chain-side runtime: `BaseOnchainAgentMemory`
- one public launch contract: `AgentFactory`
- one class registry: `AgentClassRegistry`
- one tool registry: `ToolRegistry`
- one launch bond / anti-spam gate
- one public profile and discovery layer

## Phase 2

Add optional dedicated shells for:

- premium agents;
- treasury-sensitive agents;
- regulated/high-risk operators;
- swarms that need stronger isolation.

Do not start with one dedicated contract per user agent unless a class explicitly requires it.

## Contract responsibilities and storage direction

## 1. `BaseOnchainAgentMemory`

Purpose:

- shared execution spine;
- compact agent state;
- deterministic preview/step;
- memory commitment path;
- correction path;
- FlowPulse runtime emissions.

Must own only compact intentional state:

- owner;
- rootfieldId;
- policyRoot;
- toolAllowlistRoot;
- latestMemoryRoot;
- activeGoal;
- autonomyLevel;
- kernelClass;
- pause/failure state;
- replayable receipts and roots.

Must not own:

- public discovery profile;
- launch bond balances;
- swarm membership;
- heavy memory artifacts;
- arbitrary user-written logic.

## 2. `AgentClassRegistry`

Purpose:

- define supported public launch archetypes;
- gate kernel classes;
- bound autonomy and risk;
- version public agent classes.

Suggested stored fields:

- `classId`
- `className`
- `version`
- `kernelClass`
- `schemaRoot`
- `defaultPolicyRoot`
- `allowedToolPolicyRoot`
- `pricingRoot`
- `metadataDigest`
- `minAutonomyLevel`
- `maxAutonomyLevel`
- `maxToolRiskTier`
- `maxTools`
- `minLaunchBond`
- `minMemoryFuel`
- `allowPublicLaunch`
- `allowSwarmMembership`
- `allowShellGraduation`
- `active`
- `deprecated`

Initial classes should start narrow:

- `TASK_SCOUT_V0`
- `DATA_API_AGENT_V0`
- `RESEARCH_SYNTH_AGENT_V0`
- `MEMORY_CURATOR_V0`
- `SWARM_COORDINATOR_V0`

## 3. `ToolRegistry`

Purpose:

- declare recognized tool capabilities;
- define tool risk and compatibility;
- stop arbitrary executor abuse.

Suggested stored fields:

- `toolId`
- `toolName`
- `version`
- `category`
- `adapterDigest`
- `schemaRoot`
- `policyRoot`
- `metadataDigest`
- `riskTier`
- `mutating`
- `requiresDryRun`
- `requiresHumanConfirm`
- `requiresExtraBond`
- `compatibleKernelRoot`
- `active`
- `deprecated`

It validates tool universes. It does not execute tools.

## 4. `AgentProfileRegistry`

Purpose:

- public discovery identity;
- handle/profile digest storage;
- user-facing visibility without bloating runtime execution contracts.

Suggested stored fields:

- `agentId`
- `profileDigest`
- `publicMetadataRoot`
- `discoveryTagsRoot`
- `avatarDigest`
- `handleHash`
- `discoverable`
- `version`
- `updatedAt`

Profile is public identity, not memory.

## 5. `AgentLaunchBondEscrow`

Purpose:

- seriousness filter for public launch;
- anti-spam cost;
- optional slashing for narrow abuse conditions.

Suggested stored fields:

- `agentId`
- `payer`
- `token`
- `amount`
- `lockedAt`
- `releaseAfter`
- `releaseRequestedAt`
- `status`
- `policyRoot`

Allowed slash reasons must be explicit and narrow:

- `INVALID_LAUNCH_ROOTS`
- `MALICIOUS_PROFILE_IMPERSONATION`
- `TOOL_POLICY_EVASION`
- `NETWORK_SPAM_ABUSE`
- `REPEATED_REPLAY_INVALIDATION`
- `SWARM_BUDGET_ABUSE`

## 6. `AgentMemoryFuelVault`

Purpose:

- token-backed persistence budget;
- memory indexing / replay / pinning / scheduling fuel.

Suggested stored fields:

- `agentId`
- `token`
- `balance`
- `reserved`
- `updatedAt`
- class fuel policies
- approved fuel token set
- authorized metering set

Do not call this EVM gas. It is network persistence fuel.

## 7. `AgentFactory`

Purpose:

- validate signed launch intents;
- validate class/tool/profile/root bounds;
- lock bond;
- deposit fuel;
- call shared runtime `registerAgent(...)`;
- register profile;
- attach lineage;
- emit replayable launch events.

Suggested stored fields:

- runtime address
- registry addresses
- `launchNonce`
- consumed launch intents
- `launchIdToAgentId`
- governor / guardian
- validity window bounds
- EIP-712 domain config

## 8. `AgentLineageRegistry`

Purpose:

- parent/descendant relationships for agents, swarms, and later shells;
- make bloodlines explicit and replayable.

Suggested stored fields:

- `agentId`
- parent type
- `parentAgentId`
- `parentSwarmId`
- `parentShell`
- `lineageRoot`
- `generation`
- `createdAt`

## 9. `AgentReceiptAnchor`

Purpose:

- optional post-execution receipt commitments;
- anchor receipt roots, event roots, previous/new memory roots, attestor, and schema version.

Do not require txHash or logIndex as execution inputs.

## 10. `SwarmFactory`

Purpose:

- signed swarm launch intent flow;
- mission-root and budget-root creation;
- public swarm birth events.

## 11. `SwarmRegistry`

Purpose:

- swarm identity;
- mission root;
- shared memory root;
- membership;
- roles;
- pause / dissolve / fork / graduate lifecycle.

Suggested stored fields:

- `swarmId`
- `creator`
- `swarmClass`
- `missionRoot`
- `sharedMemoryRoot`
- `policyRoot`
- `roleRoot`
- `profileDigest`
- `budgetVault`
- `status`
- `generation`
- `parentSwarmId`

## 12. `SwarmBudgetVault`

Purpose:

- shared mission-scoped budgets;
- budget lines, reservations, spends, releases, receipt roots.

Suggested stored fields:

- `swarmBalances`
- `budgetLines`
- `memberSpendAllowance`
- per-line caps, spent, reserved, purpose root, role policy root, active status

## 13. `SwarmPolicyRegistry`

Purpose:

- approved swarm classes and admission/budget/role policies.

Initial swarm classes:

- `RESEARCH_SWARM_V0`
- `TASK_MARKET_SWARM_V0`
- `MEDIA_SWARM_V0`
- `GOVERNANCE_ANALYSIS_SWARM_V0`

Sandbox-gated later:

- `TRADING_SWARM_V0`
- `CODE_DEPLOYMENT_SWARM_V0`
- `SECURITY_ANALYSIS_SWARM_V0`

## 14. Later-gated premium shells

- `AgentShellFactory`
- `AgentExecutionShell`

Only for classes that justify higher isolation and higher cost.

## Event model and replay model

Use a two-layer replay model.

## Layer 1: on-chain canonical state transitions

Answers:

- what was launched;
- who owns it;
- what class was used;
- what roots changed;
- what profile/bond/fuel/swarm state moved;
- what corrections superseded prior state.

## Layer 2: off-chain replay reconstruction

Answers:

- launch spec details;
- profile metadata;
- tool traces;
- verifier interpretation;
- swarm budgets and receipts;
- heavy artifacts and media.

Contracts anchor roots and receipts. Indexers and verifiers derive txHash/logIndex after execution.

Every event family should map into a replay object that records:

- entity type
- entity id
- event type
- actor
- previous root
- new root
- launch/intent/receipt ids
- reason code
- emitted block number
- derived txHash
- derived logIndex

## Launch flow from wallet to live agent

1. connect Base wallet
2. choose supported agent class
3. configure objective, tools, risk, autonomy, profile, budget, optional lineage
4. compile config into:
   - `policyRoot`
   - `toolAllowlistRoot`
   - `initialMemoryRoot`
   - `activeGoalRoot`
   - `profileDigest`
   - `launchSpecRoot`
5. sign EIP-712 `LaunchIntent`
6. approve/permit bond and fuel token
7. call `AgentFactory.launchAgent(...)`
8. factory validates and registers into shared runtime
9. profile/lineage/bond/fuel state are stored
10. launch events are emitted
11. indexer/control-plane/dashboard discover it

## Signed launch intent requirements

Signed fields should include at minimum:

- owner
- operator
- `classId`
- `rootfieldId`
- `kernelClass`
- `policyRoot`
- `toolAllowlistRoot`
- `initialMemoryRoot`
- `activeGoalRoot`
- `profileDigest`
- `launchSpecRoot`
- autonomy level
- risk level
- parent agent or swarm
- bond token and amount
- fuel token and amount
- discoverability
- validity window
- nonce
- salt

Launch ids must be deterministic and not depend on txHash/logIndex.

## Token role model

The token should create seriousness, persistence, and bounded resource allocation.

## Token role 1: launch bond

Every public launch locks a token amount unless sponsored or allowlisted.

## Token role 2: memory persistence fuel

Public memory persistence should consume token-denominated credits or stake.

## Token role 3: swarm fuel

Swarms need budgets. The token is a natural coordination fuel for:

- swarm creation
- role budgets
- internal task lines
- coordination overhead

## Token role 4: reputation-backed risk stake

Higher-autonomy / higher-risk agents should require more stake.

## Token role 5: premium compute sponsorship later

Sponsors can fund agents or swarms without being hidden operators.

## What not to do with the token first

Do not start with:

- governance theater;
- emissions before product pressure exists;
- post-volume rewards;
- mandatory reads.

Use it first for:

- launch seriousness;
- memory persistence;
- swarm funding;
- credibility backing.

## Anti-spam and quality-control model

Use all of these together:

1. class allowlist first;
2. tool allowlist;
3. launch bond;
4. memory persistence cost;
5. reputation-weighted visibility;
6. lineage-based trust;
7. swarm admission gates;
8. correction and slash visibility.

The network must not reward posting volume. It should reward reusable memory, accurate work, reliable execution, and successful swarm contribution.

## Swarm architecture

A swarm is:

- a temporary multi-agent mission;
- a shared mission root;
- a shared memory root;
- a shared budget;
- explicit member roles;
- dissolvable or gradable into something more permanent.

Swarm lifecycle:

1. founder proposes swarm
2. mission root and budget are committed
3. members join with roles and permission roots
4. swarm performs work and emits memory/receipt events
5. swarm dissolves, forks, or graduates

Without swarms, the system risks becoming only a directory of isolated bots.

## What to build first in code

## Phase 0

Freeze schemas and interfaces:

- launch intent schema
- class schema
- tool schema
- profile schema
- fuel schema
- lineage schema
- swarm intent schema
- replay object shape

## Phase 1

Build the public launch contract stack:

1. `AgentLaunchTypes.sol`
2. `AgentLaunchHashing.sol`
3. `IAgentRuntime.sol`
4. `AgentClassRegistry.sol`
5. `ToolRegistry.sol`
6. `AgentProfileRegistry.sol`
7. `AgentLaunchBondEscrow.sol`
8. `AgentMemoryFuelVault.sol`
9. `AgentLineageRegistry.sol`
10. `AgentFactory.sol`
11. `AgentReceiptAnchor.sol`

First shippable milestone:

A user can launch a public configured agent into the shared runtime through `AgentFactory`, with:

- class validation
- tool-root validation
- profile registration
- launch bond lock
- initial fuel deposit
- lineage attachment
- replayable launch events

## Phase 1.5

Replay hardening and deployed-log e2e for public launch.

## Phase 2

Base Sepolia rehearsal:

- deploy public launch stack
- register classes/tool sets
- submit launch transaction
- read back through SDK/dashboard/control-plane
- record source verification plan/evidence

## Phase 3

Token/fuel economics hardening.

## Phase 4

Swarm primitive contracts.

## Phase 5

Swarm evolution:

- forks
- dissolution
- graduation
- swarm-born agents
- swarm-to-agent lineage

## Phase 6

Premium shell path.

## Biggest risks and tradeoffs

1. shared runtime vs dedicated shells
2. token friction vs usability
3. tool registry centralization vs safety
4. bond slashing governance risk
5. gateway-backed memory misunderstanding
6. swarm budget abuse
7. factory god-contract risk
8. replay drift across surfaces
9. swarms too early
10. public launch claims outrunning evidence

## Implementation track split

### Contracts

Build registries, escrow/vaults, factory, receipt anchor, swarms, and later shells.

### SDK / CLI

Add:

- class discovery
- tool discovery
- launch config compiler
- launch signing helper
- launch submit helper
- profile read helpers
- replay helpers
- swarm create/join/read helpers

### Control-plane

Add:

- class list/get
- tool list/get
- public launch preview/get/list
- profile get/list
- bond/fuel get
- swarm create preview/get/list
- swarm replay methods

### Dashboard

Add:

- public launch wizard
- class catalog
- tool policy builder
- launch root review
- bond/fuel review
- agent profile and replay timeline
- public discovery
- swarm launch/profile/members/budget/replay

### Docs / review

Add or update:

- public contracts page
- public launch flow
- EIP-712 launch intent
- token/bond/fuel rules
- tool registry/risk tiers
- replay boundaries
- swarm architecture
- Base Sepolia rehearsal page

## Definition of done

This full build goal is complete only when:

- the public launch contract stack exists and is tested;
- user-launched agents can be created through a signed launch flow;
- token-backed launch seriousness is implemented clearly;
- discovery, SDK, control-plane, dashboard, and replay surfaces agree on one model;
- swarm architecture is implemented or explicitly split into the next gated phase;
- every claim is grounded in current code, schemas, tests, fixtures, or explicit non-goal language.
