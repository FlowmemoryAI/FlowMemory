# Agent Roles

Agents may be assigned one of these roles. Each role should still read `AGENTS.md`, `docs/START_HERE.md`, `docs/FLOWMEMORY_HQ_CONTEXT.md`, and `docs/CURRENT_STATE.md`.

## Bootstrap Agent

Scope:

- Repository structure
- Shared docs
- Templates
- CI hygiene

Do not build product features.

## Protocol Contracts Agent

Scope:

- `contracts/`
- Base integration
- Uniswap v4 hooks
- FlowPulse event schemas
- Rootflow and Rootfield commitment semantics

Must document event and storage assumptions.

## Services Agent

Scope:

- `services/`
- Indexers
- Verifiers
- Workers
- APIs

Must derive `txHash` and `logIndex` from receipts and logs, not from hook execution assumptions.

## Apps Agent

Scope:

- `apps/`
- Dashboard
- Explorer
- Hardware console

Must distinguish observed, verified, pending, and failed states in UI.

## Hardware Agent

Scope:

- `hardware/`
- FlowRouter
- Meshtastic and LoRa sidecars
- 3D-printed enclosures
- Field test notes

Must treat radio links as low-bandwidth control signaling.

## Research Agent

Scope:

- `research/`
- AI memory
- Neural geometry
- Reliability research
- Appchain/L1 research

Must separate hypotheses, experiments, and accepted decisions.

## Crypto Agent

Scope:

- `crypto/`
- Receipts
- Attestations
- Roots
- Proofs
- Commitment formats

Must document threat assumptions and verification requirements.

## Infra Agent

Scope:

- `infra/`
- CI
- Scripts
- Repository automation

Must avoid leaking secrets through scripts, logs, or CI output.

## Security Agent

Scope:

- Threat models
- Security reviews
- Secret handling
- Protocol and hardware risk analysis

Must create actionable issues or PR comments for findings.

## Handoff Format

Every agent should finish with:

- Summary
- Files changed
- Tests or checks run
- Risks and assumptions
- Recommended next issue or PR
