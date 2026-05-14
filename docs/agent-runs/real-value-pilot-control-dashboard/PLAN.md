# Real-Value Pilot Control-Plane/Dashboard Plan

Status: implemented for the control-plane/dashboard owner row. The branch is rebased onto `origin/main` commit `f384236`; `npm run flowchain:product-e2e` now passes. The remaining external blocker is the upstream final `npm run flowchain:real-value-pilot:e2e` HQ gate, which reports missing non-control-dashboard proof commands.

## Scope

Assigned branch: `agent/real-value-pilot-control-dashboard`.

Allowed edit areas:

- `services/control-plane/`
- `services/shared/`
- `apps/dashboard/`
- `schemas/flowmemory/`
- `docs/agent-runs/real-value-pilot-control-dashboard/`
- control-plane/dashboard docs under `docs/`

Forbidden edit areas:

- `contracts/`
- `crates/`
- crypto secret internals
- hardware implementation

## Source Context Read

- `docs/START_HERE.md`
- `docs/FLOWMEMORY_HQ_CONTEXT.md`
- `docs/CURRENT_STATE.md`
- `docs/ROOTFLOW_V0.md`
- `docs/FLOW_MEMORY_V0.md`
- `docs/V0_LAUNCH_ACCEPTANCE.md`
- `docs/FLOWCHAIN_CONTROL_PLANE_API.md`
- `docs/DASHBOARD_MVP.md`
- PR #129 goal-pack metadata from GitHub
- Real-value pilot goal-pack prompt from `E:\FlowMemory\flowchain-release`

## Handoff Findings

- Current control-plane already exposes local bridge observations, bridge deposits, bridge credits, and withdrawals.
- Current control-plane reads `services/bridge-relayer/out/bridge-observation.json` when present and falls back to `fixtures/bridge/base-sepolia-mock-deposit.json`.
- Active `E:\FlowMemory\flowmemory-indexer` work adds replay-key dedupe, bridge mode metadata, stricter transaction/observation validation, and an `explorer_summary` method.
- Active `E:\FlowMemory\flowmemory-dashboard` work adds richer Product Testnet/workbench read-only JSON-RPC probing and command guidance.
- Active `E:\FlowMemory\flowmemory-bridge-full` work keeps Base mainnet canary read-only, rejects duplicate replay keys, and exposes deterministic observation/credit/withdrawal-intent handoffs.
- Active `E:\FlowMemory\flowmemory-chain` work adds runtime `bridgeCredits` in local state and control-plane handoff maps.

## Implementation Plan

1. Load and normalize bridge runtime handoff data in the control-plane without editing bridge/runtime folders.
2. Add pilot lifecycle API methods for status, deposits, credits, withdrawal intents, release evidence, caps, pause, retries, and emergency state.
3. Keep all pilot methods browser-safe and scan/reject private key, seed phrase, mnemonic, RPC credential, API key, and webhook-shaped material.
4. Add HTTP read endpoints for pilot dashboard consumption.
5. Add dashboard workbench pilot section rendering exact state and next operator command.
6. Label all pilot views as capped owner testing, not broad public readiness.
7. Add focused tests for API lifecycle, secret rejection, dashboard rendering, and an allowed-scope pilot E2E command.
8. Update control-plane/dashboard docs with new methods/endpoints and browser secret boundary.
9. Run required checks and record results in `EXPERIMENTS.md`.

## Scope Conflict

The upstream HQ gate now owns root `flowchain:real-value-pilot:e2e`. This branch keeps the executable control-plane/dashboard proof under `services/control-plane/` and adds only the owner-specific root shim:

- `flowchain:real-value-pilot:control-dashboard`

That command matches the control-plane/dashboard proof row in the upstream HQ pilot gate. No infra script is changed in this branch's diff.

## Remaining External Blocker

- The final HQ gate `npm run flowchain:real-value-pilot:e2e` reports missing contracts, bridge, runtime, wallet, and ops proof commands. Those proof commands are outside this control-plane/dashboard branch's allowed folders.
