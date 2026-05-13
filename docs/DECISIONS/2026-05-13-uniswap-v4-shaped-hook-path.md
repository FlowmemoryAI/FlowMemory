# Uniswap V4-Shaped Hook Path

Date: 2026-05-13

## Decision

FlowMemory V0 now keeps the original dependency-light hook adapter method and
adds a Uniswap v4-shaped `afterSwap` callback surface:

```text
afterSwap(address sender, PoolKey key, SwapParams params, int256 swapDelta, bytes hookData)
  -> (bytes4 selector, int128 hookDelta)
```

The callback consumes ABI-encoded `FlowMemorySwapHookData`, derives a pool id
from the v4-compatible pool key fields, emits a `SWAP_MEMORY_SIGNAL` FlowPulse,
and returns zero hook delta.

## Why

The previous adapter was useful for local tests but did not give reviewers a
real v4 callback shape. The new path makes the next hook integration work much
less abstract while still avoiding a premature dependency or production
deployment claim.

## Boundaries

- This is not a production Uniswap v4 hook deployment.
- The repo still does not vendor `v4-core` or `v4-periphery`.
- The callback does not do custom accounting, token custody, dynamic fees, or
  LP fee overrides.
- Hook address permission mining, PoolManager deployment wiring, and production
  pool configuration remain gated.
- Contracts still cannot know `txHash` or `logIndex`; indexers derive those
  after receipts and logs exist.

## Production Hook Permission Target

When this graduates from adapter-first V0 to a real PoolManager hook, the first
permission target should be `afterSwap` only:

- no `beforeSwap`;
- no custom accounting return delta;
- no dynamic LP fee override;
- no token custody;
- no pool creation or liquidity-position behavior.

That production hook must be permission-address-mined for Uniswap v4's hook
flags and deployed through a dedicated script before any pool can use it. The
current canary adapter address is not claimed to satisfy those production hook
address flags.

## Sources Checked

- [Uniswap v4 docs](https://docs.uniswap.org/contracts/v4/concepts/hooks)
  describe `beforeSwap` and `afterSwap` as swap hook callbacks.
- [Uniswap v4 core Hooks library](https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol)
  calls `IHooks.afterSwap` after swap execution and accounts for hook delta
  separately.
