# Worktree Assignments

Use this guide when assigning issue-scoped work across dedicated FlowMemory worktrees. Keep each assignment tied to a GitHub issue, a bounded file scope, acceptance criteria, and the checks that prove the work is safe to review.

## Common Assignment Rules

Every assignment should include:

- GitHub issue number or explicit task owner.
- Objective.
- Allowed folders.
- Forbidden folders.
- Acceptance criteria.
- Risk level.
- Worktree path and branch.
- Required checks before handoff.

Default rules:

- Work only on the assigned issue or task.
- Do not build outside the named scope.
- Do not add tokenomics, dynamic fees, production deployment, production Uniswap v4 hook deployment, separate production network, hardware manufacturing, GPU proofs, verifier economics, or full dashboard implementation unless the issue explicitly allows it.
- Before finishing, run `git status --short --branch`, `git diff --check`, and area-specific tests where they exist.
- Handoffs must name changed files, checks run, remaining risks, assumptions, and follow-up issues.

## Worktree Lanes

| Lane | Worktree | Default allowed scope | Default checks |
| --- | --- | --- | --- |
| Contracts | `FLOWMEMORY_WORKTREE_ROOT\flowmemory-contracts` | `contracts/`, `tests/`, `foundry.toml`, contract decision records when scoped | `forge test`, `git diff --check` |
| Indexer / verifier | `FLOWMEMORY_WORKTREE_ROOT\flowmemory-indexer` | `services/indexer/`, `services/verifier/`, scoped shared docs | Relevant service tests, schema or fixture validation, `git diff --check` |
| Dashboard | `FLOWMEMORY_WORKTREE_ROOT\flowmemory-dashboard` | `apps/dashboard/`, dashboard fixtures and schemas when scoped | `npm test --prefix apps/dashboard`, `npm run build --prefix apps/dashboard`, `git diff --check` |
| Hardware | `FLOWMEMORY_WORKTREE_ROOT\flowmemory-hardware` | `hardware/`, hardware docs, simulator fixtures | Simulator or schema checks when touched, `git diff --check` |
| Research | `FLOWMEMORY_WORKTREE_ROOT\flowmemory-research` | `research/`, `docs/DECISIONS/`, architecture/security docs when scoped | Documented source review, `git diff --check` |
| Crypto | `FLOWMEMORY_WORKTREE_ROOT\flowmemory-crypto` | `crypto/`, crypto schemas, crypto fixtures | `npm test --prefix crypto`, vector validation, `git diff --check` |
| Review / program | `FLOWMEMORY_WORKTREE_ROOT\flowmemory-review` | `.github/`, `docs/`, `infra/scripts/`, `README.md`, `AGENTS.md` | Public hardening or area-specific checks, `git diff --check` |

## Launch-Core Add-On

Use this add-on when an issue mentions Rootflow V0, Flow Memory V0, launch core, memory signals, Rootfield bundles, verifier reports, receipts, or dashboard-readable state.

Rootflow V0 must connect:

- Rootfield namespace.
- FlowPulse pulse id.
- Parent pulse or parent root.
- New root.
- Receipt id.
- Verifier report id.
- Status.
- Source observation.

Flow Memory V0 must expose:

- MemorySignal.
- MemoryReceipt.
- RootfieldBundle.
- AgentMemoryView.

Use deterministic local fixtures before live production integrations. Do not claim separate production network, production mainnet readiness, full trustless verification, free storage, or AI running on-chain.

Before finishing launch-core work, name exactly which `docs/V0_LAUNCH_ACCEPTANCE.md` rows are satisfied and which remain incomplete.

## PR Summary Format

```md
## Summary
- Summarize the user-visible or maintainer-visible change.

## Scope
- Issue:
- Allowed folders:
- Forbidden folders:
- Worktree:
- Risk level:

## Checks
- [ ] git status --short --branch
- [ ] git diff --check
- [ ] Area-specific tests/checks:

## Risks And Follow-Ups
- Name remaining risks, assumptions, rollout notes, or follow-up issues. If there are none, write `None`.
```
