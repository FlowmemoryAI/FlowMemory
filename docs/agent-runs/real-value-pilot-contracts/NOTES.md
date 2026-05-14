# Real-Value Pilot Contracts Notes

## Source Context

- `docs/START_HERE.md`, `docs/FLOWMEMORY_HQ_CONTEXT.md`,
  `docs/CURRENT_STATE.md`, `docs/ROOTFLOW_V0.md`,
  `docs/FLOW_MEMORY_V0.md`, `docs/V0_LAUNCH_ACCEPTANCE.md`, and
  `docs/PR_PROCESS.md` were read before editing.
- This integration branch ports the useful contract-side work from
  `E:\FlowMemory\flowmemory-live-contracts` onto current `main` after PR #145.
  Several sibling worktrees are dirty; their changes are context only until
  merged.
- The real-value pilot goal pack exists in `E:\FlowMemory\flowchain-release`,
  not in this branch.

## Event Boundary

`BridgeDeposit` must remain:

```solidity
BridgeDeposit(bytes32,uint256,address,address,uint256,bytes32,uint256,bytes32)
```

Receipt fields such as `txHash`, `transactionIndex`, `logIndex`, block number,
and block hash are relayer/indexer-derived after logs exist. The contract emits
deterministic in-transaction data only: schema-derived `depositId`, chain id,
lockbox address by log emitter, sender, token, amount, FlowChain recipient,
nonce, and metadata hash.

## Pilot Boundary

The `8453` path is a capped pilot deployment configuration for the same lockbox
and settlement spine, not a broad public bridge claim. Owner and release
authority are trusted pilot roles. Emergency controls are pause, cap changes
above current locked amount, allowlist disablement, authority rotation, and
authorized release/recovery calls.

## Verification Notes

- `npm run flowchain:product-e2e` regenerates tracked fixture/dashboard/service
  outputs during the run. Those generated outputs were restored afterward so the
  branch stays inside the assigned folders.
- Foundry dry-run artifacts under `broadcast/` and cache artifacts under
  `cache/` remain ignored by Git.
- The root package alias is `flowchain:real-value-pilot:contracts`; the final
  HQ gate remains `flowchain:real-value-pilot:e2e`.
