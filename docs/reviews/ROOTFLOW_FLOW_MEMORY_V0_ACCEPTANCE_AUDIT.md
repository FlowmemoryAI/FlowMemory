# Rootflow And Flow Memory V0 Acceptance Audit

Date: 2026-05-13

Status: local/test V0 launch-core integration complete.

This audit tracks the launch-critical goal: build Rootflow V0 and Flow Memory V0 as a coherent local/testnet-ready V0 system. The local fixture acceptance path now exists and is verified. This does not mean production L1, production Uniswap v4 deployment, production verifier network, free storage, or AI running on-chain.

## Current Merged State

All previously open launch-foundation PRs have merged into `main`:

| PR | Area | Merged result |
| --- | --- | --- |
| #56 | FlowRouter hardware POC | Hardware docs, schemas, simulator, and sample fixture. |
| #57 | Contracts V0 foundation | FlowPulse, Rootfield, hook-adapter scaffold, receipt/report/work/identity registries, scheduler skeleton, and 33 Foundry tests. |
| #58 | Local devnet prototype | Rust no-value local devnet crate, handoff fixtures, chain research docs, and 7 Rust tests. |
| #59 | FlowMemory HQ OS | Source-of-truth docs, agent roles, runbook, backlog, launch-core goals, and review process. |
| #60 | Crypto V0 foundation | Keccak-based helper package, typed domains, receipts, roots, report hashes, attestations, fixtures, and vectors. |
| #61 | Indexer/verifier V0 fixtures | Shared services package, fixture indexer, fixture verifier, report schema, e2e command, and 24 service tests. |
| #62 | Dashboard V0 | Fixture-backed Vite/React dashboard, dashboard fixture, views, tests, and production build. |

## Launch-Core Evidence

The single local acceptance command is:

```powershell
npm run launch:v0
```

It runs:

1. FlowPulse fixture indexing.
2. Verifier report generation.
3. No-value local devnet handoff generation.
4. FlowRouter hardware fixture validation.
5. Rootflow and Flow Memory V0 generation.
6. Dashboard fixture/runtime generation.

Generated outputs:

- `fixtures/launch-core/flowmemory-launch-v0.json`
- `fixtures/launch-core/rootflow-transitions.json`
- `fixtures/dashboard/flowmemory-dashboard-v0.json`
- `apps/dashboard/public/data/flowmemory-dashboard-v0.json`
- `fixtures/launch-core/generated/devnet/`

Launch-hardening evidence:

- Generated `MemorySignal` objects now embed `contractEvent` data for
  `IFlowPulse.FlowPulse`, including event signature text, topic0, pulse type,
  indexed fields, payload fields, and receipt-derived locator fields.
- Generated `RootflowTransition` objects now include `contractEventRef` so a
  dashboard or reviewer can map each transition back to the contract event
  semantics that produced the signal.
- The Flow Memory / Rootflow dashboard view now includes a contract-event spine,
  transition status counts, root bundle summary, and agent memory warnings for
  launch demo review.
- `docs/reviews/V0_BOUNDARY_CLAIMS_AUDIT.md` records the latest review pass for
  blocked production, storage, trustlessness, hardware, and AI-on-chain claims.

Canonical schemas:

- `schemas/flowmemory/memory-signal.schema.json`
- `schemas/flowmemory/memory-receipt.schema.json`
- `schemas/flowmemory/rootflow-transition.schema.json`
- `schemas/flowmemory/rootfield-bundle.schema.json`
- `schemas/flowmemory/agent-memory-view.schema.json`

## Main Verification Evidence

These commands were run from merged `main` on 2026-05-13.

