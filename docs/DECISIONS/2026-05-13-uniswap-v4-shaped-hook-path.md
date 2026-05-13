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

Issue #78 keeps the adapter-first path for existing local/canary fixtures and
adds the next production-shaped path without vendoring v4 dependencies:

- `FlowMemoryAfterSwapHook` is a separate PoolManager-gated hook candidate with
  only a v4-shaped `afterSwap` callback.
- `FlowMemoryHookPlanner` defines and mines the permission-address target for
  the hook candidate.
- The first hook target is afterSwap-only: low hook bits must equal
  `AFTER_SWAP_FLAG` (`1 << 6`, `0x40`) and must not include return-delta,
  before-swap, donate, liquidity, or initialize flags.

## Why

The previous adapter was useful for local tests but did not give reviewers a
real v4 callback shape. The new path makes the next hook integration work much
less abstract while still avoiding a premature dependency or production
deployment claim.

The true-hook path is separate from the adapter so launch fixtures can remain
stable while Base Sepolia hook address mining, PoolManager gating, and source
verification inputs become concrete review artifacts.

## Boundaries

- This is not a production Uniswap v4 hook deployment.
- The repo still does not vendor `v4-core` or `v4-periphery`.
- The adapter and hook callback do not do custom accounting, token custody,
  dynamic fees, or LP fee overrides.
- Production pool configuration remains gated.
- Contracts still cannot know `txHash` or `logIndex`; indexers derive those
  after receipts and logs exist.

## Hook Permission Target

The first real PoolManager hook target is `afterSwap` only:

- no `beforeSwap`;
- no custom accounting return delta;
- no dynamic LP fee override;
- no token custody;
- no pool creation or liquidity-position behavior.

The hook candidate must be permission-address-mined for Uniswap v4's hook flags
before any pool can use it. The current canary adapter address is not claimed
to satisfy those hook address flags.

## Base Sepolia Path

Base Sepolia is the next allowed live-network path for this hook work:

- chain id: `84532`;
- PoolManager: `0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3`;
- CREATE2 deployer: `0x4e59b44847b379578588920cA78FbF26c0B4956C`;
- target hook address bits: exactly `0x40` under Uniswap v4's low-bit hook
  mask;
- constructor args: reviewed PoolManager address only.

Before broadcast, the issue or PR must record the mined salt, computed hook
address, init code hash, constructor args, deployer, target chain, source
verification plan, and post-deploy Base Sepolia reader range. This is still not
a production hook deployment or Base mainnet approval.

## Tests Added

Foundry tests now cover:

- afterSwap-only permissions and address-flag rejection for extra return-delta
  or before-swap flags;
- Base Sepolia CREATE2 salt planning for a `FlowMemoryAfterSwapHook` init code
  hash;
- PoolManager gating;
- zero hook delta on `afterSwap`;
- rejection of invalid hook data;
- no payable native-token receive path;
- event schemas that continue excluding `txHash` and `logIndex`.

## Sources Checked

- [Uniswap v4 docs](https://docs.uniswap.org/contracts/v4/concepts/hooks)
  describe `beforeSwap` and `afterSwap` as swap hook callbacks.
- [Uniswap v4 core Hooks library](https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol)
  calls `IHooks.afterSwap` after swap execution and accounts for hook delta
  separately.
- [Uniswap v4 hook deployment docs](https://developers.uniswap.org/docs/protocols/v4/guides/hooks/hook-deployment)
  describe address-encoded hook flags and HookMiner-style deployment.
- [Uniswap v4 deployment docs](https://developers.uniswap.org/docs/protocols/v4/deployments)
  list current network deployment addresses, including Base Sepolia.
