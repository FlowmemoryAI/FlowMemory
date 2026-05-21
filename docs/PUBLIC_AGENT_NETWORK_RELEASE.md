# Public Agent Network Release Boundary

Status: public repository release boundary, local/test implementation.

This document names what exists for the public agent network, what is intentionally not claimed, and how reviewers can verify the current stack.

## What Exists

The current public-agent network stack includes:

- shared `BaseOnchainAgentMemory` runtime;
- class, tool, profile, lineage, receipt-anchor, launch-bond, and memory-fuel registries;
- `AgentFactory` EIP-712 launch gateway for supported agent classes;
- launch-bond escrow and memory-fuel vault flows;
- public launch preview, launch intent, discovery, and prototype projection methods in the control-plane;
- public agent class/tool helpers and deterministic launch-root builders in `services/flowmemory`;
- contract-aligned launch digest helpers for SDK and signer integrations;
- swarm policy, identity, membership, lifecycle, factory, and budget vault contracts;
- public swarm preview, launch intent, replay, and prototype projection methods;
- FlowChain SDK and CLI wrappers for discovery and public launch/swarm projections;
- dashboard public-network view backed by deterministic local data;
- Foundry tests for public contracts and a local script that exercises agent launch plus swarm budget lifecycle.

## Verification Commands

```powershell
npm run public-agent-network:contracts
npm run public-agent-network:local-e2e
npm test --prefix services/flowmemory
npm test --prefix services/control-plane
npm test --prefix services/flowchain-sdk
npm test --prefix services/agent-memory-sdk
npm test --prefix apps/dashboard
npm run build --prefix apps/dashboard
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

The local deployed-log style exercise is:

```powershell
npm run public-agent-network:local-e2e
```

It runs `script/RunPublicAgentNetworkLocalE2E.s.sol:RunPublicAgentNetworkLocalE2E`, deploys the public-agent and swarm contracts in a local Foundry script simulation, signs a deterministic public launch intent, creates an agent, creates a swarm with that agent as a member, reserves and releases budget, and spends from a budget line.

## What This Is Not

This release does not claim:

- production readiness;
- mainnet readiness;
- audited contracts;
- production indexer/verifier operations;
- public validator economics;
- uncapped tokenomics;
- production keeper automation;
- production bridge security;
- AI/model execution on-chain;
- heavy memory storage on-chain.

## Design Boundary

Agents are launched from supported registered classes. Users do not upload arbitrary Solidity as agents. The public launch path uses compact commitments and receipts on-chain while heavy memory, artifacts, model outputs, and media remain off-chain.

Swarms are treated as first-class network actors: temporary machine-native organizations with mission roots, shared memory roots, roles, members, budgets, and lifecycle transitions.

## Public Operator Boundary

The repository is safe to read publicly as a local/test implementation package. Live deployments still require explicit operator inputs, funded testnet credentials, bounded block ranges, and follow-up verification. Never commit live credentials or `.env` files.
