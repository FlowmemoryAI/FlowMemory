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
| Existing `npm run flowchain:product-e2e` remains passing, or failure is documented with owner and next action. | Ran twice. First failed due missing dependencies. After `npm ci`, `npm ci --prefix apps/dashboard`, and `npm ci --prefix crypto`, it failed in `contracts:hardening` because local Slither reported `BaseBridgeLockbox.releaseNative` findings. Owner and next action recorded in `CHECKLIST.md` and PR #132. | Failure documented; not passing locally. |
| Open a PR with exact commands run and current blockers. | Draft PR #132 opened: https://github.com/FlowmemoryAI/FlowMemory/pull/132. | Complete. |
| PR CI state. | `gh pr view 132` showed all CI checks successful and merge state `CLEAN` after push. | Complete for current PR. |
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

## Uncovered Or Incomplete Requirements

- The new gates are not on `main`; PR #132 is still draft and unmerged.
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
2. Have contracts/static-analysis owner resolve or explicitly accept the local
   Slither findings before relying on local `flowchain:l1-e2e` evidence.
3. Merge or rebase the richer ops `flowchain:l1-e2e` wrapper when ready.
4. Have each subsystem agent add its dedicated pilot proof command.
5. Rerun `npm run flowchain:real-value-pilot:e2e` without
   `-AllowIncomplete` only after all dedicated proof commands exist.
