# Real-Value Pilot Control-Plane/Dashboard Experiments

This file records commands and outcomes for the feedback loop.

## Baseline

- `git status --short --branch` confirmed branch `agent/real-value-pilot-control-dashboard`.
- `infra/scripts/status-report.ps1` was used for read-only worktree, PR, and issue context.

## Implementation Checks

- `npm test --prefix services/control-plane` failed before snapshot/method-count updates, then passed with 21 tests.
- `npm run control-plane:smoke` passed with 66 methods and pilot schemas included.
- After hardening pilot HTTP route query handling, `npm test --prefix services/control-plane` passed again with 21 tests and `/pilot/deposits?limit=1` plus invalid `limit=0` coverage.
- After hardening pilot HTTP route query handling, `npm run control-plane:smoke` passed again with 66 methods.
- `npm install --prefix apps/dashboard` installed missing dashboard test dependencies.
- `npm test --prefix apps/dashboard` passed with 10 tests.
- `npm run build --prefix apps/dashboard` passed.
- Scope audit passed: all changed/untracked paths are inside the allowed control-plane/dashboard/schema/docs surfaces, except the documented root `package.json` proof-command shim for `flowchain:real-value-pilot:control-dashboard`.
- `git diff --check` passed; Git reported only CRLF normalization warnings for touched text files.
- After rebasing onto `origin/main`, `npm test --prefix services/control-plane` passed again with 21 tests.
- After rebasing onto `origin/main`, `npm run control-plane:smoke` passed again with 66 methods and pilot schemas included.
- After rebasing onto `origin/main`, `npm test --prefix apps/dashboard` passed again with 10 tests.
- After rebasing onto `origin/main`, `npm run build --prefix apps/dashboard` passed again.

## Browser Verification

- In-app browser verification was attempted after reading the Browser skill, but the Node REPL `js` tool was not exposed by tool discovery.
- Fallback local server verification passed:
  - started `npm run serve --prefix services/control-plane`
  - started `npm run dev --prefix apps/dashboard -- --port 5174 --strictPort`
  - `GET http://127.0.0.1:8787/health` returned service `flowmemory-control-plane-v0`
  - `GET http://127.0.0.1:8787/pilot/status` returned schema `flowmemory.control_plane.real_value_pilot_status.v0`, state `degraded`, and the Base canary observe command
  - `GET http://127.0.0.1:5174/` returned HTTP 200 and the Vite root element
- Source scan for `localStorage`, `sessionStorage`, `setItem`, private-key, seed-phrase, mnemonic, RPC credential, API key, and webhook terms in `apps/dashboard/src` and `apps/dashboard/public` found only explanatory/test text and no browser storage write API usage.

## E2E

- Before the upstream HQ gate landed, `npm run flowchain:real-value-pilot:e2e` passed as the control-dashboard service-local proof. Result schema: `flowmemory.control_plane.real_value_pilot_e2e.v0`; pilot state: `degraded`; next command: `npm run bridge:observe -- --mode base-mainnet-canary --rpc-url <FLOWCHAIN_BASE8453_RPC_URL> --lockbox-address <FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS> --from-block <n> --to-block <n> --acknowledge-real-funds --max-usd 25`.
- Before the upstream HQ gate landed, after hardening pilot HTTP route query handling, `npm run flowchain:real-value-pilot:e2e` passed again with the same schema and degraded fixture-backed state.
- `npm run flowchain:real-value-pilot:control-dashboard` passed. It delegates to the same service-local E2E and satisfies the upstream HQ pilot proof-row command for the control-plane/dashboard owner.
- Before rebasing onto the upstream HQ gate, after adding the proof-row shim, `npm run flowchain:real-value-pilot:e2e` passed again with schema `flowmemory.control_plane.real_value_pilot_e2e.v0`, state `degraded`, all nine pilot API methods, and dashboard evidence entries.
- `npm run flowchain:product-e2e` initially failed before product flow because root and crypto `node_modules` were missing.
- `npm ci` and `npm ci --prefix crypto` installed locked local dependencies.
- `npm run flowchain:product-e2e` then failed in optional Slither static analysis on existing `contracts/bridge/BaseBridgeLockbox.sol` findings outside this task scope. The latest exact rerun failed for the same reason after service/dashboard tests had passed inside the product gate. GitHub issue #131 tracks this exact blocker.
- Fresh rerun after adding `flowchain:real-value-pilot:control-dashboard`: `npm run flowchain:product-e2e` again passed service tests, control-plane tests, bridge-relayer tests, crypto tests, crypto vector validation, local-alpha validation, and forge tests, then failed in Slither with `missing-zero-check` and `low-level-calls` on `contracts/bridge/BaseBridgeLockbox.sol#195-207`.
- `$slitherDir = Split-Path -Parent (Get-Command slither).Source; $env:PATH = (($env:PATH -split ';') | Where-Object { $_ -and (([System.IO.Path]::GetFullPath($_.TrimEnd('\\'))) -ne ([System.IO.Path]::GetFullPath($slitherDir.TrimEnd('\\')))) }) -join ';'; npm run flowchain:product-e2e` passed, matching the documented default path where Slither is optional unless explicitly required. Latest rerun passed.
- After rebasing onto `origin/main` commit `14f378b`, bare `npm run flowchain:product-e2e` passed without environment changes.
- After rebasing onto `origin/main`, `npm run flowchain:real-value-pilot:control-dashboard` passed again with schema `flowmemory.control_plane.real_value_pilot_e2e.v0`, state `degraded`, all nine pilot API methods, and dashboard evidence entries.
- After rebasing onto `origin/main`, bare `npm run flowchain:real-value-pilot:e2e` invoked the upstream final HQ gate and failed incomplete because the contracts, bridge, runtime, wallet, and ops proof commands are missing outside this branch's scope.
- `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` completed and wrote `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json` with `status: incomplete`, `ownerGoNoGo.go: false`, `control-dashboard:api-and-owner-views.passed: true`, and missing proofs only for contracts, bridge, runtime, wallet, and ops.
- After rebasing onto `origin/main` commit `f384236`, `npm run flowchain:real-value-pilot:control-dashboard` passed again.
- After rebasing onto `origin/main` commit `f384236`, `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` completed again with only non-control-dashboard proof rows missing.
- After rebasing onto `origin/main` commit `f384236`, bare `npm run flowchain:product-e2e` passed again without extra tracked fixture churn.
- `npm run flowchain:l1-e2e` passed on the current rebased tree and left no extra tracked fixture churn beyond the intended branch diff.
- `node infra/scripts/check-unsafe-claims.mjs` passed, reporting that launch claims in README, docs, and contracts were checked.
- After updating `docs/FLOWCHAIN_REAL_VALUE_PILOT.md` for the control-dashboard branch row, `node infra/scripts/check-unsafe-claims.mjs` passed again.

## Upstream Reconciliation

- Rebased this branch onto `origin/main` commit `14f378b` (`Add real-value pilot HQ gate`) after the initial implementation, then rebased again onto `f384236` (`Refresh real-value pilot HQ status`).
- Those upstream commits add and refresh `docs/FLOWCHAIN_REAL_VALUE_PILOT.md`, an HQ `flowchain:real-value-pilot:e2e` wrapper, `flowchain:l1-e2e`, and an infra-level optional Slither policy change.
- The upstream HQ spec expects the control-plane/dashboard owner row to provide `npm run flowchain:real-value-pilot:control-dashboard`; this branch now exposes and verifies that command.
- The upstream infra-level optional Slither policy is now present via rebase; no local `infra/scripts/` edits are part of this branch diff.
