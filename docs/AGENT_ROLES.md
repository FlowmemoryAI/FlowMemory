# Agent Roles

Agents may be assigned one of these roles. Each role should still read `AGENTS.md`, `docs/START_HERE.md`, `docs/FLOWMEMORY_HQ_CONTEXT.md`, and `docs/CURRENT_STATE.md`.

## Shared Folder Boundary Rules

- Work only in the folders named by the issue or assignment.
- Treat issue "Allowed folders" as the write boundary, not just a suggestion.
- Do not edit forbidden folders even for cleanup unless the issue is updated first.
- Cross-link docs instead of moving code or expanding scope.
- If a task appears to need another agent's folder, stop and create or request a follow-up issue.

## Recommended Worktrees

- `FLOWMEMORY_WORKTREE_ROOT\flowmemory-contracts`: protocol contracts work
- `FLOWMEMORY_WORKTREE_ROOT\flowmemory-indexer`: services, indexer, and verifier work
- `FLOWMEMORY_WORKTREE_ROOT\flowmemory-dashboard`: apps, dashboard, explorer, and console work
- `FLOWMEMORY_WORKTREE_ROOT\flowmemory-hardware`: hardware, FlowRouter, LoRa, and Meshtastic work
- `FLOWMEMORY_WORKTREE_ROOT\flowmemory-research`: AI memory, neural geometry, reliability, and appchain/L1 research
- `FLOWMEMORY_WORKTREE_ROOT\flowmemory-crypto`: receipts, attestations, roots, proofs, and commitment-format work
- `FLOWMEMORY_WORKTREE_ROOT\flowmemory-review`: review, docs maintenance, templates, and repo hygiene

## Bootstrap Agent

Scope:

- Repository structure
- Shared docs
- Templates
- CI hygiene

Do not build product features.

Default worktree: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-review`

## Protocol Contracts Agent

Scope:

- `contracts/`
- Base integration
- Uniswap v4 hooks
- FlowPulse event schemas
- Rootflow and Rootfield commitment semantics

Must document event and storage assumptions.

Default worktree: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-contracts`

## Services Agent

Scope:

- `services/`
- Indexers
- Verifiers
- Workers
- APIs

Must derive `txHash` and `logIndex` from receipts and logs, not from hook execution assumptions.

Default worktree: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-indexer`

## Apps Agent

Scope:

- `apps/`
- Dashboard
- Explorer
- Hardware console

Must distinguish observed, verified, pending, and failed states in UI.

Default worktree: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-dashboard`

## Hardware Agent

Scope:

- `hardware/`
- FlowRouter
- Meshtastic and LoRa sidecars
- 3D-printed enclosures
- Field test notes

Must treat radio links as low-bandwidth control signaling.

Default worktree: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-hardware`

## Research Agent

Scope:

- `research/`
- AI memory
- Neural geometry
- Reliability research
- Appchain/L1 research

Must separate hypotheses, experiments, and accepted decisions.

Default worktree: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-research`

## Crypto Agent

Scope:

- `crypto/`
- Receipts
- Attestations
- Roots
- Proofs
- Commitment formats

Must document threat assumptions and verification requirements.

Default worktree: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-crypto`

## Infra Agent

Scope:

- `infra/`
- CI
- Scripts
- Repository automation

Must avoid leaking secrets through scripts, logs, or CI output.

Default worktree: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-review`

## Security Agent

Scope:

- Threat models
- Security reviews
- Secret handling
- Protocol and hardware risk analysis

Must create actionable issues or PR comments for findings.

Default worktree: `FLOWMEMORY_WORKTREE_ROOT\flowmemory-review`

## Handoff Format

Every agent should finish with:

- Summary
- Files changed
- Tests or checks run
- Risks and assumptions
- Recommended next issue or PR
