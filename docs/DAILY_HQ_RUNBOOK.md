# Daily HQ Runbook

This runbook is for the FlowMemory HQ operator. It keeps many Codex agents moving without overlapping folders or expanding into premature product work.

## Morning Review

Run:

```powershell
cd E:\FlowMemory\flowmemory-main
git fetch --all --prune
.\infra\scripts\status-report.ps1
gh pr list --repo FlowmemoryAI/FlowMemory --state open
gh issue list --repo FlowmemoryAI/FlowMemory --state open --limit 80
```

Check:

- Dirty worktrees.
- Open PRs and changed file scope.
- Blocked issues.
- Issues missing labels or milestones.
- Any PR touching forbidden folders.

## Issue Triage

For each issue:

- Confirm objective is concrete.
- Confirm allowed folders and forbidden folders.
- Confirm risk level.
- Confirm recommended worktree/agent.
- Confirm dependencies in `docs/ISSUE_BACKLOG.md`.
- Add missing labels or milestones before starting work.

Priority order:

1. Repo OS and review process.
2. Contracts foundation hardening.
3. Indexer/verifier fixture and schema work.
4. Crypto vocabulary.
5. Dashboard data model.
6. Hardware POC specs.
7. Research gates.

## Starting Agents

Use one terminal per agent:

```powershell
cd E:\FlowMemory\flowmemory-contracts
codex
```

Give the agent the prompt from `docs/AGENT_PROMPTS.md` plus the assigned issue number.

Do not start two agents on the same folder family unless the changed files are clearly disjoint.

## Monitoring PRs

For each open PR:

- Check issue linkage.
- Check changed files.
- Check `git diff --check` result.
- Check area-specific tests or documented absence.
- Check for scope creep.
- Check whether docs/current state need updates.

Reject or send back any PR that adds:

- Tokenomics.
- Dynamic fees.
- Production deployment.
- Production L1/appchain implementation.
- Production Uniswap v4 hook deployment.
- Hardware manufacturing or production field deployment.
- GPU proofs or verifier economics.
- Full dashboard implementation.

## Merge Order

Prefer:

1. Repo OS, labels, milestones, PR process, runbook.
2. Current-state, roadmap, architecture, decision records.
3. Contracts test/config hardening.
4. Indexer/verifier fixture/spec changes.
5. Crypto vocabulary.
6. Dashboard data model.
7. Hardware scope docs.
8. Research docs.

If two PRs touch the same source-of-truth doc, merge the one that updates shared process first and ask the second PR to rebase or refresh.

## Updating Current State

Update `docs/CURRENT_STATE.md` when a merge changes:

- Implemented files or systems.
- Conceptual/not-implemented status.
- Active boundaries.
- Major issue or milestone organization.
- Agent workflow expectations.

Do not update it for unmerged local work unless the note clearly says the work is not source of truth.

## End-Of-Day Handoff

Record:

- Merged PRs.
- Open PRs and review status.
- Dirty worktrees.
- Blocked issues.
- Next five priorities.
- Any scope creep stopped.
- Any docs that need source-of-truth updates tomorrow.

Suggested command:

```powershell
cd E:\FlowMemory\flowmemory-main
.\infra\scripts\status-report.ps1
```