| Area | Command | Result |
| --- | --- | --- |
| Launch core | `npm run launch:v0` | 7 loaded FlowPulses, 7 indexed observations, 7 verifier reports, 6 Rootflow transitions, 7 MemorySignals, 7 MemoryReceipts, 1 RootfieldBundle, 1 AgentMemoryView. |
| Services | `npm test` | 27 tests passed across shared, indexer, verifier, and FlowMemory packages. |
| Services e2e | `npm run e2e` | Indexer -> verifier -> FlowMemory generator passed and wrote dashboard fixture. |
| Dashboard | `npm test`; `npm run build` in `apps/dashboard` | 4 tests passed; production build passed. |
| Contracts | `forge test` | 33 tests passed. |
| Crypto | `npm ci`; `npm test`; `npm run validate:vectors`; `python validate_test_vectors.py` | 13 tests passed; 21 vectors validated; Python FlowPulse recompute passed. |
| Devnet | `cargo test --manifest-path crates\flowmemory-devnet\Cargo.toml` | 7 tests passed. |
| Hardware | `python hardware\simulator\flowrouter_sim.py --validate-file hardware\fixtures\flowrouter_sample_seed42.json` | Fixture validation passed. |

## Acceptance Matrix

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Rootfield namespaces | `RootfieldRegistry` registration and Foundry tests. | Implemented for V0 local contracts. |
| Root commitments | `submitRoot`, counters, latest root storage, FlowPulse emission, tests. | Implemented for V0 local contracts. |
| Parent/child memory-state transitions | `fixtures/launch-core/rootflow-transitions.json` contains generated RootflowTransition objects with parent pulse and parent transition links. | Implemented for local/test V0. |
| FlowPulse linkage | Contracts emit FlowPulse; services parse fixture logs and generated MemorySignals reference pulse/observation ids. | Implemented for local/test V0. |
| Contract event semantics | Generated MemorySignals and RootflowTransitions expose `IFlowPulse.FlowPulse` event metadata, indexed fields, payload fields, and receipt locator fields. | Implemented for local/test V0. |
| Receipt linkage | Generated MemoryReceipts link verifier reports to observations/rootfields. | Implemented for local/test V0. |
| Verifier status | `services/flowmemory/src/status.ts` maps `valid`/`invalid` to `verified`/`failed`. | Implemented. |
| Pending/verified/failed/reorged states | Generated dashboard fixture includes observed, pending, finalized, verified, failed, unresolved, unsupported, reorged, offline, and stale. | Implemented for local/test V0. |
| Deterministic fixtures | Launch-core, dashboard, crypto, services, devnet, and hardware fixtures exist. | Implemented. |
| Dashboard-readable state | Dashboard fixture is generated from services/devnet/hardware outputs. | Implemented. |
| Flow Memory schemas | Canonical JSON schema files exist under `schemas/flowmemory/`. | Implemented for local/test V0. |
| Verifier reports | Schema, local reports, tests, and e2e output exist. | Implemented for local fixtures. |
| Dashboard display path | Dashboard includes Flow Memory / Rootflow view and renders generated fixture data. | Implemented for local fixtures. |
| Single acceptance command | `npm run launch:v0`. | Implemented. |
| Area-specific CI | CI includes contracts, services/launch-core, crypto, dashboard, devnet, and hardware jobs. | Implemented. |

## Remaining Gated Work

Not part of local/test V0 completion:

- Live RPC indexing and durable production persistence.
- Production Uniswap v4 hook deployment.
- Production appchain/L1, sequencer, validator, bridge, or token design.
- Hardware firmware, real Meshtastic devices, manufacturing, certification, and field deployment.
- Trustless proof systems, verifier economics, slashing, GPU proofs, and production verifier network.
- Runtime JSON Schema validation with a dedicated validator dependency.

## Next Three Issues

1. `[launch-core/validation] Add runtime schema validation and fixture diff guardrails`
   - Agent/worktree: Review/Integration Agent in `E:\FlowMemory\flowmemory-review`.
   - Owns: schema validator choice, fixture validation command, CI diff policy.

2. `[contracts/security] Add static-analysis setup and V0 contract hardening notes`
   - Agent/worktree: Contracts Agent in `E:\FlowMemory\flowmemory-contracts`.
   - Owns: Slither setup issue, owner/status boundary review, test gaps.

3. `[dashboard/polish] Add deeper generated object inspection`
   - Agent/worktree: Dashboard Agent in `E:\FlowMemory\flowmemory-dashboard`.
   - Owns: drilldown views, generated object inspection, no live API claims.

## Current Recommendation

Treat Rootflow V0 and Flow Memory V0 as locally integrated and fixture-complete. Keep production claims blocked until separate live indexing, deployment, proof, verifier-network, and chain decisions are made.
