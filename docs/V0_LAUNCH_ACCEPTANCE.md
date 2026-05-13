# V0 Launch Acceptance Matrix

Status: local/test V0 acceptance path implemented.

This matrix maps the Rootflow V0 and Flow Memory V0 goal to concrete evidence. It is intentionally strict: a PR, passing test, or useful document is only evidence if it covers the requirement named here.

## Goal

Build Rootflow V0 and Flow Memory V0 as the launch-critical core of FlowMemory.

The local/testnet-ready V0 system must support:

- Rootfield namespaces.
- Root commitments.
- Parent/child memory-state transitions.
- FlowPulse linkage.
- Receipt linkage.
- Verifier statuses.
- `pending`, `verified`, `failed`, and `reorged` states.
- Deterministic fixtures.
- Dashboard-readable state.
- Flow Memory schemas.
- Local fixtures.
- Verifier reports.
- Dashboard display path.
- Source-of-truth docs.

It must not claim production L1, production mainnet readiness, full trustless verification, free storage, or AI running on-chain.

## Artifact Checklist

| Requirement | Required evidence | Owner | Current state |
| --- | --- | --- | --- |
| Rootfield namespaces | Contract or fixture registers `rootfieldId`; docs explain namespace policy. | Contracts | Implemented for local/test V0 in `RootfieldRegistry` and tests. |
| Root commitments | Contract or fixture commits a nonzero root and emits/records the update. | Contracts | Implemented for local/test V0 in contracts and generated fixtures. |
| Parent/child transitions | `RootflowTransition` includes parent pulse/root and new root. | Indexer + Crypto + Contracts | Implemented in `fixtures/launch-core/rootflow-transitions.json`. |
| FlowPulse linkage | Transition and memory signal reference `pulseId`. | Indexer + Dashboard | Implemented in generated MemorySignals and RootflowTransitions. |
| Contract event semantics | Generated MemorySignals preserve `IFlowPulse.FlowPulse` event signature, indexed fields, payload fields, pulse type, and receipt-derived locator fields. | Contracts + Indexer + Dashboard | Implemented with `contractEvent` and `contractEventRef` fields in launch-core fixtures and dashboard data. |
| Receipt linkage | `MemoryReceipt` links signal, artifact commitment, evidence URI, and verifier report. | Crypto + Indexer | Implemented in `fixtures/launch-core/flowmemory-launch-v0.json`. |
| Verifier statuses | Cross-agent status vocabulary exists and verifier reports use it. | Indexer + Crypto | Implemented with explicit adapter in `services/flowmemory/src/status.ts`. |
| Pending state | Fixture/report can show pending transition. | Indexer + Dashboard | Implemented in generated dashboard fixture. |
| Verified state | Fixture/report can show verified transition. | Indexer + Crypto + Dashboard | Implemented in generated dashboard fixture. |
| Failed state | Fixture/report can show rejected transition. | Indexer + Dashboard | Implemented via `invalid` -> `failed` adapter. |
| Reorged state | Fixture/report can show removed/superseded observation. | Indexer | Implemented in generated transition/report/dashboard state. |
| Deterministic fixtures | Fixtures run without private RPC keys or secrets. | Indexer + Crypto + Chain | Implemented; `npm run launch:v0` regenerates deterministic local fixtures. |
| Dashboard-readable state | JSON/API/fixture shape feeds dashboard views. | Dashboard + Indexer | Implemented in generated dashboard fixture. |
| Flow Memory schemas | `MemorySignal`, `MemoryReceipt`, `RootflowTransition`, `RootfieldBundle`, and `AgentMemoryView` schemas exist. | Crypto + Indexer + Dashboard | Implemented under `schemas/flowmemory/`. |
| Verifier reports | JSON schema and sample reports exist. | Indexer + Crypto | Implemented in verifier package and generated MemoryReceipts. |
| Dashboard display path | Dashboard renders Rootfield, transition, signal, receipt, and status data. | Dashboard | Implemented in Flow Memory / Rootflow dashboard view and raw JSON. |
| Source-of-truth docs | Current state, roadmap, decision record, and specs are updated. | HQ/Review | Implemented with launch-core decision and audit updates. |

## End-To-End Acceptance Test

A developer must be able to run a local V0 flow:

1. Emit or load a FlowPulse.
2. Observe it with the indexer.
3. Create or validate a receipt.
4. Commit or update a Rootfield root.
5. Produce a Rootflow transition.
6. Show the resulting Flow Memory state in the dashboard.

The final acceptance evidence should include:

- command: `npm run launch:v0`;
- fixture paths: `fixtures/launch-core/`, `fixtures/dashboard/flowmemory-dashboard-v0.json`;
- output paths: `fixtures/launch-core/flowmemory-launch-v0.json`, `fixtures/launch-core/rootflow-transitions.json`, `apps/dashboard/public/data/flowmemory-dashboard-v0.json`;
- test results: services, dashboard, contracts, crypto, devnet, and hardware checks;
- GitHub CI area jobs.

## Required Agent Handoffs

Contracts to indexer:

- FlowPulse event ABI.
- RootfieldRegistry ABI.
- local deployment or fixture event output.
- contract tests showing root registration and root commitment.
- pulse type semantics for `ROOTFIELD_REGISTERED`, `ROOT_COMMITTED`, and `ROOTFIELD_STATUS_CHANGED`.

Crypto to indexer:

- canonical hash inputs.
- receipt id generation.
- verifier report id generation.
- signature envelope or fixture validation rules.

Indexer to dashboard:

- observation fixture.
- verifier report fixture.
- Rootflow timeline fixture.
- AgentMemoryView fixture or endpoint.

HQ/review to all agents:

- merge order.
- non-goals.
- PR review checklist.
- current-state updates.

## Local/Test Completion

The local/test V0 milestone is complete when all of these remain true:

- Contracts tests pass.
- Crypto fixture validation passes.
- Indexer fixture parser/verifier checks pass.
- Dashboard can render fixture-backed Rootflow/Flow Memory state.
- Docs name what is implemented and what remains conceptual.
- Review agent confirms no PR claims production L1, mainnet readiness, full trustless verification, free storage, or AI running on-chain.

## Non-Goal Guardrails

Do not use this milestone to add:

- tokenomics;
- dynamic fee hooks;
- production deployment config;
- production L1 or appchain claims;
- production Uniswap v4 hook deployment;
- GPU proof systems;
- verifier economics;
- hardware manufacturing claims.
