# FlowChain Operator Checklist

Status: morning/evening checklist for the private/local testnet package.

This checklist is for HQ/Ops and second-computer validation. GitHub remains the
source of truth for issues, pull requests, reviews, and final history.

## Morning

Run from the main checkout:

```powershell
cd E:\FlowMemory\flowmemory-main
git fetch --all --prune
.\infra\scripts\status-report.ps1
gh pr list --repo FlowmemoryAI/FlowMemory --state open
gh issue list --repo FlowmemoryAI/FlowMemory --state open --limit 80
```

Check:

- Which worktrees are dirty.
- Whether `origin/main` has moved.
- Whether open PRs touch overlapping folders.
- Whether docs still match GitHub issue and PR state.
- Whether `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md` has stale statuses.
- Whether command names in `docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md` still
  match `package.json`.
- Whether any PR adds tokenomics, public validator onboarding, production
  bridge work, production hook claims, audited-cryptography claims, or
  production hardware claims.

Second-computer readiness check:

```powershell
npm run flowchain:prereq
npm run flowchain:init
npm run flowchain:start
npm run flowchain:demo
npm run flowchain:export
```

Run `npm run flowchain:smoke` when the machine has the full prerequisite set,
including Foundry, Python, dashboard dependencies, and crypto dependencies.

## During The Day

- Keep each agent in its assigned worktree and folder lane.
- If a subsystem command changes, update the wrapper script and setup guide in
  the same PR.
- If a subsystem remains missing, record the blocker and the smallest next
  issue in `docs/ISSUE_BACKLOG.md`.
- If the second-computer path fails earlier than yesterday, update
  `docs/FLOWCHAIN_TROUBLESHOOTING.md`.
- Keep the wrapper layer pointed at existing devnet, launch-core, dashboard,
  crypto, hardware, and service surfaces.

## Evening

Record:

- Merged PRs.
- Open PRs and review status.
- Dirty worktrees.
- The first failing second-computer step, if any.
- Smoke command result or the reason smoke was not run.
- New blocked rows in the private/local acceptance matrix.
- Next five issue prompts or agent assignments.

Run before handoff when dependencies are installed:

```powershell
npm run flowchain:smoke
git diff --check
```

If full smoke cannot run, record the exact skipped prerequisite or failing
command. Do not replace that with a broad "works locally" note.

## Handoff Summary Shape

End each HQ/Ops handoff with:

- What changed.
- Why it changed.
- Tests or checks run.
- Current second-computer next command.
- Risks, assumptions, and follow-ups.

