# FlowMemory Hook Adapter v0 Boundary

Date: 2026-05-12

## Status

Accepted

## Context

FlowMemory may later integrate with Uniswap v4 hooks on Base, but production hook behavior is not part of the Live V0 contracts package. The current package needs a compileable scaffold so future hook work has an explicit boundary without adding custom accounting, custody, dynamic fees, or deployment assumptions.

## Decision

Create `FlowMemoryHookAdapter` as a dependency-light scaffold with an `afterSwap`-style function. The adapter records a compact observation event containing caller, sender, pool id, rootfield id, commitment, and hook data hash.

The adapter intentionally does not:

- Import Uniswap v4 dependencies
- Implement production hook permissions
- Implement custom accounting
- Implement dynamic fees
- Hold or transfer tokens
- Call external protocols
- Know or claim `txHash` or `logIndex`
- Deploy to production networks

Receipt metadata remains indexer-derived after transaction receipts and logs are available.

## Consequences

The scaffold gives contracts, tests, and CI a concrete hook-adjacent boundary while avoiding a false claim that FlowMemory has a production Uniswap v4 hook. Future hook work must replace or wrap this adapter with real Uniswap v4 interfaces only after dependency, permission, accounting, and deployment decisions are accepted.

## Follow-Ups

- Define the production Uniswap v4 hook adapter boundary in a separate issue before importing hook dependencies.
- Decide whether hook events should emit FlowPulse directly or be transformed by indexers.
- Add dependency-specific tests only after the project accepts concrete Uniswap v4 package versions.
