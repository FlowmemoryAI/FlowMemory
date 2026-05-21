# Public Agent Network Module Prompts

## Purpose

This file contains copy-ready module prompts for the major public-network contracts and surfaces.

Use these when splitting the public agent network across worktrees or specialized implementation agents.

## 1. AgentClassRegistry prompt

```text
Implement AgentClassRegistry.sol for FlowMemory public agent launch.

Requirements:
- register supported public agent archetypes;
- store compact on-chain config for each class;
- fields must include classId, version, kernelClass, schemaRoot, defaultPolicyRoot, allowedToolPolicyRoot, pricingRoot, metadataDigest, autonomy bounds, max tool risk tier, max tools, minimum launch bond, minimum memory fuel, and launch/swarm/shell permissions;
- include register/update/deprecate events;
- expose validation helpers for AgentFactory;
- add tests for inactive/deprecated classes, invalid class config, and launchability checks.

Non-goals:
- no public launch execution inside this contract;
- no arbitrary metadata blobs on-chain.
```

## 2. ToolRegistry prompt

```text
Implement ToolRegistry.sol as the public capability registry for FlowMemory agents.

Requirements:
- register tool identities, adapter digests, schema roots, policy roots, risk tiers, mutability, dry-run requirements, and tool-set roots;
- validate whether a tool set is allowed for an agent class and autonomy level;
- include register/update/deprecate flows and tests for incompatible tool sets, mutating-tool risk escalation, and class/tool compatibility.

Non-goals:
- do not execute tools;
- do not act as a generic router.
```

## 3. AgentFactory prompt

```text
Implement AgentFactory.sol as the EIP-712 public launch gateway.

Requirements:
- validate signed LaunchIntent;
- reject reused or expired intents;
- verify class/tool/profile/root constraints;
- lock launch bond;
- deposit memory fuel;
- call BaseOnchainAgentMemory.registerAgent(...);
- register profile;
- attach lineage;
- emit replayable launch events;
- include integration tests against the shared runtime and deployed-log replay fixtures.

Constraints:
- must not rely on txHash/logIndex during execution;
- must not accept arbitrary user Solidity.
```

## 4. AgentLaunchBondEscrow prompt

```text
Implement AgentLaunchBondEscrow.sol as the anti-spam launch bond layer.

Requirements:
- lock approved bond tokens per agent;
- enforce class bond policies;
- support release request and release after delay;
- support capped slashing with reasonCode and evidenceRoot;
- include tests for double release, slash-after-release, insufficient bond, release delay, and evidence-root emission.

Boundary:
- this is launch seriousness and anti-spam, not insurance, recourse, or task settlement.
```

## 5. AgentMemoryFuelVault prompt

```text
Implement AgentMemoryFuelVault.sol for memory persistence fuel.

Requirements:
- support deposits, reservations, consumption against receipt roots, refunds, class fuel policies, sponsor support, and authorized metering;
- emit replayable fuel events;
- include tests for insufficient fuel, authorized consumption, reservation/release, sponsor deposits, and accounting safety.

Boundary:
- do not describe this as EVM gas;
- do not charge unverifiable hidden model-token usage.
```

## 6. AgentProfileRegistry prompt

```text
Implement AgentProfileRegistry.sol for public agent discovery.

Requirements:
- store compact profile commitments: profileDigest, publicMetadataRoot, discoveryTagsRoot, avatarDigest, handleHash, discoverability, and version;
- support handle uniqueness and profile updates by authorized owner/factory path;
- include dashboard-friendly events and tests for handle conflicts and profile visibility.

Boundary:
- do not store heavy profile/media data.
```

## 7. AgentReceiptAnchor prompt

```text
Implement AgentReceiptAnchor.sol for optional post-execution receipt commitments.

Requirements:
- anchor receiptRoot, eventRoot, previousMemoryRoot, newMemoryRoot, attestor, schemaVersion, and supersession events;
- support receipt anchoring, supersession, and authorized attestor flows;
- include tests for unauthorized attestors and correction replay.

Boundary:
- do not rely on txHash/logIndex during execution.
```

## 8. SwarmRegistry prompt

```text
Implement SwarmRegistry.sol as the identity and lifecycle contract for FlowMemory swarms.

Requirements:
- support swarm creation, missionRoot, sharedMemoryRoot, policyRoot, roleRoot, profileDigest, member refs for wallets/agents/swarms/shells, roles, join/leave, role changes, mission updates, shared memory updates, pause, dissolve, fork, and graduation;
- store compact roots only;
- emit replayable swarm lifecycle events.
```

## 9. SwarmBudgetVault prompt

```text
Implement SwarmBudgetVault.sol as a mission-scoped shared budget vault.

Requirements:
- support deposits, budget lines, per-purpose caps, reservations, spends, releases, receipt roots, role policy roots, and active/dissolved swarm checks;
- prevent spending above cap and spending after dissolution;
- add invariant tests for budget conservation.
```

## 10. Dashboard prompt

```text
Implement the public agent network dashboard surfaces.

Requirements:
- class catalog;
- tool policy builder;
- public launch wizard;
- launch root review;
- bond/fuel review;
- live agent profile;
- replay timeline;
- correction history;
- public discovery directory;
- swarm launch;
- swarm profile;
- member roles;
- budget vault;
- shared memory replay.

Must include explicit trust-boundary copy:
- roots/receipts/policies are on-chain;
- heavy memory artifacts remain off-chain;
- this is not a production/mainnet readiness claim.
```

## 11. SDK/control-plane prompt

```text
Implement direct deployed-contract SDK and control-plane support for the public agent network.

Requirements:
- class listing;
- tool listing;
- launch preview;
- EIP-712 launch signing;
- launch execution;
- profile retrieval;
- replay retrieval;
- bond/fuel state;
- swarm creation;
- swarm budgets;
- swarm replay.

Replay assembly must join factory/runtime/profile/bond/fuel/swarm events by deterministic ids, not by assuming txHash/logIndex as execution-time inputs.
```
