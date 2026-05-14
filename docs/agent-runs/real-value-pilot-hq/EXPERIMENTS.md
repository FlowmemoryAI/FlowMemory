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
| `git show origin/main:package.json \| rg -n "flowchain:l1-e2e\|flowchain:real-value-pilot:e2e" -S` | No matches | Historical pre-merge check: the scripts were absent before PR #132. |
| `gh pr view 132 --repo FlowmemoryAI/FlowMemory --json ...` | Passed | PR #132 is open draft, merge state `CLEAN`, CI checks successful, not merged. |
| `npm run flowchain:real-value-pilot:e2e` | Failed as expected | Default gate failed clearly with six missing dedicated proof commands and wrote the report. |
| `npm run flowchain:l1-e2e` | Failed locally | Alias invoked full smoke and stopped in `contracts:hardening` because local Slither reported the same `BaseBridgeLockbox.releaseNative` findings. |
| Live pilot worktree inspection | Passed | Inspected `flowmemory-live-contracts`, `flowmemory-live-bridge`, `flowmemory-live-chain`, `flowmemory-live-wallet`, `flowmemory-live-control-dashboard`, and `flowmemory-live-ops` statuses, package scripts, and run notes. |
| Requested original worktree inspection refresh | Passed | Rechecked `flowmemory-chain`, `flowmemory-bridge-full`, `flowmemory-contracts`, `flowmemory-crypto`, `flowmemory-indexer`, `flowmemory-dashboard`, `flowmemory-review`, and `flowmemory-hq-review-loop` statuses and relevant package scripts. |
| `gh issue view 130 --repo FlowmemoryAI/FlowMemory --json ...` | Passed | Historical pre-merge check: release-gate issue #130 was still the accepted-boundary blocker. |
| `gh issue view 131 --repo FlowmemoryAI/FlowMemory --json ...` | Passed | Historical pre-merge check: Slither/static-analysis issue #131 still blocked coherent local product/L1 E2E evidence. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/status-report.ps1` | Passed | Historical pre-merge check: PR #132 was the only real-value pilot implementation PR, many sibling worktrees were dirty, and #130/#131 were still open. |
| Post blocker-link docs checks | Passed | `node infra/scripts/check-unsafe-claims.mjs`, `git diff --check`, and `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` passed after linking issues #130/#131. |
| PowerShell parser for `infra/scripts/contracts-static-analysis.ps1` | Passed | Parser accepted the updated opt-in Slither policy. |
| `bash -n infra/scripts/contracts-static-analysis.sh` | Passed | Passed after normalizing the script line endings and applying the same opt-in Slither policy. |
| `npm run contracts:hardening` | Passed | 84 Foundry tests passed; default gate printed the optional-Slither warning and did not run Slither findings as a default failure. |
| `npm run contracts:hardening:slither` | Failed as expected | 84 Foundry tests passed, then explicit Slither audit gate reported the known `BaseBridgeLockbox.releaseNative` `missing-zero-check` and `low-level-calls` findings. |
| `npm run flowchain:product-e2e` | Passed | Product Testnet V1 E2E passed and wrote `devnet/local/product-e2e/flowchain-product-e2e-report.json`. |
| `npm run flowchain:l1-e2e` | Passed | Current alias to `flowchain-full-smoke.ps1` passed and wrote `devnet/local/full-smoke/flowchain-full-smoke-report.json`. |
| Post static-analysis docs checks | Passed | `node infra/scripts/check-unsafe-claims.mjs`, `git diff --check`, and `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` passed after recording the static-analysis policy evidence. |
| Post release-boundary docs checks | Passed | `node infra/scripts/check-unsafe-claims.mjs`, `git diff --check`, and `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` passed after adding the issue #130 release-gate boundary. |
| `gh issue create ...` for subsystem proof commands | Passed | Created contracts #133, runtime #134, ops #135, wallet #136, control-dashboard #137, and bridge #138. |
| Post subsystem-issue mapping checks | Passed | `node infra/scripts/check-unsafe-claims.mjs`, `git diff --check`, and `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` passed after mapping #133 through #138 into HQ docs. |
| PR #132 merge verification | Passed | `gh pr view 132` reported state `MERGED`, merge commit `14f378b7f2dee9bfd29aec691ebda41e2b6fa101`, merged at `2026-05-14T02:19:55Z`. |
| Issue #130/#131 closure verification | Passed | `gh issue view 130` and `gh issue view 131` reported `CLOSED`; #130 closed at `2026-05-14T02:22:17Z`, #131 closed at `2026-05-14T02:22:35Z`. |
| Post-merge `npm run flowchain:l1-e2e` | Passed | Main-equivalent tree passed and wrote `devnet/local/full-smoke/flowchain-full-smoke-report.json`. |
| Post-merge strict `npm run flowchain:real-value-pilot:e2e` | Failed as intended | Gate exists on `main` and failed clearly with the six missing dedicated subsystem proof commands. |
| Post-merge `npm run flowchain:product-e2e` | Passed | Product Testnet V1 E2E passed and wrote `devnet/local/product-e2e/flowchain-product-e2e-report.json`. |
| Post-merge policy checks | Passed | `git diff --check` and `node infra/scripts/check-unsafe-claims.mjs` passed after the product E2E run. |
| GitHub issue comments for #133 through #138 | Passed | Posted HQ refresh comments with local worktree evidence, missing root proof command state, and next integration action on each subsystem proof issue. |
| Post-merge docs refresh checks | Passed | After updating HQ docs for PR #132 merge, #130/#131 closure, and issue comments, `git diff --check`, `node infra/scripts/check-unsafe-claims.mjs`, and `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` passed. |

## Static Analysis Policy Update

Owner: contracts / static-analysis policy.

This branch updates `infra/scripts/contracts-static-analysis.ps1` and
`infra/scripts/contracts-static-analysis.sh` so default `contracts:hardening`
matches the repo-level policy in `docs/CURRENT_STATE.md`: Slither remains an
explicit audit gate, not an environment-dependent default gate.

Closed GitHub issue: https://github.com/FlowmemoryAI/FlowMemory/issues/131

The explicit audit gate still owns the observed Slither findings:

- `missing-zero-check` for `BaseBridgeLockbox.releaseNative(...).recipient`.
- `low-level-calls` for the same native release call.
