# Public Agent Network Technical Guide

Status: technical guide for the current local/test public-agent implementation.

This guide explains how the public-agent network works across contracts, helpers, control-plane methods, SDK/CLI surfaces, dashboard projection, tests, and remaining gaps. It describes the current repository state only. It does not claim a production agent network or audited deployment.

## 1. Design Goal

The public-agent network lets an agent be launched from a supported class, with public roots and receipts that make the agent's state inspectable and replayable.

The design deliberately avoids arbitrary user-supplied agent contracts. A public launch chooses from registered classes and approved tool sets. The chain-side system stores compact state: identity, roots, receipts, policy references, fuel, bonds, lineage, and swarm/budget state. Heavy memory, prompts, files, model output, embeddings, and media remain off-chain behind commitments or receipts.

## 2. Contract Layers

### Shared runtime

`contracts/BaseOnchainAgentMemory.sol`

The shared runtime registers agents, tracks latest memory roots and sequences, previews bounded steps, commits allowed actions, writes memory deltas, emits FlowPulse, and records correction history. Public launches currently register into this shared runtime instead of deploying one contract per agent.

### Public launch registries

`contracts/public-agent-network/`

- `AgentClassRegistry.sol` registers supported classes, autonomy bounds, launch minimums, and tool risk limits.
- `ToolRegistry.sol` registers tools, tool sets, and class-to-toolset compatibility.
- `AgentProfileRegistry.sol` stores discoverable profile roots and handle ownership.
- `AgentLineageRegistry.sol` records parent agent, parent swarm, generation, and inheritance roots.
- `AgentReceiptAnchor.sol` stores post-execution receipt commitments and replay status.

### Funding and accountability

- `AgentLaunchBondEscrow.sol` locks, releases, and slashes launch bonds under class policies.
- `AgentMemoryFuelVault.sol` creates fuel accounts, accepts deposits, reserves fuel, consumes fuel, and refunds reservations.

These are not broad tokenomics. They are narrow operational primitives: launch bond, memory fuel, swarm budget, and scoped accountability.

### Launch gateway

`AgentFactory.sol` validates an owner-signed EIP-712 launch intent, checks class/tool/funding rules, registers the agent in the shared runtime, creates profile state, locks bond, deposits fuel, and attaches lineage when a parent agent or swarm is present.

### Swarm layer

`contracts/public-agent-network/swarm/`

- `SwarmPolicyRegistry.sol` registers approved swarm classes and policy roots.
- `SwarmRegistry.sol` creates swarms, manages membership, updates mission/shared-memory roots, pauses, dissolves, forks, and graduates swarms.
- `SwarmBudgetVault.sol` deposits mission budget, creates budget lines, reserves budget, releases reservations, and records spends.
- `SwarmFactory.sol` validates a swarm intent and creates the swarm plus optional initial budget.

Swarms are first-class network actors: temporary machine-native organizations with mission roots, shared memory roots, roles, membership, and budget lifecycle.

### Shell layer

`contracts/public-agent-network/shell/`

`AgentShellFactory.sol` and `AgentExecutionShell.sol` provide a later-gated dedicated-shell path. The current public release keeps the shared runtime path as the main local/test implementation.

## 3. Agent Launch Lifecycle

1. **Class setup**: an operator registers an `AgentClass` with kernel class, autonomy bounds, launch-bond minimum, memory-fuel minimum, and tool limits.
2. **Tool setup**: tools and tool sets are registered; the tool set is explicitly allowed for the class.
3. **Preview**: helper code builds `policyRoot`, `toolAllowlistRoot`, `initialMemoryRoot`, `activeGoalRoot`, `profileDigest`, and `launchSpecRoot` from deterministic inputs.
4. **Intent**: the owner signs a launch intent. The Solidity hash path lives in `AgentLaunchHashing.sol`; the TypeScript mirror lives in `services/flowmemory/src/public-agent-network.ts`.
5. **Factory validation**: `AgentFactory` checks time window, nonce, signature, class launchability, kernel class, autonomy bounds, allowed tool set, bond minimum, and fuel minimum.
6. **Runtime registration**: the shared runtime creates the agent and emits the relevant FlowPulse path.
7. **Funding**: launch bond and memory fuel are pulled from the payer or sponsor according to the launch payment mode.
8. **Profile and lineage**: profile roots are stored; lineage attaches parent agent or parent swarm when present.
9. **Discovery and replay projection**: control-plane, SDK, and dashboard surfaces expose deterministic launch records and replay-oriented state.

