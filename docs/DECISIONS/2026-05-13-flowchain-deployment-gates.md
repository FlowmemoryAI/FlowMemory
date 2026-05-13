# FlowChain Deployment Gates

Date: 2026-05-13

## Status

Accepted for research and future implementation gating.

## Context

FlowMemory has merged V0 launch-core contracts, crypto helpers, fixture-first services, a dashboard, a no-value local devnet prototype, and guarded Base canary evidence. The research packet also includes Noesis, Rootflow, Claude/RD, Octra, FlowMemory, and FlowChain ideas that could easily be over-scoped into a public L1, token, bridge, or proof-system project before the local object model is proven.

The current Ralph loop needs builders to know what is allowed now and what is later.

## Decision

FlowChain work must use three deployment gates:

1. **Local/private testnet**: local-alpha target. This is a no-value, second-computer-validatable package for FlowMemory object-state testing. It may harden the local runtime, API, workbench, explorer, provenance, crypto vectors, operator-vault boundary, release manifest, and smoke flow after the relevant implementation agents accept scope.
2. **Public devnet**: later research and blocked until the local/private testnet package is reproducible, monitored, exportable/importable, and reviewed. Public devnet planning may document operator roles, DA assumptions, monitoring, reset/halt policy, and threat models. It may not introduce tokenomics.
3. **Public L1/mainnet**: explicitly later and blocked. A production or value-bearing chain requires a separate readiness program, independent reviews, bridge/DA/security work, production verifier design, incident response, governance/upgrade policy, and explicit accepted decisions.

The current research task does not authorize implementation outside `research/`, `chain/` docs, or `docs/DECISIONS/`.

## Alternatives Considered

- **Start public devnet work immediately**: rejected because the local/private object model, challenge/finality flow, private-state boundary, and release package are not proven.
- **Treat the Base canary as production readiness**: rejected because the canary is V0 testing evidence only.
- **Skip local/private testnet and choose an L1 framework now**: rejected because the project has not proven that receipt, memory, dependency, verifier, challenge, and finality objects must be native chain state.

## Consequences

- Builders can target a local/private no-value package without importing public-network scope.
- Public devnet and public L1/mainnet work remain blocked behind named evidence.
- Octra-level control-plane lessons become local acceptance criteria, not a reason to chase bridge or encrypted-coprocessor scope.
- The master L1 question remains unresolved until local evidence proves native receipt/memory state is stronger than app-level logs on an existing chain.

## Scope Boundaries

This decision does not approve:

- production validators or sequencers;
- tokenomics, staking, rewards, fees, slashing, or validator economics;
- public L1/mainnet launch planning;
- value-bearing bridge work;
- production encrypted compute;
- production proof systems;
- production Uniswap v4 hook deployment;
- hardware validator, sequencer, DA, or bridge roles.

## Follow-Ups

- Use `research/flowchain-local-alpha/L1_GO_NO_GO_GATES.md` as the gate checklist.
- Use `research/flowchain-local-alpha/OCTRA_COMPETENCY_BAR.md` for the local control-plane bar.
- Use `research/flowchain-local-alpha/BLOCKED_AND_LATER.md` before assigning implementation work.
- Create separate implementation issues only after the owning agents accept folder scope and tests.
