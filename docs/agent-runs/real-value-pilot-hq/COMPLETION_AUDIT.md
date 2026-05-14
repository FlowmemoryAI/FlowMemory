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
| Read current main before editing. | `git fetch origin main --prune`; `HEAD` before edits was `9b025c5`; `origin/main` was `9b025c5`. | Complete for this HQ pass. |
| Inspect active worktrees for reusable work. | Worktree status/diff inspections recorded in `PLAN.md` and `EXPERIMENTS.md`. | Complete for this HQ pass. |
| Stay inside allowed folders. | `git status --short --branch`; PR #132 changed only `docs/`, `infra/scripts/`, and `package.json`. | Complete. |
| Create `docs/agent-runs/real-value-pilot-hq/PLAN.md`. | File exists and records scope, source docs, worktree inspection, and blockers. | Complete. |
| Create `docs/agent-runs/real-value-pilot-hq/CHECKLIST.md`. | File exists and records acceptance state plus blocker rows. | Complete. |
| Create `docs/agent-runs/real-value-pilot-hq/EXPERIMENTS.md`. | File exists and records command outcomes. | Complete. |
| Create `docs/agent-runs/real-value-pilot-hq/NOTES.md`. | File exists and records source-of-truth notes and boundaries. | Complete. |
| Create `docs/FLOWCHAIN_REAL_VALUE_PILOT.md`. | File exists with purpose, final gate, integration matrix, go/no-go checklist, blockers, and PR evidence rules. | Complete on branch, not on `main`. |
| Add or update `npm run flowchain:real-value-pilot:e2e`. | `package.json` on branch contains the script. `git show origin/main:package.json` shows `origin/main` lacks it. | Complete on branch, missing on `main`. |
| Add or maintain `npm run flowchain:l1-e2e`. | `package.json` on branch contains the alias. `git show origin/main:package.json` shows `origin/main` lacks it. | Complete on branch, missing on `main`. |
| Pilot gate must fail clearly until subsystem pieces exist. | `npm run flowchain:real-value-pilot:e2e` exited nonzero and listed contracts, bridge, runtime, wallet, control-dashboard, and ops proof gaps. | Complete. |
| Integration matrix maps every required proof to owning agent and command. | `docs/FLOWCHAIN_REAL_VALUE_PILOT.md` matrix maps baseline, contracts, bridge, runtime, wallet, control-dashboard, ops, and final gate proofs. | Complete. |
| Pilot go/no-go checklist for project owner. | `docs/FLOWCHAIN_REAL_VALUE_PILOT.md#owner-gonogo-checklist`. | Complete. |
| Keep public-readiness claims out of docs. | `node infra/scripts/check-unsafe-claims.mjs` passed. | Complete for touched docs. |
| `git diff --check` passes. | Ran after edits and after follow-up updates; only Windows line-ending warnings appeared. | Complete. |
| New pilot gate in incomplete mode. | `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` passed and wrote `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`. | Complete. |
| Existing `npm run flowchain:product-e2e` remains passing, or failure is documented with owner and next action. | Initially failed under local Slither. After the allowed `infra/scripts/` static-analysis policy update, `npm run flowchain:product-e2e` passed and wrote `devnet/local/product-e2e/flowchain-product-e2e-report.json`. | Complete on branch; not yet on `main`. |
| Open a PR with exact commands run and current blockers. | Draft PR #132 opened: https://github.com/FlowmemoryAI/FlowMemory/pull/132. | Complete. |
| PR CI state. | `gh pr view 132` showed all CI checks successful and merge state `CLEAN` after push. | Complete for current PR. |
| GitHub blocker state. | `gh issue view 130`, `gh issue view 131`, and `infra/scripts/status-report.ps1` show issues #130 and #131 open. PR #132 now contains a branch-local #131 policy fix. | Not complete; blockers remain open until reviewed/merged. |
| Final success: `flowchain:real-value-pilot:e2e` passes on `main`. | `origin/main` lacks the script; branch gate fails by design because dedicated subsystem proof commands are missing. | Not complete. |
| Final success: `flowchain:l1-e2e` passes on `main`. | `origin/main` lacks the script. The branch alias now passes locally after the static-analysis policy update. | Complete on branch; missing on `main`. |

