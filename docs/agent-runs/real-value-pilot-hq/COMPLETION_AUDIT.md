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
| Existing `npm run flowchain:product-e2e` remains passing, or failure is documented with owner and next action. | Ran twice. First failed due missing dependencies. After `npm ci`, `npm ci --prefix apps/dashboard`, and `npm ci --prefix crypto`, it failed in `contracts:hardening` because local Slither reported `BaseBridgeLockbox.releaseNative` findings. Owner and next action recorded in `CHECKLIST.md`, PR #132, and issue #131. | Failure documented; not passing locally. |
| Open a PR with exact commands run and current blockers. | Draft PR #132 opened: https://github.com/FlowmemoryAI/FlowMemory/pull/132. | Complete. |
| PR CI state. | `gh pr view 132` showed all CI checks successful and merge state `CLEAN` after push. | Complete for current PR. |
| GitHub blocker state. | `gh issue view 130`, `gh issue view 131`, and `infra/scripts/status-report.ps1` show issues #130 and #131 open. | Not complete; blockers remain open. |
| Final success: `flowchain:real-value-pilot:e2e` passes on `main`. | `origin/main` lacks the script; branch gate fails by design because dedicated subsystem proof commands are missing. | Not complete. |
| Final success: `flowchain:l1-e2e` passes on `main`. | `origin/main` lacks the script; branch alias currently fails locally through `flowchain-full-smoke` because `contracts:hardening` fails under local Slither. | Not complete. |

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

Result: failed locally inside `npm run contracts:hardening`; Slither reported
`missing-zero-check` and `low-level-calls` findings for
`contracts/bridge/BaseBridgeLockbox.sol`.

```powershell
gh issue view 131 --repo FlowmemoryAI/FlowMemory --json number,title,state,url
```

Result: issue #131 is open and tracks the required contracts/static-analysis
decision before local product/L1 E2E evidence is treated as coherent in this
Slither-equipped environment.

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
- GitHub issue #131 is still open, so local product/L1 E2E evidence remains
  blocked in Slither-equipped environments.
- `flowchain:real-value-pilot:e2e` does not pass without `-AllowIncomplete`.
- Dedicated subsystem proof commands do not exist yet:
  `flowchain:real-value-pilot:contracts`,
  `flowchain:real-value-pilot:bridge`,
  `flowchain:real-value-pilot:runtime`,
  `flowchain:real-value-pilot:wallet`,
  `flowchain:real-value-pilot:control-dashboard`, and
  `flowchain:real-value-pilot:ops`.
- `flowchain:l1-e2e` is only a branch alias to `flowchain:full-smoke` in this
  HQ PR; it is not on `main` and did not pass locally with Slither installed.
- The owner go/no-go checklist remains no-go.

## Next Concrete Actions

1. Keep PR #132 open as the HQ gate/documentation branch until reviewed.
2. Close issue #130 by accepting the capped owner-pilot release boundary.
3. Close issue #131 by having the contracts/static-analysis owner resolve or
   explicitly accept the local Slither findings before relying on local
   `flowchain:l1-e2e` evidence.
4. Merge or rebase the richer ops `flowchain:l1-e2e` wrapper when ready.
5. Have each subsystem agent add its dedicated pilot proof command.
6. Rerun `npm run flowchain:real-value-pilot:e2e` without
   `-AllowIncomplete` only after all dedicated proof commands exist.
