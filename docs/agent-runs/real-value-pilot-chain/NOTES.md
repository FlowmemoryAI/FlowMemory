# FlowChain Real-Value Pilot Chain Runtime Notes

## Source Context

- This branch ports the useful runtime work from
  `E:\FlowMemory\flowmemory-live-chain` onto current `main` after PR #146.
- The old source worktree was behind the HQ, bridge, wallet, ops, and contracts
  proof merges; this branch keeps the merged HQ
  `flowchain:real-value-pilot:e2e` gate and adds only the runtime proof alias.
- The old source worktree had a legacy `infra/scripts/flowchain-real-value-pilot-e2e.ps1`;
  that file was intentionally not ported because HQ owns the final gate.

## Runtime Model

- Bridge credits are local/no-value runtime records derived from relayer handoff
  evidence.
- Source transaction hash and log index are consumed from relayer/indexer
  handoff objects after the Base event exists; the runtime does not claim a
  contract knew those receipt fields during execution.
- Replay protection is keyed by the relayer-provided bridge replay key.
- The runtime records both a bridge credit object and a bridge credit receipt so
  control-plane, dashboard, indexer, and verifier handoffs can all reference the
  same local receipt id.

## Root Command

The branch adds:

```powershell
npm run flowchain:real-value-pilot:runtime
```

The command runs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-real-value-pilot-runtime.ps1
```

## Boundary

This work does not add custody, release guarantees, tokenomics, production
bridge security, public validators, public L1/mainnet readiness, or production
deployment behavior.
