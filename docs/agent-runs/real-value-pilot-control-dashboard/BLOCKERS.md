# Real-Value Pilot Control-Plane/Dashboard Blockers

## Blocking Acceptance Item

`npm run flowchain:real-value-pilot:e2e` does not pass without `-AllowIncomplete` after rebasing onto the upstream HQ pilot gate.

## Why It Blocks Completion

The upstream final pilot gate now checks every owner proof row before running subsystem proof commands. This control-plane/dashboard branch provides its owner-specific proof command, but the final gate still reports missing proof commands owned by other workstreams.

## Missing Upstream Proof Rows

- `flowchain:real-value-pilot:contracts` - issue #133: https://github.com/FlowmemoryAI/FlowMemory/issues/133
- `flowchain:real-value-pilot:bridge` - issue #138: https://github.com/FlowmemoryAI/FlowMemory/issues/138
- `flowchain:real-value-pilot:runtime` - issue #134: https://github.com/FlowmemoryAI/FlowMemory/issues/134
- `flowchain:real-value-pilot:wallet` - issue #136: https://github.com/FlowmemoryAI/FlowMemory/issues/136
- `flowchain:real-value-pilot:ops` - issue #135: https://github.com/FlowmemoryAI/FlowMemory/issues/135

## Current Evidence

- `npm test --prefix services/control-plane` passes.
- `npm run control-plane:smoke` passes.
- `npm test --prefix apps/dashboard` passes.
- `npm run build --prefix apps/dashboard` passes.
- `npm run flowchain:real-value-pilot:control-dashboard` passes and verifies this branch's API/dashboard evidence row.
- Bare `npm run flowchain:product-e2e` now passes after rebasing onto `origin/main` commit `f384236`.
- Bare `npm run flowchain:real-value-pilot:e2e` fails with an incomplete report that names the missing contracts, bridge, runtime, wallet, and ops proof commands.
- `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` completes and writes `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`; that report marks `control-dashboard:api-and-owner-views.passed` as `true` and `ownerGoNoGo.go` as `false`.

## GitHub Tracking

- `origin/main` contains the final HQ pilot gate and optional Slither policy that lets `flowchain:product-e2e` pass in the default gate.
- `docs/FLOWCHAIN_REAL_VALUE_PILOT.md` assigns the control-plane/dashboard row to issue #137 and `npm run flowchain:real-value-pilot:control-dashboard`; this branch now provides that command.
- The remaining missing proof commands belong to other owners and are outside this branch's allowed folders.

## Smallest Useful Next Step

Merge or rebase the contracts, bridge-relayer, runtime, wallet/operator, and ops/installer proof-command branches. Then rerun:

```powershell
npm run flowchain:real-value-pilot:e2e
```
