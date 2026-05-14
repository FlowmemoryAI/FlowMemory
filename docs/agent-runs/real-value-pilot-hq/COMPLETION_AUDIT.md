# Real-Value Pilot HQ Completion Audit

Status: not complete.

Last updated: 2026-05-14.

## Objective Restated

Coordinate the capped FlowChain real-value pilot until these success criteria
are true on `main`:

1. `npm run flowchain:real-value-pilot:e2e` exists.
2. `npm run flowchain:real-value-pilot:e2e` passes without
   `-AllowIncomplete`.
3. `npm run flowchain:l1-e2e` exists.
4. `npm run flowchain:l1-e2e` passes.
5. The pilot remains capped owner validation only, with no public-readiness
   claim.
6. The HQ documentation, matrix, go/no-go checklist, run notes, and PR evidence
   exist in the allowed folders.

## Prompt-To-Artifact Checklist

| Requirement | Evidence inspected | Current result |
| --- | --- | --- |
| Worktree `E:\FlowMemory\flowmemory-live-hq` and branch `agent/real-value-pilot-hq`. | `git status --branch --short` showed `agent/real-value-pilot-hq...origin/agent/real-value-pilot-hq`. | Complete. |
| Read current main before editing. | Initial `git fetch origin main --prune`; later refresh showed `origin/main` at `14f378b Add real-value pilot HQ gate`. | Complete for HQ passes. |
| Inspect requested active worktrees. | Original worktrees and live pilot worktrees are recorded in `PLAN.md`; latest refresh inspected branches, heads, dirty counts, package scripts, and checklists. | Complete. |
| Stay inside allowed folders. | PR #132 changed only `docs/`, `infra/scripts/`, and `package.json`; this refresh changes only `docs/`. | Complete. |
| Create `docs/agent-runs/real-value-pilot-hq/PLAN.md`. | File exists and records scope, source docs, worktree inspection, and blockers. | Complete. |
| Create `docs/agent-runs/real-value-pilot-hq/CHECKLIST.md`. | File exists and records acceptance state plus blocker rows. | Complete. |
| Create `docs/agent-runs/real-value-pilot-hq/EXPERIMENTS.md`. | File exists and records command outcomes. | Complete. |
| Create `docs/agent-runs/real-value-pilot-hq/NOTES.md`. | File exists and records source-of-truth notes and boundaries. | Complete. |
| Create `docs/FLOWCHAIN_REAL_VALUE_PILOT.md`. | File exists on `main` after PR #132 and includes purpose, final gate, release boundary, integration matrix, go/no-go checklist, blockers, tracking issues, and PR evidence rules. | Complete. |
| Add or update `npm run flowchain:real-value-pilot:e2e`. | `git show origin/main:package.json` contains `flowchain:real-value-pilot:e2e`; strict command runs and fails on missing proof commands. | Complete. |
| Add or maintain `npm run flowchain:l1-e2e`. | `git show origin/main:package.json` contains `flowchain:l1-e2e`; post-merge local main-equivalent run passed. | Complete. |
| Pilot gate must fail clearly until subsystem pieces exist. | Strict `npm run flowchain:real-value-pilot:e2e` exited nonzero and listed contracts, bridge, runtime, wallet, control-dashboard, and ops proof gaps. | Complete. |
| Integration matrix maps every required proof to owning agent and command. | `docs/FLOWCHAIN_REAL_VALUE_PILOT.md#integration-matrix` maps baseline, contracts, bridge, runtime, wallet, control-dashboard, ops, and final gate proofs. | Complete. |
| Pilot go/no-go checklist for project owner. | `docs/FLOWCHAIN_REAL_VALUE_PILOT.md#owner-gonogo-checklist`. | Complete. |
| Keep public-readiness claims out of docs. | `node infra/scripts/check-unsafe-claims.mjs` passed after PR #132 and again after post-merge product E2E. | Complete for inspected docs. |
| `git diff --check` passes. | Passed after PR #132 and again after post-merge product E2E. | Complete. |
| New pilot gate in incomplete mode. | `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` passed and wrote `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`. | Complete. |
| Existing `npm run flowchain:product-e2e` remains passing, or failure is documented. | Post-merge local main-equivalent run passed and wrote `devnet/local/product-e2e/flowchain-product-e2e-report.json`. | Complete. |
| Open a PR with exact commands run and current blockers. | PR #132 opened, was marked ready, and merged: https://github.com/FlowmemoryAI/FlowMemory/pull/132. | Complete. |
| Resolve release-boundary blocker. | Issue #130 is closed; PR #132 merged the capped owner-pilot boundary. | Complete. |
| Resolve default static-analysis blocker. | Issue #131 is closed; PR #132 merged optional-Slither default hardening while keeping `contracts:hardening:slither` explicit. | Complete. |
| Post subsystem blocker coordination. | HQ refresh comments posted on issues #133 through #138 with current branch-local evidence and next integration action. | Complete for current coordination pass. |
| Final success: `flowchain:l1-e2e` passes on `main`. | `npm run flowchain:l1-e2e` passed on the post-merge main-equivalent tree. | Complete locally; should be rerun from clean `main` before owner go. |
| Final success: `flowchain:real-value-pilot:e2e` passes on `main`. | Strict gate exists on `origin/main` but fails because six dedicated proof commands are missing. | Not complete. |

