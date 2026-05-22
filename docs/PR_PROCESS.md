# Pull Request Process

FlowMemory uses small, scoped pull requests from dedicated worktrees. GitHub is the source of truth for PR state, review, and merge history.

## Branch Naming

Use one branch per issue:

```text
agent/<area>-issue-<number>-short-title
```

Examples:

- `agent/contracts-issue-6-foundry-config`
- `agent/indexer-issue-43-flowpulse-parser`
- `agent/review-issue-20-foundation-review`

Use `hq/<short-title>` only for HQ operating-system work that spans docs, templates, scripts, labels, or milestones.

## Draft PRs

Open a draft PR as soon as a branch has a coherent direction and useful file ownership is visible.

Draft PRs should include:

- Linked issue number.
- Allowed folders.
- Forbidden folders.
- Worktree path.
- Current checklist state.
- Known blockers.

## Review Requirements

Every PR must show:

- It is tied to one primary issue.
- Changed files stay inside allowed folders.
- Forbidden folders were not touched.
- `git diff --check` passed.
- Area-specific tests or checks were run, or the PR explains why none exist.
- The PR does not add gated work such as tokenomics, dynamic fees, production deployment, production L1/appchain, production hooks, hardware manufacturing, GPU proofs, verifier economics, or full dashboard implementation.

## Merge Order

Preferred order:

1. Repo OS, templates, labels, milestones, runbooks, and review process.
2. Current-state, roadmap, architecture, and decision-record updates.
3. Contracts foundation hardening.
4. Indexer/verifier fixtures and schemas.
5. Crypto vocabulary and validation boundaries.
6. Dashboard data model.
7. Hardware POC specs.
8. Research docs.

When two PRs touch the same file, merge the source-of-truth or reviewer PR first, then rebase or update the dependent PR.

## Avoiding Conflicts

- Start each agent from its assigned worktree.
- Run `git fetch --all --prune` before starting.
- Run `git status --short --branch` before editing.
- Keep issue scope to one folder family when possible.
- Use cross-links instead of moving files across agent boundaries.
- Do not edit another agent's folder unless the issue explicitly allows it.
- If a second folder becomes necessary, create or request a follow-up issue.

## Dirty Worktrees

Dirty worktrees are expected in multi-agent work, but they must be explicit.

Before assigning an agent:

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-main
.\infra\scripts\status-report.ps1
```

If a worktree is dirty:

- Identify whether the dirty files match the assigned issue.
- Do not reuse that worktree for unrelated work.
- Commit, stash, or move the work only with explicit operator intent.
- Never discard changes made by another agent without approval.

## Closing Issues

Close an issue only when:

- Acceptance criteria are met.
- The PR is merged.
- Required docs are updated.
- Tests or checks are recorded.
- Follow-up issues exist for deferred work.

Use closing keywords only when the PR fully satisfies the issue:

```text
Closes #<issue>
```

Use weaker references when partial:

```text
Refs #<issue>
```

## Emergency Scope Stop

Stop and ask for HQ review if a PR starts adding:

- Tokenomics.
- Dynamic fees.
- Mainnet or production deployment.
- Production Uniswap v4 hook deployment.
- Production L1/appchain implementation.
- Hardware manufacturing or production field deployment.
- GPU proofs or verifier economics.
- Full dashboard implementation.
