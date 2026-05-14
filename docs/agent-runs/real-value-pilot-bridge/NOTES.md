# Real-Value Pilot Bridge Relayer Notes

## Source Context

- Current integration branch: `agent/real-value-pilot-bridge-proof`.
- GitHub source of truth shows draft PR #129 for the real-value pilot goal pack
  and draft PR #113 for the earlier bridge-testnet work.
- This integration branch starts from current `main` after PR #144.
- `E:\FlowMemory\flowmemory-bridge-full` contains useful unmerged bridge E2E
  work for duplicate replay and control-plane visibility. It is context only,
  not source of truth.
- `E:\FlowMemory\flowmemory-live-contracts` exists and is clean at `origin/main`
  at inspection time. Its current `BaseBridgeLockbox` event shape matches the
  relayer parser.

## Runtime Handoff Shape

The current handoff is `flowmemory.bridge_runtime_handoff.v0` in
`fixtures/bridge/local-runtime-bridge-handoff.json`. It carries observations,
credits, withdrawal intents, replay keys, duplicate replay keys, and
workbench-ready timeline/record projections. The control plane currently reads
bridge observations and projects deposits/credits; it does not yet consume a
stateful runtime application ledger.

## Design Choice

The Base public-network pilot should be a distinct mode from the existing
read-only `base-mainnet-canary` mode. This keeps the historical canary guardrail
intact while allowing the explicit pilot to require approved contracts,
confirmation depth, capped operator acknowledgement, deterministic evidence, and
exactly-once local application state.

## Package Alias Note

The root `package.json` was updated with
`flowchain:real-value-pilot:bridge` because the merged
`flowchain:real-value-pilot:e2e` is the HQ final gate. All substantive
implementation remains in the assigned bridge, schema, fixture, script, and
docs surfaces.
