# Worker And Verifier Registry v0 Boundary

Date: 2026-05-13

## Status

Accepted

## Context

FlowMemory needs identity surfaces for workers and verifiers before building scheduling, receipt, report, or hook integrations. V0 should make identities observable without implying economics, Sybil resistance, or production trust.

## Decision

WorkerRegistry and VerifierRegistry v0 are self-registration registries. An address registers its own `operatorId`, `role`, and metadata commitment, and may later update metadata or deactivate itself.

Registration does not prove real-world identity, competence, stake, reputation, uniqueness, or authorization to earn rewards. It is a lightweight on-chain identity and metadata commitment surface.

## Authorization Semantics

Self-registration is not the same as permission to submit work receipts or verifier reports. WorkReceiptRegistry and VerifierReportRegistry use their own owner-controlled allowlists in v0. Future versions may connect these registries, require attestations, or introduce governance-controlled authorization.

## Status Lifecycle

V0 supports:

- unregistered
- active after self-registration
- inactive after self-deactivation

Inactive records remain historical records. V0 does not support reactivation, delegated administration, third-party suspension, governance slashing, or recovery.

## Intentionally Excluded

- Token staking
- Rewards
- Slashing
- Reputation scoring
- Sybil resistance
- Real-world identity verification
- Delegated updates
- Governance-managed allowlists
- Production audit claims

## Future Options

Future versions should decide whether worker and verifier authorization uses allowlists, signed attestations, staking, governance, decentralized identity, or links to off-chain indexer identity specs.
