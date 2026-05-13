# V0 Launch Acceptance Matrix

Status: active milestone checklist.

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
| Rootfield namespaces | Contract or fixture registers `rootfieldId`; docs explain namespace policy. | Contracts | Baseline exists in `RootfieldRegistry`; policy still needs hardening. |
| Root commitments | Contract or fixture commits a nonzero root and emits/records the update. | Contracts | Baseline exists in `submitRoot`; tests need launch-grade coverage. |
| Parent/child transitions | `RootflowTransition` includes parent pulse/root and new root. | Indexer + Crypto + Contracts | Specified in `docs/ROOTFLOW_V0.md`; implementation still required. |
| FlowPulse linkage | Transition and memory signal reference `pulseId`. | Indexer + Dashboard | Specified; parser and display path still required. |
| Receipt linkage | `MemoryReceipt` links signal, artifact commitment, evidence URI, and verifier report. | Crypto + Indexer | Specified in `docs/FLOW_MEMORY_V0.md`; implementation still required. |
| Verifier statuses | Cross-agent status vocabulary exists and verifier reports use it. | Indexer + Crypto | Specified; schema/tests still required. |
| Pending state | Fixture/report can show pending transition. | Indexer + Dashboard | Required, not complete. |
| Verified state | Fixture/report can show verified transition. | Indexer + Crypto + Dashboard | Required, not complete. |
| Failed state | Fixture/report can show rejected transition. | Indexer + Dashboard | Required, not complete. |
| Reorged state | Fixture/report can show removed/superseded observation. | Indexer | Required, not complete. |
| Deterministic fixtures | Fixtures run without private RPC keys or secrets. | Indexer + Crypto + Chain | Required, not complete. |
| Dashboard-readable state | JSON/API/fixture shape feeds dashboard views. | Dashboard + Indexer | Required, not complete. |
| Flow Memory schemas | `MemorySignal`, `MemoryReceipt`, `RootfieldBundle`, and `AgentMemoryView` schemas exist. | Crypto + Indexer + Dashboard | Specified; canonical schemas still required. |
| Verifier reports | JSON schema and sample reports exist. | Indexer + Crypto | Required, not complete. |
| Dashboard display path | Dashboard renders Rootfield, transition, signal, receipt, and status data. | Dashboard | Required, not complete. |
| Source-of-truth docs | Current state, roadmap, decision record, and specs are updated. | HQ/Review | This PR adds the launch-core docs. |

## End-To-End Acceptance Test

A developer must be able to run a local V0 flow:

1. Emit or load a FlowPulse.
2. Observe it with the indexer.
3. Create or validate a receipt.
4. Commit or update a Rootfield root.
5. Produce a Rootflow transition.
6. Show the resulting Flow Memory state in the dashboard.

The final acceptance evidence should include:

- exact commands run;
- fixture paths;
- output paths;
- screenshots or dashboard verification notes when UI exists;
- test results;
- PR links for each subsystem.

## Required Agent Handoffs

Contracts to indexer:

- FlowPulse event ABI.
- RootfieldRegistry ABI.
- local deployment or fixture event output.
- contract tests showing root registration and root commitment.

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

## Merge Readiness

The milestone is not ready to call complete until all of these are true:

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
