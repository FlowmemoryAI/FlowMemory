# Daily HQ Runbook

This runbook is for the FlowMemory HQ operator. It keeps many Codex agents moving without overlapping folders or expanding into premature product work.

Private/local testnet checklist companion:
`docs/FLOWCHAIN_OPERATOR_CHECKLIST.md`. Troubleshooting companion:
`docs/FLOWCHAIN_TROUBLESHOOTING.md`.

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
- Rootflow and Flow Memory launch-core issues #63 through #67.
- Evidence gaps in `docs/V0_LAUNCH_ACCEPTANCE.md`.
- Current audit notes in `docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md`.

## FlowChain Full-Testnet Push Checklist

Morning:

- Confirm GitHub open PRs and issues still match `docs/CURRENT_STATE.md` and
  `docs/ISSUE_BACKLOG.md`.
- Check all sibling worktrees for dirty changes before assigning agents.
- Verify no two active agents are editing the same folder family or source-of-truth
  doc without coordination.
- Review `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md` for rows that changed from
  missing to in flight or implemented after merges.
- Verify root command aliases in `package.json` still match the scripts under
  `infra/scripts/flowchain-*.ps1`.
- Confirm the next assigned work extends the existing devnet, control-plane,
  crypto, dashboard, contracts, hardware, or research surface instead of adding
  a replacement system.
- Keep production L1, tokenomics, public validator, production bridge, audited
  cryptography, production hook, and production hardware claims blocked.

Evening:

- Record merged PRs, open PRs, dirty worktrees, blockers, and next smallest
  actions for the private/local testnet package.
- Update `docs/CURRENT_STATE.md`, `docs/ROADMAP.md`, and
  `docs/ISSUE_BACKLOG.md` if a merge changes implemented, in-flight, missing,
  or later-gated state.
- Update `docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md` whenever a command lands or
  a command name changes.
- Check whether the second-computer path can now run farther than the previous
  day, and name the first failing step.
- Save or cite `devnet/local/smoke/flowchain-smoke-report.json` when full smoke
  runs locally.
- Require `git diff --check` in each PR summary and area tests where the touched
  area has tests.

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
2. Rootflow and Flow Memory V0 launch-core issues #63 through #67.
3. Contracts foundation hardening.
4. Crypto vocabulary and deterministic fixtures.
5. Indexer/verifier fixture and schema work.
6. Dashboard fixture-backed display path.
7. Hardware POC specs.
8. Research gates.

## Starting Agents

Use one terminal per agent:

```powershell
cd E:\FlowMemory\flowmemory-contracts
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
- Check whether the PR satisfies named rows in `docs/V0_LAUNCH_ACCEPTANCE.md`.

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
2. Rootflow and Flow Memory specs, current-state, roadmap, architecture, decision records.
3. Contracts test/config hardening.
4. Crypto vocabulary and launch-core fixtures.
5. Indexer/verifier fixture/spec changes.
6. Dashboard fixture-backed display path.
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
