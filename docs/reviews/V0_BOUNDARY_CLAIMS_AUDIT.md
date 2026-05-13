# V0 Boundary Claims Audit

Date: 2026-05-13

Status: pass for the current launch-core documentation set.

## Scope Reviewed

Reviewed the launch-facing source-of-truth docs and generated local/test V0
surfaces for unsafe production claims:

- `README.md`
- `docs/CURRENT_STATE.md`
- `docs/ROADMAP.md`
- `docs/ARCHITECTURE.md`
- `docs/ROOTFLOW_V0.md`
- `docs/FLOW_MEMORY_V0.md`
- `docs/V0_LAUNCH_ACCEPTANCE.md`
- `docs/SECURITY_MODEL.md`
- `docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md`
- `apps/dashboard/README.md`
- generated launch-core and dashboard fixture descriptions

## Claims That Remain Allowed

- FlowMemory has a local/test V0 launch-core path.
- `npm run launch:v0` regenerates fixture-backed Rootflow and Flow Memory state.
- Contracts emit compact `FlowPulse` events.
- Indexers derive receipt coordinates such as `txHash` and `logIndex` after
  receipts/logs exist.
- Verifiers produce local/test V0 reports.
- The dashboard renders generated fixture data.

## Claims That Remain Blocked

- FlowMemory is a production L1 or mainnet-ready chain.
- FlowMemory has production Uniswap v4 hook deployment.
- FlowMemory provides full trustless verification.
- FlowMemory provides free on-chain storage.
- AI runs on-chain.
- Transaction hashes store arbitrary memory data.
- Hardware is manufactured, field-deployed, or fully trustless.
- Meshtastic/LoRa provides normal internet bandwidth.

## Result

No launch-facing source-of-truth doc reviewed here claims production L1,
production mainnet readiness, full trustless verification, free storage, or AI
running on-chain.

Keep this audit updated whenever docs, dashboard copy, README language, or
generated fixture descriptions change in a way that affects launch claims.
