# FlowChain Real-Value Pilot Chain Runtime Plan

Status: implemented on branch `agent/real-value-pilot-runtime-proof`; pending
PR for issue #134.

Worktree: `E:\FlowMemory\flowmemory-live-wallet`

## Scope

Allowed edit scope for the runtime proof:

- `crates/flowmemory-devnet/`
- `devnet/`
- `infra/scripts/flowchain-real-value-pilot-runtime.ps1`
- `package.json`
- `docs/`

Forbidden edit scope:

- `contracts/`
- `services/bridge-relayer/`
- `apps/dashboard/`
- `crypto/` secret internals
- `hardware/`

## Objective

Make the local FlowChain runtime consume deterministic pilot bridge-credit
handoff objects, map source assets and recipients into local runtime accounts,
persist credit receipts, expose receipt lookup by id and Base event reference,
reject replay, and preserve the resulting state through restart and
export/import.

## Implementation

1. Ported the chain-runtime implementation from `agent/real-value-pilot-chain`
   onto current `main` after PR #146.
2. Added native bridge asset mappings, local bridge account mappings, bridge
   credit state, bridge credit receipt state, replay index, and Base event
   receipt index to `flowmemory-devnet`.
3. Added `bridge-handoff` and `bridge-receipt` CLI flows for local runtime
   intake and receipt lookup.
4. Added Rust coverage for exactly-once bridge credit application, replay
   rejection, receipt lookup by id and Base event reference, restart
   persistence, and export/import deterministic roots.
5. Added the dedicated proof wrapper
   `infra/scripts/flowchain-real-value-pilot-runtime.ps1`.
6. Added the root `flowchain:real-value-pilot:runtime` package alias.
7. Updated local runtime docs and HQ pilot status to show the runtime proof as
   branch-local pending PR merge.

## Boundary

This remains local/testnet runtime work. It does not add custody, withdrawal
guarantees, public validators, production bridge readiness, audited
cryptography, tokenomics, or production deployment behavior.
