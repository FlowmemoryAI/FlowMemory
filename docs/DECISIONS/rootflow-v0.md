# Decision: Rootflow V0 Launch Core

Date: 2026-05-13

Status: Accepted for V0 planning.

## Context

FlowMemory needs a launch-critical core that connects Base or local contract events to AI-readable memory without claiming that the full future dedicated network, proof network, or hardware network is complete.

The merged contracts foundation already includes `FlowPulse` and a baseline `RootfieldRegistry`, but Rootflow and the Flow Memory layer need a shared definition before builders can safely implement contracts, crypto fixtures, indexer/verifier logic, and dashboard views.

## Decision

Rootflow V0 is the cross-layer state-transition model for FlowMemory.

Flow Memory V0 is the agent-facing memory layer built from FlowPulse observations, Rootflow transitions, receipts, verifier reports, and committed roots.

Rootflow V0 must remain compact and receipt-oriented:

- contracts emit FlowPulse events and store intentional compact state;
- indexers derive receipt metadata such as `txHash` and `logIndex`;
- crypto packages define canonical serialization, ids, signatures, and fixture validation;
- verifiers assign launch vocabulary statuses;
- dashboards render Rootfield, Rootflow, receipt, and memory state;
- heavy AI/model/memory/artifact data stays off-chain.

The minimum shared status set is:

- `observed`
- `pending`
- `verified`
- `failed`
- `reorged`
- `unsupported`

## Consequences

Builder agents can work in parallel without redefining the product core:

- Contracts agent owns compact on-chain state and FlowPulse emission.
- Crypto agent owns canonical object shapes, hashes, receipts, and fixtures.
- Indexer/verifier agent owns observation identity, transition construction, reports, and status handling.
- Dashboard agent owns the operator and agent-readable display path.
- HQ/review owns docs, acceptance matrix, merge order, and claim discipline.

The launch acceptance test is an end-to-end local V0 flow:

1. emit or load a FlowPulse;
2. observe it with the indexer;
3. create or validate a receipt;
4. commit or update a Rootfield root;
5. produce a Rootflow transition;
6. show the resulting Flow Memory state in the dashboard.

## Boundaries

This decision does not approve:

- separate production network or dedicated-network claims;
- production mainnet deployment;
- production Uniswap v4 hook deployment;
- tokenomics;
- dynamic fees;
- full trustless verifier network claims;
- free-storage claims;
- AI-running-on-chain claims;
- hardware trustlessness claims without verifier/proof infrastructure.
