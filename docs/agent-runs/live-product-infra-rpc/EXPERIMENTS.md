# FlowChain Live Infra RPC Experiments

This file records commands run by this agent and the evidence paths they produce. Do not paste env values, endpoint URLs, private keys, seed phrases, API keys, webhooks, or vault ciphertext here.

| Time UTC | Command | Result | Evidence |
| --- | --- | --- | --- |
| 2026-05-15 | `git status --short --branch` | passed | branch reported as `agent/live-product-infra-rpc...origin/agent/production-l1-hq` |
| 2026-05-15 | `git fetch origin --prune` | passed | remote `agent/live-product-infra-rpc` was not present |
| 2026-05-15 | `npm run flowchain:init` | passed | initialized ignored local state at `devnet/local/state.json` |
| 2026-05-15 | `npm run flowchain:live-infra:check -- -AllowBlocked` | blocked as expected | `docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json` |
| 2026-05-15 | `npm run flowchain:doctor` | degraded, exit 0 | `devnet/local/doctor/flowchain-doctor-report.json`; degraded by live env blockers |
| 2026-05-15 | `npm run flowchain:node:status` | passed | printed local node state summary for `devnet/local/state.json` |
| 2026-05-15 | `npm run flowchain:rpc:e2e` | passed | `devnet/local/rpc-e2e/flowchain-rpc-e2e-report.json`; public readiness remained `BLOCKED` |
| 2026-05-15 | `npm run flowchain:bridge:live:check` | blocked, exit 1 | `devnet/local/bridge-live-readiness/bridge-live-readiness-report.json`; missing Base 8453 env names only |
| 2026-05-15 | `npm run flowchain:live-infra:check` | blocked, exit 1 | `docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json`; missing public RPC and Base 8453 env names |
| 2026-05-15 | `npm install` | passed | installed root workspace dependencies needed by aggregate checks |
| 2026-05-15 | `npm install --prefix apps/dashboard` | passed | installed dashboard dependencies |
| 2026-05-15 | `npm install --prefix crypto` | passed | installed crypto dependencies |
| 2026-05-15 | `npm run flowchain:production-l1:e2e` | first run failed on missing deps | logs under `devnet/local/production-l1-e2e/logs/` |
| 2026-05-15 | `npm run flowchain:production-l1:e2e` | passed-with-live-blockers, exit 0 | `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json` |
| 2026-05-15 | `npm run flowchain:service:start -- -LiveProfile` | passed | `devnet/local/services/flowchain-service-start-report.json`; `maxBlocks=0` |
| 2026-05-15 | `npm run flowchain:service:status -- -AllowBlocked` | passed while services were running | `docs/agent-runs/live-product-infra-rpc/service-status-report.json` |
| 2026-05-15 | `npm run flowchain:service:stop` | passed | `docs/agent-runs/live-product-infra-rpc/service-stop-report.json`; state preserved |
| 2026-05-15 | `npm run flowchain:no-secret:scan` | passed | `devnet/local/production-l1-e2e/no-secret-scan-report.json` |
| 2026-05-15 | `node infra/scripts/check-unsafe-claims.mjs` | passed | checked README, docs, contracts |
| 2026-05-15 | `git diff --check` | passed with CRLF warnings | no whitespace errors |
| 2026-05-15 | live-infra scoped no-secret scan | passed | `docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json` |

## Notes For Final Run

The final local result without owner inputs is `blocked`, not a pass claim. The exact missing env names are recorded in `flowchain-live-infra-check-report.json`.