## Latest Command Evidence

```powershell
gh pr view 132 --repo FlowmemoryAI/FlowMemory --json state,mergedAt,mergeCommit,url
```

Result: PR #132 is `MERGED`; merge commit
`14f378b7f2dee9bfd29aec691ebda41e2b6fa101`.

```powershell
gh issue view 130 --repo FlowmemoryAI/FlowMemory --json state,closedAt,url
gh issue view 131 --repo FlowmemoryAI/FlowMemory --json state,closedAt,url
```

Result: both issues are `CLOSED`.

```powershell
npm run flowchain:l1-e2e
```

Result: passed. Report path:
`devnet/local/full-smoke/flowchain-full-smoke-report.json`.

```powershell
npm run flowchain:real-value-pilot:e2e
```

Result: failed clearly with missing dedicated proof commands for:

- contracts;
- bridge relayer;
- chain runtime;
- wallet/operator;
- control-plane/dashboard;
- ops/installer.

```powershell
npm run flowchain:product-e2e
```

Result: passed. Report path:
`devnet/local/product-e2e/flowchain-product-e2e-report.json`.

```powershell
git diff --check
node infra/scripts/check-unsafe-claims.mjs
```

Result: both passed after the post-merge product E2E run.

## In-Flight Worktree Evidence

The following evidence is not source of truth until each branch is reviewed,
merged to `main`, and the strict HQ gate passes from `main`.

| Area | Latest branch-local evidence | Completion impact |
| --- | --- | --- |
| Contracts | `agent/real-value-pilot-contracts` checklist reports `forge test`, `npm run contracts:hardening`, deploy dry-run, product E2E, caps, allowlist, pause, release/recovery, replay, events, and docs complete. | Candidate proof exists branch-locally; root `flowchain:real-value-pilot:contracts` is still missing on `main`. |
| Bridge relayer | `agent/real-value-pilot-bridge` checklist reports Base `8453` observer, wrong-chain rejection, approved lockbox guard, confirmation depth, deterministic evidence, duplicate replay handling, local credit once, withdrawal/release evidence, tests, mock pilot E2E, wrong-chain negatives, local-credit smoke, and product E2E complete. | Candidate proof exists branch-locally; root `flowchain:real-value-pilot:bridge` is still missing on `main`. |
| Chain runtime | `agent/real-value-pilot-chain` checklist reports bridge credit mapping, include-once behavior, replay evidence, receipt lookup, handoff export, restart preservation, export/import roots, multi-node smoke, and direct wrapper proof complete. It records missing dependency and root package-script blockers. | Runtime proof needs a rebased PR adding `flowchain:real-value-pilot:runtime` and rerunning product/HQ gates. |
| Wallet/operator | `agent/real-value-pilot-wallet` checklist reports schemas, metadata boundary, config validation, cap guardrails, signing/validation CLI, pilot E2E, negative cases, next-command CLI, scans, product evidence, and issue #131 handoff complete. | Candidate proof exists branch-locally; root `flowchain:real-value-pilot:wallet` is still missing on `main`. |
| Control plane/dashboard | `agent/real-value-pilot-control-dashboard` checklist reports API, dashboard, schemas, docs, tests, smoke, build, branch-local `flowchain:real-value-pilot:control-dashboard`, and branch-local pilot E2E complete. | Candidate proof exists branch-locally; no PR currently exists. |
| Ops/installer | `agent/real-value-pilot-ops` checklist reports dry run, live-mode env refusal, owner ack refusal, Base guard, tiny cap checks, next commands, emergency stop, sanitized export, docs, troubleshooting, unsafe-claims, diff check, and product E2E complete. | Candidate proof exists branch-locally; root `flowchain:real-value-pilot:ops` is still missing on `main`. |

## Uncovered Or Incomplete Requirements

- `flowchain:real-value-pilot:e2e` does not pass without
  `-AllowIncomplete`.
- Dedicated subsystem proof commands do not exist on `main`:
  `flowchain:real-value-pilot:contracts`,
  `flowchain:real-value-pilot:bridge`,
  `flowchain:real-value-pilot:runtime`,
  `flowchain:real-value-pilot:wallet`,
  `flowchain:real-value-pilot:control-dashboard`, and
  `flowchain:real-value-pilot:ops`.
- No PR currently exists for the six live `agent/real-value-pilot-*`
  subsystem branches.
- The owner go/no-go checklist remains no-go.

## Next Concrete Actions

1. Rebase or refresh each subsystem branch onto main commit `14f378b`.
2. Add the dedicated root proof command required by its issue.
3. Rerun the issue-specific proof commands plus `git diff --check`,
   `node infra/scripts/check-unsafe-claims.mjs`, and
   `npm run flowchain:product-e2e` where practical.
4. Open PRs for issues #133, #138, #134, #136, #137, and #135.
5. Rerun `npm run flowchain:real-value-pilot:e2e` without
   `-AllowIncomplete` after all dedicated proof commands are merged.
