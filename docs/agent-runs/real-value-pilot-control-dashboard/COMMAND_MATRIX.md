# Real-Value Pilot Control-Dashboard Command Matrix

## Branch-owned commands

| Command | Status | Evidence |
| --- | --- | --- |
| `npm test --prefix services/control-plane` | Passed | 21 control-plane tests, including pilot lifecycle, secret rejection, and HTTP pilot route coverage. |
| `npm run control-plane:smoke` | Passed | 66 methods; includes all real-value pilot schemas. |
| `npm test --prefix apps/dashboard` | Passed | 10 dashboard tests, including pilot labels and workbench mapping. |
| `npm run build --prefix apps/dashboard` | Passed | Vite production build completed. |
| `npm run flowchain:real-value-pilot:control-dashboard` | Passed | Verifies all pilot API methods, dashboard evidence, capped-owner labels, no broad readiness, and no browser secret storage. |
| `node infra/scripts/check-unsafe-claims.mjs` | Passed | Checked launch claims in README, docs, and contracts. |

## Baseline command

| Command | Status | Evidence |
| --- | --- | --- |
| `npm run flowchain:product-e2e` | Passed | Product E2E passed after rebasing onto `origin/main` commit `f384236`; no extra tracked fixture churn remained. |
| `npm run flowchain:l1-e2e` | Passed | Alias to `flowchain:full-smoke`; passed on the current rebased tree with no extra tracked fixture churn. |

## Upstream multi-owner command

| Command | Status | Evidence |
| --- | --- | --- |
| `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` | Completed coordination report | Report `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json` marks `control-dashboard:api-and-owner-views.passed: true` and `ownerGoNoGo.go: false`. |
| `npm run flowchain:real-value-pilot:e2e` | Incomplete | Final HQ gate is waiting on non-control-dashboard proof commands: contracts #133, bridge #138, runtime #134, wallet #136, and ops #135. |

## Interpretation

The control-plane/dashboard owner row is complete and has a passing proof command. The final owner go/no-go gate remains intentionally incomplete until other owner branches land their proof commands.
