# Daily HQ Runbook

This runbook is for the FlowMemory HQ operator. It keeps many Codex agents moving without overlapping folders or expanding into premature product work.

## Morning Review

Run:

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-main
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
- Public launch issues and gaps in `docs/PUBLIC_RELEASE_GAPS.md`.
- Rootflow and Flow Memory launch-core issues #63 through #67.
- Evidence gaps in `docs/V0_LAUNCH_ACCEPTANCE.md`.
- Current audit notes in `docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md`.

## Public Launch Checklist

Morning:

- Confirm GitHub open PRs and issues still match `docs/CURRENT_STATE.md` and `docs/ISSUE_BACKLOG.md`.
- Confirm `README.md`, `docs/PUBLIC_REPO_GUIDE.md`, `docs/PUBLIC_TESTER_GUIDE.md`, `docs/MOBILE_APPS.md`, and `docs/PUBLIC_RELEASE_GAPS.md` agree on product scope.
- Check all sibling worktrees for dirty changes before assigning agents.
- Verify no two active agents are editing the same folder family or source-of-truth doc without coordination.
- Run or queue `npm run public:hardening` and `npm run public:test:all` before any public-launch merge.
- Confirm the next assigned work extends the existing contracts, services, dashboard, mobile, hardware, crypto, or research surface instead of adding a replacement system.
- Keep public tokenomics, public validator, value-bearing bridge, audited-cryptography, production hook, hosted production API, and production hardware claims blocked unless a later issue explicitly scopes them.

Evening:

- Record merged PRs, open PRs, dirty worktrees, blockers, and next smallest public-launch actions.
- Update `docs/CURRENT_STATE.md`, `docs/ROADMAP.md`, and `docs/ISSUE_BACKLOG.md` if a merge changes implemented, in-flight, missing, or later-gated state.
- Require `git diff --check` in each PR summary and area tests where the touched area has tests.
- Re-run public claim guardrails if README, docs, issue templates, CI, dashboard copy, mobile docs, or release workflows changed.

## Issue Triage

For each issue:

- Confirm objective is concrete.
- Confirm allowed folders and forbidden folders.
- Confirm risk level.
- Confirm recommended worktree/agent.
- Confirm dependencies in `docs/ISSUE_BACKLOG.md`.
- Add missing labels or milestones before starting work.

Priority order:

1. Public repo OS and review process.
2. Rootflow and Flow Memory V0 launch-core issues #63 through #67.
3. Public-agent and Agent Bonds launch hardening.
4. Mobile operator app packaging and iOS gap tracking.
5. Contracts foundation hardening.
6. Crypto vocabulary and deterministic fixtures.
7. Indexer/verifier fixture and schema work.
8. Dashboard fixture-backed display path.
9. Hardware POC specs.
10. Research gates.

## Starting Agents

Use one terminal per agent:

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-contracts
codex
```

Give the agent the prompt from `docs/AGENT_PROMPTS.md` plus the assigned issue number.

For Rootflow V0 and Flow Memory V0 launch-core work, use `docs/LAUNCH_CORE_AGENT_GOALS.md`.

Do not start two agents on the same folder family unless the changed files are clearly disjoint.

## Monitoring PRs

For each open PR:

- Check issue linkage.
- Check changed files.
- Check `git diff --check` result.
- Check area-specific tests or documented absence.
- Check for scope creep.
- Check whether docs/current state need updates.
- Check whether the PR satisfies named rows in `docs/V0_LAUNCH_ACCEPTANCE.md` or public release gaps.

Reject or send back any PR that adds:

- Tokenomics.
- Dynamic fees.
- Production deployment.
- Production Uniswap v4 hook deployment.
- Hardware manufacturing or production field deployment.
- GPU proofs or verifier economics.
- Full dashboard replacement instead of fixture-backed launch views.

## Merge Order

Prefer:

1. Repo OS, labels, milestones, PR process, runbook.
2. Public launch docs, claim guardrails, and public tester lanes.
3. Rootflow and Flow Memory specs, current-state, roadmap, architecture, decision records.
4. Contracts test/config hardening.
5. Crypto vocabulary and launch-core fixtures.
6. Indexer/verifier fixture/spec changes.
7. Dashboard and mobile operator surfaces.
8. Hardware scope docs.
9. Research docs.

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
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-main
.\infra\scripts\status-report.ps1
```
