# Decision: Base Sepolia Reader And Claim Guardrails

Date: 2026-05-13

## Status

Accepted for V0 hardening.

## Context

FlowMemory needs a launch-critical path beyond fixtures, but it must not jump to production-mainnet claims. The next useful step is a constrained Base Sepolia reader that can observe FlowPulse logs from explicit contract addresses and persist durable local state.

The project also needs stronger protection against unsafe launch language as docs and marketing work accelerate.

## Decision

- Add a Base Sepolia-only FlowPulse reader path in `services/indexer`.
- Require an explicit RPC URL and explicit emitting contract addresses.
- Reject RPC endpoints unless `eth_chainId` is Base Sepolia (`84532`).
- Persist both canonical indexer state and a Base Sepolia checkpoint.
- Add contracts hardening docs for static analysis, deployment boundary, and access-control review.
- Add CI claim guardrails that scan `README.md`, `docs/`, and `marketing/` if present.

## Non-Goals

- No Base mainnet reader by default.
- No production indexer service.
- No production verifier network.
- No production L1 or mainnet readiness claim.
- No free-storage claim.
- No claim that AI runs on-chain.

## Consequences

Developers can test the first live reader path against Base Sepolia while keeping production claims blocked. Marketing and README changes now have a CI-backed guardrail for the highest-risk overclaims.
