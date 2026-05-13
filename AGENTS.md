# FlowMemory Agent Instructions

These instructions apply to every agent, assistant, script, and human operating in this repository.

## Source Of Truth

- Treat GitHub as the source of truth for project state, issues, pull requests, reviews, and final history.
- Read `docs/START_HERE.md` before starting any task.
- Read `docs/FLOWMEMORY_HQ_CONTEXT.md` before making design or implementation choices.
- Read `docs/CURRENT_STATE.md` immediately before working so you understand what exists and what does not.
- Read `docs/ROOTFLOW_V0.md`, `docs/FLOW_MEMORY_V0.md`, and `docs/V0_LAUNCH_ACCEPTANCE.md` before working on launch-core Rootflow, Flow Memory, verifier, receipt, dashboard, or memory-signal tasks.
- If local context conflicts with GitHub, stop and reconcile the difference before editing.

## Scope Discipline

- Work only on the assigned scope.
- Do not edit unrelated files.
- Do not rename, move, or delete files outside the task unless the task explicitly asks for it.
- Do not build product features during bootstrap, planning, or research tasks.
- When blocked, document the blocker and the smallest useful next step.

## HQ Program Management

- Use `docs/ISSUE_BACKLOG.md` to understand issue dependencies and milestone placement.
- Use `docs/AGENT_PROMPTS.md` when launching or briefing a worktree agent.
- Use `docs/PR_PROCESS.md` for branch naming, draft PRs, merge order, dirty worktrees, and issue closing.
- Use `docs/DAILY_HQ_RUNBOOK.md` for morning review, triage, monitoring, and handoff.
- Use `infra/scripts/status-report.ps1` for read-only local worktree, PR, and issue status.
- The immediate major milestone is the Rootflow V0 and Flow Memory V0 launch core. Do not reinterpret that as approval for production deployment.

## Engineering Rules

- Do not hardcode secrets, tokens, private keys, seed phrases, RPC credentials, API keys, or webhook URLs.
- Keep heavy AI, model, memory, artifact, and media data off-chain.
- Remember that storage is not free and transaction hashes do not store arbitrary data.
- Remember that Uniswap v4 hooks cannot know `txHash` or `logIndex` at execution time.
- Let indexers and verifiers derive `txHash` and `logIndex` after reading receipts and logs.
- Store roots, receipts, commitments, attestations, proofs, and work state on-chain only when they are intentionally part of the protocol.
- Treat Meshtastic and LoRa as low-bandwidth control signaling, not normal internet bandwidth.
- Add tests where practical, especially for protocol logic, parsers, cryptography, indexers, verifiers, and hardware control paths.

## Collaboration

- Prefer small, reviewable pull requests.
- Keep documentation updated when changing architecture, security assumptions, public contracts, or agent workflows.
- Record durable architectural decisions in `docs/DECISIONS/`.
- Use issues for unknowns, research tasks, hardware tasks, security tasks, bugs, and feature proposals.
- End every task with a PR-ready summary that includes:
  - What changed
  - Why it changed
  - Tests or checks run
  - Risks, assumptions, and follow-ups