## Command Evidence

Latest command evidence:

```powershell
git show origin/main:package.json | rg -n "flowchain:l1-e2e|flowchain:real-value-pilot:e2e" -S
```

Result: no matches; `origin/main` lacks both scripts.

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
npm run flowchain:l1-e2e
```

Result after static-analysis policy update: passed. Report path:
`devnet/local/full-smoke/flowchain-full-smoke-report.json`.

```powershell
npm run flowchain:product-e2e
```

Result after static-analysis policy update: passed. Report path:
`devnet/local/product-e2e/flowchain-product-e2e-report.json`.

```powershell
gh issue view 131 --repo FlowmemoryAI/FlowMemory --json number,title,state,url
```

Result: issue #131 is open. PR #132 now contains the branch-local policy fix;
the issue remains incomplete until reviewed and merged.

## In-Flight Worktree Evidence

The following evidence was inspected after PR #132 opened. It is not source of
truth until the work lands in reviewed PRs and merges to `main`.

| Area | Live branch evidence | Completion impact |
| --- | --- | --- |
| Contracts | `agent/real-value-pilot-contracts` reports `forge test`, `npm run contracts:hardening`, deploy dry-run, and `npm run flowchain:product-e2e` passing after local dependency install. | Candidate proof exists branch-locally, but no dedicated root pilot proof command is merged. |
| Bridge relayer | `agent/real-value-pilot-bridge` has Base `8453` observer and mock pilot E2E files, but the checklist still records observer, replay, local-credit, and product E2E proof rows as pending. | Still incomplete. |
| Chain runtime | `agent/real-value-pilot-chain` has bridge-credit runtime changes in progress; baseline cargo test passed before edits and current experiments remain pending. | Still incomplete. |
| Wallet/operator | `agent/real-value-pilot-wallet` has pilot signing, schemas, and docs in progress; all verification commands are still pending in its checklist. | Still incomplete. |
| Control plane/dashboard | `agent/real-value-pilot-control-dashboard` has pilot API/dashboard files and a service-local E2E, but its checklist still marks implementation and test rows incomplete. | Still incomplete. |
| Ops/installer | `agent/real-value-pilot-ops` has root pilot wrappers, emergency stop, sanitized export, and a passing checklist, including product E2E after an ops-side static-analysis wrapper change. | Candidate proof exists branch-locally, but not merged; it must reconcile with contracts hardening policy. |

## Uncovered Or Incomplete Requirements

- The new gates are not on `main`; PR #132 is still draft and unmerged.
- GitHub issue #130 is still open, so the accepted release-gate boundary is not
  complete.
- GitHub issue #131 is still open. This branch contains a policy fix and local
  product/L1 E2E now passes, but `main` is unchanged until PR #132 merges.
- `flowchain:real-value-pilot:e2e` does not pass without `-AllowIncomplete`.
- Dedicated subsystem proof commands do not exist yet:
  `flowchain:real-value-pilot:contracts`,
  `flowchain:real-value-pilot:bridge`,
  `flowchain:real-value-pilot:runtime`,
  `flowchain:real-value-pilot:wallet`,
  `flowchain:real-value-pilot:control-dashboard`, and
  `flowchain:real-value-pilot:ops`.
- `flowchain:l1-e2e` is only a branch alias to `flowchain:full-smoke` in this
  HQ PR; it is not on `main`. It now passes locally after the branch static-
  analysis policy update.
- The owner go/no-go checklist remains no-go.

## Next Concrete Actions

1. Keep PR #132 open as the HQ gate/documentation branch until reviewed.
2. Close issue #130 by accepting the capped owner-pilot release boundary.
3. Review and merge the #131 static-analysis policy fix, or replace it with a
   contracts-owned fix if the owner chooses to require Slither findings in the
   default gate.
4. Merge or rebase the richer ops `flowchain:l1-e2e` wrapper when ready.
5. Have each subsystem agent add its dedicated pilot proof command.
6. Rerun `npm run flowchain:real-value-pilot:e2e` without
   `-AllowIncomplete` only after all dedicated proof commands exist.