## 4. Swarm Lifecycle

1. **Policy setup**: `SwarmPolicyRegistry` approves a swarm class and policy root.
2. **Intent build**: helper code builds mission, shared-memory, policy, role, and profile roots.
3. **Creation**: `SwarmFactory` validates the window, nonce, policy, and class, then calls `SwarmRegistry.createSwarm`.
4. **Membership**: swarms can contain wallets, agents, child swarms, or shells.
5. **Budget**: `SwarmBudgetVault` receives mission budget, creates budget lines, reserves budget, releases reservations, and records spends.
6. **Evolution**: registry functions support mission-root updates, shared-memory-root updates, pause, dissolve, fork, and graduation paths.

The open swarm-born-agent work is tracked in issue #168.

## 5. Services And SDK Surfaces

### FlowMemory helpers

`services/flowmemory/src/public-agent-network.ts`

- lists default public agent classes and tools;
- builds public launch previews;
- builds launch intents;
- hashes launch intents for deterministic local/test projections;
- mirrors contract-aligned EIP-712 launch digest and launch-id hashing.

`services/flowmemory/src/public-swarm-network.ts`

- lists public swarm classes;
- builds swarm launch previews and intents;
- mirrors contract-style intent hash and swarm-id derivation.

### Control-plane methods

`services/control-plane/src/methods.ts`

Public-agent methods include class/tool discovery, launch preview, launch intent, prototype launch record, and discovery projection. Public-swarm methods include class discovery, launch preview, prototype swarm record, and replay projection.

Current methods are local/control-plane projections. Direct contract-backed submit/read SDK work is tracked in issue #166.

### FlowChain SDK and CLI

`services/flowchain-sdk/src/client.ts` wraps the control-plane methods. `services/flowchain-sdk/src/cli.ts` exposes public-agent and swarm commands for class/tool discovery, launch preview, launch intent, launch projection, agent discovery, swarm projection, and swarm replay.

### Agent Memory SDK

`services/agent-memory-sdk/` exposes fixture-backed and control-plane-backed reads for the Base agent-memory Task Scout flow. It is the narrow first SDK path for agent memory views and replay behavior.

## 6. Dashboard Surface

The dashboard public-network view lives at:

- `apps/dashboard/src/views/PublicAgentNetworkView.tsx`
- `apps/dashboard/src/data/publicAgentNetwork.ts`

It shows public network primitives and deterministic local projections. Live event-backed discovery, bond/fuel panels, swarm budget views, and correction/challenge timelines are tracked in issue #167.

## 7. Local Verification

Public-agent contract suites:

```powershell
npm run public-agent-network:contracts
```

Local public-agent plus swarm e2e script:

```powershell
npm run public-agent-network:local-e2e
```

The e2e script deploys the local public-agent stack, signs a deterministic launch intent, creates an agent, creates a swarm with the agent as a member, creates a budget line, reserves and releases budget, and records a spend.

The broader local/test gate remains:

```powershell
npm run launch:candidate
```

## 8. Security Model

### What chain state can prove

- a class/tool policy existed at launch time;
- a launch intent was signed by the expected owner;
- a nonce was consumed;
- a runtime agent was registered;
- a bond or fuel account changed state;
- a profile or lineage root was recorded;
- a swarm, membership, budget line, reservation, or spend was recorded.

### What chain state does not prove by itself

- that private prompts were truthful or complete;
- that off-chain model output was correct;
- that a heavy artifact is available forever;
- that a verifier report is globally trustless;
- that an agent should be trusted outside its recorded policies and receipts.

### Required boundaries

- Secrets stay out of Git.
- Heavy data stays off-chain.
- Receipts and commitments must be explicit.
- Live testnet work must use bounded block ranges and public-safe evidence.
- Any broader deployment claim requires separate gates, review, and issue/PR history.

## 9. Published Gaps

The remaining public-agent network work is intentionally public:

- #164 Base Sepolia deployment and readback evidence.
- #165 keeper runtime automation and replay-safe lifecycle jobs.
- #166 direct contract-backed launch SDK.
- #167 live dashboard discovery, fuel, bond, and swarm budget views.
- #168 swarm-born agents and memory inheritance.

The gap register is `docs/PUBLIC_RELEASE_GAPS.md`.
