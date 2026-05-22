# FlowChain Local Alpha Research Pack

Last updated: 2026-05-13

Status: research gate index. This package does not authorize product code, public networks, tokenomics, bridges, production proof systems, encrypted compute, or production deployment.

## Purpose

This directory turns the FlowMemory, Rootflow, legacy AI-native state research, external RD, and external local-chain reference research into practical gates for the local/private FlowChain testnet direction.

The only near-term build target this pack supports is a no-value local/private testnet package that proves the FlowMemory object model on a second computer.

## Source Status

Use GitHub as source of truth. This worktree is behind `origin/main` by two commits at the time of this pass, so implemented facts may be sourced from either local `docs/CURRENT_STATE.md` or `origin/main` on 2026-05-13.

## Reading Order

1. `ARCHITECTURE_REFERENCE.md`: local-alpha architecture boundary and object model direction.
2. `L1_GO_NO_GO_GATES.md`: local/private, public devnet, and public L1/mainnet gates.
3. `OCTRA_COMPETENCY_BAR.md`: concrete local-control-plane surface bar.
4. `CRYPTOGRAPHY_RESEARCH_MAP.md`: Process-Witness, SEAL, Synthetic Non-Amplification, proof-carrying receipt, and crypto-library boundaries.
5. `PRIVATE_STATE_ROADMAP.md`: vault, private references, dependency privacy, and encrypted-compute sequence.
6. `BLOCKED_AND_LATER.md`: explicit stop list and smallest useful next steps.

## Current Gate Summary

| Gate | Status | Builder meaning |
| --- | --- | --- |
| Local/private testnet | Local-alpha target | Requirements may move to implementation only in the owning folders after accepted schemas, tests, and issue scope exist. |
| Public devnet | Later research, Blocked | Requirements drafting and threat modeling only; no public launch. |
| Public L1/mainnet | Explicitly later, Blocked | No implementation, launch planning, tokenomics, bridge deployment, or production proof claims. |

## Decision Records

- `docs/DECISIONS/2026-05-13-flowchain-deployment-gates.md`
- `docs/DECISIONS/2026-05-13-flowchain-proof-private-state-boundary.md`
- `docs/DECISIONS/2026-05-13-flowchain-local-alpha-control-plane-boundary.md`

## Non-Negotiable Boundary

Every future claim must be labeled as implemented, local-alpha target, later research, blocked, or explicitly later. Unlabeled public-chain, production-proof, token, bridge, validator, encrypted-compute, or mainnet claims should be treated as blocked.
