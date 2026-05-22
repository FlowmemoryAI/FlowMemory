# Public Agent Network Release Boundary

Status: public repository release boundary, local/test implementation.

This document names what exists for the public agent network, what is intentionally not claimed, and how reviewers can verify the current stack.

For the end-to-end reader guide, see `docs/PUBLIC_REPO_GUIDE.md`. For tester lanes, see `docs/PUBLIC_TESTER_GUIDE.md`. For component-level details, see `docs/PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md`.

## What Exists

The current public-agent network stack includes:

- shared `BaseOnchainAgentMemory` runtime;
- class, tool, profile, lineage, receipt-anchor, launch-bond, and memory-fuel registries;
- `AgentFactory` EIP-712 launch gateway for supported agent classes;
- launch-bond escrow and memory-fuel vault flows;
- public launch preview, launch intent, discovery, and prototype projection methods in the control-plane;
- public agent class/tool helpers and deterministic launch-root builders in `services/flowmemory`;
- contract-aligned launch digest helpers, direct calldata builders, EIP-712 typed-data signing requests, EIP-1193 provider submission helpers, receipt polling, and event decoding for SDK and signer integrations;
- swarm policy, identity, membership, lifecycle, factory, and budget vault contracts;
- public swarm preview, launch intent, replay, prototype projection methods, and direct create-call builders;
- public SDK and CLI wrappers for discovery, public launch/swarm projections, direct contract preparation/submission helpers, and local CLI smoke;
- dashboard public-network view backed by deterministic local data;
- Foundry tests for public contracts and a local script that exercises agent launch plus swarm budget lifecycle;
- Base Sepolia public-agent deployment, source-verification, and bounded event-readback tooling with a configured public testnet deployer plan in `fixtures/deployments/public-agent-network-base-sepolia-plan.json`.

## Verification Commands

```powershell
npm run public-agent-network:contracts
npm run public-agent-network:local-e2e
npm run public:test:quick
npm run public-agent-network:base-sepolia:plan -- --deployer-address 0x69F55917209C446bf9d31D2903e01966B75a8cDe --json
npm test --prefix services/control-plane
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

The Base Sepolia operator rehearsal path is:

```powershell
npm run public-agent-network:base-sepolia:plan -- --deployer-address 0x69F55917209C446bf9d31D2903e01966B75a8cDe --json
npm run public-agent-network:base-sepolia -- --json
npm run public-agent-network:base-sepolia:broadcast -- --json
npm run public-agent-network:base-sepolia:readback -- --rpc-url $env:BASE_SEPOLIA_RPC_URL --deployment-artifact fixtures/deployments/public-agent-network-base-sepolia.latest.json --from-block <deployBlock> --to-block <latestBlock>
```

The plan command is public-safe and committed. Dry run, broadcast, and readback require explicit local operator environment values and must not write RPC URLs, private keys, or explorer API keys.

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
