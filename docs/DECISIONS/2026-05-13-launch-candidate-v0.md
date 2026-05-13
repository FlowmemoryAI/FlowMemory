# Launch Candidate V0 Boundary

Date: 2026-05-13

## Decision

FlowMemory V0 now treats the local launch candidate as a complete repeatable
developer loop, not just a set of isolated fixtures.

The loop is:

```text
FlowPulse or swap-derived hook-adapter event
-> indexer observation
-> verifier report
-> MemorySignal and MemoryReceipt
-> RootflowTransition
-> RootfieldBundle
-> AgentMemoryView
-> dashboard fixture
```

## What Changed

- `FlowMemoryHookAdapter.afterSwap` emits `SWAP_MEMORY_SIGNAL` FlowPulse events
  for the V0 swap-memory path.
- The verifier can validate swap-memory artifacts using `poolId`,
  `hookDataHash`, and `memoryRoot` commitments.
- The launch command now generates 8 observations, 8 verifier reports, 8 memory
  signals, 8 memory receipts, 7 Rootflow transitions, 1 Rootfield bundle, and 1
  AgentMemoryView.
- `npm run validate:launch` validates generated launch-core objects against
  canonical JSON schemas.
- `npm run fixtures:check` catches stale generated launch/dashboard fixtures.
- `npm run launch:candidate` runs the local hardening, launch, validation,
  drift, and claim-guardrail path.
- Base Sepolia deploy/read commands exist for the current V0 testnet contract
  set without committing credentials.

## Boundaries

This decision does not approve Base mainnet deployment, a production L1,
tokenomics, production verifier economics, custody, dynamic fees, or a production
Uniswap v4 hook.

Contracts still cannot know `txHash` or `logIndex` during execution. The
indexer derives those fields after receipts and logs exist.

Heavy AI/model/memory/artifact data remains off-chain. On-chain and fixture
surfaces carry roots, commitments, receipts, and status.

## Required Before Public Testnet Use

- Run `npm run contracts:hardening:slither`.
- Record deployer address, chain id `84532`, contract addresses, block range,
  source verification status, and post-deploy read evidence in the PR or issue.
- Run the Base Sepolia reader over the deployment block range and attach the
  generated checkpoint.
