# Real-Value Pilot HQ Experiments

Status: command log.

Last updated: 2026-05-14.

## Commands Run So Far

| Command | Result | Notes |
| --- | --- | --- |
| `git fetch origin main --prune` | Passed | Confirmed `HEAD` and `origin/main` were both `9b025c5` before edits. |
| `gh pr list --repo FlowmemoryAI/FlowMemory --state open --limit 30 --json ...` | Passed | Confirmed PR #129 exists for the real-value pilot goal pack and active draft PR state. |
| `gh issue list --repo FlowmemoryAI/FlowMemory --state open --limit 80 --json ...` | Passed | Confirmed issue #130 exists for release gates before public-network pilot work. |
| `gh issue list --repo FlowmemoryAI/FlowMemory --state closed --limit 40 --json ...` | Passed | Confirmed #99, #100, #101, #102, #108, and #78 are closed on GitHub. |
| `git worktree list` | Passed | Identified live, L1 loop, and release worktrees. |
| Requested sibling worktree status/diff inspections | Passed | Found reusable unmerged work; no sibling worktree was edited. |
| `node -e "JSON.parse(...package.json...)"` | Passed | Confirmed package JSON syntax after adding scripts. |
| PowerShell scriptblock parse for `infra/scripts/flowchain-real-value-pilot-e2e.ps1` | Passed | Parser accepted the new pilot gate script. |
| `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` | Passed as incomplete report | Report written to `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`; six dedicated subsystem proof commands are missing. |
| `node infra/scripts/check-unsafe-claims.mjs` | Passed | Output: `Checked launch claims in README.md, docs, contracts.` |
| `git diff --check` | Passed | Git emitted only the Windows line-ending warning for `package.json`; no whitespace errors. |
| `npm run flowchain:product-e2e` | Failed before checks | First run failed because `node_modules`, `apps/dashboard/node_modules`, and `crypto/node_modules` were missing. |
| `npm ci` | Passed | Installed root workspace dependencies from lockfile. |
| `npm ci --prefix apps/dashboard` | Passed | Installed dashboard dependencies from lockfile. |
| `npm ci --prefix crypto` | Passed | Installed crypto dependencies from lockfile. |
| `npm run flowchain:product-e2e` | Failed after dependency install | Reached `npm run contracts:hardening`; local Slither reported existing `BaseBridgeLockbox.releaseNative` findings in `contracts/bridge/BaseBridgeLockbox.sol`, so product E2E stopped. |
| Draft PR creation through GitHub connector | Passed | Opened https://github.com/FlowmemoryAI/FlowMemory/pull/132. |
| `git show origin/main:package.json \| rg -n "flowchain:l1-e2e\|flowchain:real-value-pilot:e2e" -S` | No matches | Confirmed `origin/main` lacks both new scripts. |
| `gh pr view 132 --repo FlowmemoryAI/FlowMemory --json ...` | Passed | PR #132 is open draft, merge state `CLEAN`, CI checks successful, not merged. |
| `npm run flowchain:real-value-pilot:e2e` | Failed as expected | Default gate failed clearly with six missing dedicated proof commands and wrote the report. |
| `npm run flowchain:l1-e2e` | Failed locally | Alias invoked full smoke and stopped in `contracts:hardening` because local Slither reported the same `BaseBridgeLockbox.releaseNative` findings. |
| Live pilot worktree inspection | Passed | Inspected `flowmemory-live-contracts`, `flowmemory-live-bridge`, `flowmemory-live-chain`, `flowmemory-live-wallet`, `flowmemory-live-control-dashboard`, and `flowmemory-live-ops` statuses, package scripts, and run notes. |
| Requested original worktree inspection refresh | Passed | Rechecked `flowmemory-chain`, `flowmemory-bridge-full`, `flowmemory-contracts`, `flowmemory-crypto`, `flowmemory-indexer`, `flowmemory-dashboard`, `flowmemory-review`, and `flowmemory-hq-review-loop` statuses and relevant package scripts. |
| `gh issue view 130 --repo FlowmemoryAI/FlowMemory --json ...` | Passed | Confirmed release-gate issue #130 remains open and is the accepted-boundary blocker. |
| `gh issue view 131 --repo FlowmemoryAI/FlowMemory --json ...` | Passed | Confirmed Slither/static-analysis issue #131 remains open and blocks coherent local product/L1 E2E evidence. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/status-report.ps1` | Passed | Confirmed PR #132 is the only open real-value pilot implementation PR, many sibling worktrees are dirty, and issues #130/#131 are open. |
| Post blocker-link docs checks | Passed | `node infra/scripts/check-unsafe-claims.mjs`, `git diff --check`, and `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` passed after linking issues #130/#131. |

## Product E2E Failure Assignment

Owner: contracts / static-analysis policy.

Next action: contracts owner should address the Slither findings or update the
accepted static-analysis policy in a contracts-scoped PR. This HQ branch is not
allowed to edit `contracts/`.

GitHub blocker: https://github.com/FlowmemoryAI/FlowMemory/issues/131

Observed Slither findings:

- `missing-zero-check` for `BaseBridgeLockbox.releaseNative(...).recipient`.
- `low-level-calls` for the same native release call.
