# Start Here

This is the first document to read after `AGENTS.md`.

## Reading Order

1. `AGENTS.md`
2. `docs/FLOWMEMORY_HQ_CONTEXT.md`
3. `docs/CURRENT_STATE.md`
4. `docs/PUBLIC_REPO_GUIDE.md` for public-reader orientation, repository map, verification commands, and gap links
5. `docs/PUBLIC_TESTER_GUIDE.md` for external tester lanes, expected results, and report format
6. `docs/PUBLIC_AGENT_NETWORK_TECHNICAL_GUIDE.md` for public-agent network implementation details
7. `docs/ROOTFLOW_V0.md`, `docs/FLOW_MEMORY_V0.md`, and `docs/V0_LAUNCH_ACCEPTANCE.md` for launch-core work
8. The task-specific document or issue
9. Any relevant decision records in `docs/DECISIONS/`

## Before You Edit

- Confirm the assigned scope.
- Check the current branch and working tree.
- Read the files you plan to edit.
- Identify whether the task is docs, protocol, service, app, hardware, research, crypto, infra, or security work.
- If working from an issue, copy its allowed folders, forbidden folders, acceptance criteria, risk level, and recommended worktree into your local plan before editing.
- If the task touches architecture, security assumptions, public schemas, or cross-agent workflow, update docs in the same pull request.
- If local files disagree with GitHub issue or pull request state, stop and reconcile the difference before editing.

## Multi-Agent Worktree Setup

Use one Git worktree per Codex agent. Each worktree has its own branch and folder under `FLOWMEMORY_WORKTREE_ROOT`, so agents can work without sharing the same checkout.

Start from the main checkout:

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-main
.\infra\scripts\setup-worktrees.ps1
```

The setup script creates these worktrees if they do not already exist:

```text
FLOWMEMORY_WORKTREE_ROOT\flowmemory-contracts   agent/contracts
FLOWMEMORY_WORKTREE_ROOT\flowmemory-indexer     agent/indexer
FLOWMEMORY_WORKTREE_ROOT\flowmemory-hardware    agent/hardware
FLOWMEMORY_WORKTREE_ROOT\flowmemory-dashboard   agent/dashboard
FLOWMEMORY_WORKTREE_ROOT\flowmemory-research    agent/research
FLOWMEMORY_WORKTREE_ROOT\flowmemory-crypto      agent/crypto
FLOWMEMORY_WORKTREE_ROOT\flowmemory-chain       agent/chain
FLOWMEMORY_WORKTREE_ROOT\flowmemory-review      agent/review
```

Run each Codex agent from its assigned worktree in a separate PowerShell window:

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-contracts
codex
```

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-indexer
codex
```

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-hardware
codex
```

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-dashboard
codex
```

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-research
codex
```

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-crypto
codex
```

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-chain
codex
```

```powershell
cd FLOWMEMORY_WORKTREE_ROOT\flowmemory-review
codex
```

## Multi-Agent Safety Rules

- Keep `FLOWMEMORY_WORKTREE_ROOT\flowmemory-main` as the main checkout and coordination point.
- Run each agent only inside its assigned worktree folder.
- Check `git status --short --branch` before starting and before handing off work.
- Avoid assigning two agents to edit the same files at the same time.
- Use `git worktree list` from `FLOWMEMORY_WORKTREE_ROOT\flowmemory-main` to inspect all local worktrees.
- Long-running bucket agents should post or record short handoffs that name touched files, checks run, unresolved risks, and the next smallest safe task.
- Review agents should avoid product implementation and should work in docs, templates, scripts, and issue/PR hygiene unless an issue explicitly assigns a narrower technical scope.

## During Work

- Keep changes small and reviewable.
- Do not edit unrelated files.
- Do not hardcode secrets.
- Add tests where practical.
- Document open questions instead of silently inventing protocol facts.
- Prefer explicit boundaries over vague claims.

## Before You Finish

Run the checks that exist for the area you touched. If no test suite exists yet, say that clearly.

End with a PR-ready summary:

- What changed
- Why it changed
- Tests or checks run
- Risks, assumptions, and follow-ups
