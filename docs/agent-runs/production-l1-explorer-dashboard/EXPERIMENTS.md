# FlowChain L1 Pilot Explorer Dashboard Experiments

This file records commands, verification attempts, and outcomes for the run.

## Commands

| Command | Status | Notes |
| --- | --- | --- |
| `npm test --prefix services/indexer` | pass | 19 tests passed, including deterministic token/DEX/bridge fallback indexing. |
| `npm run index:fixtures --prefix services/indexer` | pass | Regenerated explorer projection with 1 token, 2 pools, and 2 bridge events. |
| `npm test --prefix services/control-plane` | pass | 21 tests passed. |
| `npm test --prefix apps/dashboard` | pass | 10 tests passed. |
| `npm run build --prefix apps/dashboard` | pass | Vite build passed and copied explorer fallback. |
| `npm run control-plane:smoke` | pass | `ok: true`, 79 methods. |
| Browser verification at `http://127.0.0.1:5173` | pass | Playwright evidence saved in this directory. |
| `npm run flowchain:l1-e2e` | pass | Full private/local smoke passed. |
| `npm run flowchain:real-value-pilot:control-dashboard` | pass | Control-plane/dashboard scoped pilot proof passed. |
| `npm run flowchain:real-value-pilot:e2e` | pass | Passed after reconciling this branch with `origin/main` proof-gate commits; report `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`. |
| `git diff --check` | pass | Exit 0; line-ending warnings only. |

## Evidence Paths

- Desktop/mobile visual evidence: `dashboard-desktop-playwright.png`, `dashboard-mobile-playwright.png`.
- DOM evidence: `browser-dom-evidence.json`.
- No-secret scan summary: `NO_SECRET_BROWSER_PROOF.md`.

## Upstream Reconciliation

- GitHub issues #133, #138, and #134 are closed.
- `origin/main` contains the missing proof commands in commits `91b4d5d`, `3bece1e`, and `ef3ae59`.
- Merged `origin/main` into the worktree with `git merge --no-commit --no-ff origin/main` so the final root pilot gate could run against the actual current source-of-truth proof commands.
