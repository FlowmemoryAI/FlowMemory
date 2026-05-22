# Launch-Core Generated FlowMemory V0

Date: 2026-05-13

## Status

Accepted for local/test V0 fixtures.

## Context

FlowMemory needed a single local acceptance path that connected previously separate V0 components:

- FlowPulse fixture observations.
- Indexer output.
- Verifier reports.
- Rootflow transitions.
- Flow Memory objects.
- Dashboard-readable state.
- Local no-value local test runtime handoff output.
- FlowRouter hardware POC fixture output.

Before this decision, each subsystem had useful local fixtures, but the project did not have one command that regenerated the launch-core state end to end.

## Decision

The repo now uses `npm run launch:v0` as the local launch-core acceptance command.

The command:

1. runs the indexer fixture command;
2. runs the verifier fixture command;
3. runs the no-value local test runtime demo handoff;
4. validates the FlowRouter hardware POC fixture;
5. generates Rootflow and Flow Memory V0 state;
6. writes the dashboard fixture and runtime data.

Generated canonical outputs:

- `fixtures/launch-core/flowmemory-launch-v0.json`
- `fixtures/launch-core/rootflow-transitions.json`
- `fixtures/dashboard/flowmemory-dashboard-v0.json`
- `apps/dashboard/public/data/flowmemory-dashboard-v0.json`
- `fixtures/launch-core/generated/local test runtime/`

Canonical schema files:

- `schemas/flowmemory/memory-signal.schema.json`
- `schemas/flowmemory/memory-receipt.schema.json`
- `schemas/flowmemory/rootflow-transition.schema.json`
- `schemas/flowmemory/rootfield-bundle.schema.json`
- `schemas/flowmemory/agent-memory-view.schema.json`

Verifier report statuses remain internal verifier results. The explicit adapter is:

- `valid` -> `verified`
- `invalid` -> `failed`
- `unresolved` -> `unresolved`
- `unsupported` -> `unsupported`
- `reorged` -> `reorged`

## Boundaries

This is local/test V0 only. It is not a separate production network, production Uniswap v4 deployment, hosted verifier network, proof system, production hardware deployment, or claim that AI runs on-chain.

Heavy memory/model/artifact data remains off-chain. The generated files contain roots, receipts, observations, commitments, reports, status mappings, and fixture metadata only.

## Consequences

- Dashboard V0 now consumes generated state rather than only hand-maintained dashboard data.
- Rootflow transitions are concrete generated objects, not only documentation.
- Flow Memory object shapes have canonical local JSON schema files.
- GitHub CI can run area-specific checks beyond repository hygiene.

## Follow-Ups

- Add richer schema validation if the repo adopts a JSON Schema validator dependency.
- Add live RPC indexing only after fixture behavior remains stable.
- Keep production deployment, tokenomics, verifier economics, and dedicated-network planning gated behind separate decisions.
