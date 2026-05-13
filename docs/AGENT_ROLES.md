# Agent Roles

Agents may be assigned one of these roles. Each role should still read `AGENTS.md`, `docs/START_HERE.md`, `docs/FLOWMEMORY_HQ_CONTEXT.md`, and `docs/CURRENT_STATE.md`.

## Shared Folder Boundary Rules

- Work only in the folders named by the issue or assignment.
- Treat issue "Allowed folders" as the write boundary, not just a suggestion.
- Do not edit forbidden folders even for cleanup unless the issue is updated first.
- Cross-link docs instead of moving code or expanding scope.
- If a task appears to need another agent's folder, stop and create or request a follow-up issue.

## Recommended Worktrees

- `E:\FlowMemory\flowmemory-contracts`: protocol contracts work
- `E:\FlowMemory\flowmemory-indexer`: services, indexer, and verifier work
- `E:\FlowMemory\flowmemory-dashboard`: apps, dashboard, explorer, and console work
- `E:\FlowMemory\flowmemory-hardware`: hardware, FlowRouter, LoRa, and Meshtastic work
- `E:\FlowMemory\flowmemory-research`: AI memory, neural geometry, reliability, and appchain/L1 research
- `E:\FlowMemory\flowmemory-crypto`: receipts, attestations, roots, proofs, and commitment-format work
- `E:\FlowMemory\flowmemory-review`: review, docs maintenance, templates, and repo hygiene

## Bootstrap Agent

Scope:

- Repository structure
- Shared docs
- Templates
- CI hygiene

Do not build product features.

Default worktree: `E:\FlowMemory\flowmemory-review`

## Protocol Contracts Agent

Scope:

- `contracts/`
- Base integration
- Uniswap v4 hooks
- FlowPulse event schemas
- Rootflow and Rootfield commitment semantics

Must document event and storage assumptions.

Default worktree: `E:\FlowMemory\flowmemory-contracts`

## Services Agent

Scope:

- `services/`
- Indexers
- Verifiers
- Workers
- APIs

Must derive `txHash` and `logIndex` from receipts and logs, not from hook execution assumptions.

Default worktree: `E:\FlowMemory\flowmemory-indexer`

## Apps Agent

Scope:

- `apps/`
- Dashboard
- Explorer
- Hardware console

Must distinguish observed, verified, pending, and failed states in UI.

Default worktree: `E:\FlowMemory\flowmemory-dashboard`

## Hardware Agent

Scope:

- `hardware/`
- FlowRouter
- Meshtastic and LoRa sidecars
- 3D-printed enclosures
- Field test notes

Must treat radio links as low-bandwidth control signaling.

Default worktree: `E:\FlowMemory\flowmemory-hardware`

## Research Agent

Scope:

- `research/`
- AI memory
- Neural geometry
- Reliability research
- Appchain/L1 research

Must separate hypotheses, experiments, and accepted decisions.

Default worktree: `E:\FlowMemory\flowmemory-research`

## Crypto Agent

Scope:

- `crypto/`
- Receipts
- Attestations
- Roots
- Proofs
- Commitment formats

Must document threat assumptions and verification requirements.

Default worktree: `E:\FlowMemory\flowmemory-crypto`

## Infra Agent

Scope:

- `infra/`
- CI
- Scripts
- Repository automation

Must avoid leaking secrets through scripts, logs, or CI output.

Default worktree: `E:\FlowMemory\flowmemory-review`

## Security Agent

Scope:

- Threat models
- Security reviews
- Secret handling
- Protocol and hardware risk analysis

Must create actionable issues or PR comments for findings.

Default worktree: `E:\FlowMemory\flowmemory-review`

## Handoff Format

Every agent should finish with:

- Summary
- Files changed
- Tests or checks run
- Risks and assumptions
- Recommended next issue or PR
