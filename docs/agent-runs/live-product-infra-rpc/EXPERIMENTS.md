# FlowChain Live Infra RPC Experiments

This file records commands run by this agent and the evidence paths they produce. Do not paste env values, endpoint URLs, private keys, seed phrases, API keys, webhooks, or vault ciphertext here.

| Time UTC | Command | Result | Evidence |
| --- | --- | --- | --- |
| 2026-05-15 | `git status --short --branch` | passed | branch reported as `agent/live-product-infra-rpc...origin/agent/live-product-infra-rpc` |
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
| 2026-05-15 | `npm test --prefix services/control-plane` | passed | active runtime block status/list/get coverage included |
| 2026-05-15 | `npm run flowchain:control-plane:smoke` | passed | full local lifecycle RPC smoke returned `flowmemory.control_plane.smoke.v0` |
| 2026-05-15 | `npm run flowchain:service:restart -- -LiveProfile` | passed | service restarted from this worktree; stale cross-worktree control-plane reuse rejected by code |
| 2026-05-15 | `npm run flowchain:public-rpc:check -- -AllowBlocked` with local-only configured endpoint rehearsal | blocked, not failed | CORS probe executed without printing header values; chain checks matched active moving blocks |
| 2026-05-15 | `npm test --prefix services/control-plane` after CORS server hardening | passed | 29 tests; configured allowed-origin and disallowed-origin behavior covered |
| 2026-05-15 | `npm run flowchain:production-l1:e2e` after CORS hardening | passed-with-live-blockers, exit 0 | `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`; mock/local path passed |
| 2026-05-15 | `npm run flowchain:live-infra:check` after CORS hardening | blocked, exit 1 | service/no-secret passed; public RPC/backup/Base 8453 still blocked on exact owner env names |
| 2026-05-15 | `npm run flowchain:service:stop` after pid-match hardening | passed | expected FlowChain processes stopped only after command-line match; state preserved |
| 2026-05-15 | `npm run flowchain:service:start -- -LiveProfile` after pid-match hardening | passed | service running with `MaxBlocks=0`; status report passed |
| 2026-05-15 | `npm run flowchain:no-secret:scan` | passed | `devnet/local/production-l1-e2e/no-secret-scan-report.json` |
| 2026-05-15 | `node infra/scripts/check-unsafe-claims.mjs` | passed | checked README, docs, contracts |
| 2026-05-15 | `git diff --check` | passed with CRLF warnings | no whitespace errors |
| 2026-05-15 | live-infra scoped no-secret scan | passed | `docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json` |
| 2026-05-15T08:20Z | `npm run flowchain:live-infra:check` after service restore | failed on scanner read failure | traced to aggregate restore stdout/stderr logs held open by long-lived service descendants |
| 2026-05-15T08:24Z | `npm run flowchain:live-infra:check` after controlled service restart and stale log cleanup | blocked, exit 1 | service status passed; no-secret scan passed; remaining blockers were exact owner env names |
| 2026-05-15T08:31Z | `npm run flowchain:production-l1:e2e` inside live-product aggregate | passed-with-live-blockers | `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`; local/mock path passed |
| 2026-05-15T09:31Z | `npm run flowchain:live-product:e2e` after wrapper fixes | blocked, exit 1 | `docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json`; command exited cleanly, production aggregate `passed-with-live-blockers`, live infra `blocked` |
| 2026-05-15T09:32Z | `npm run flowchain:service:status` | passed | node PID `22008`, control-plane PID `5836`, latest height `8876` |
| 2026-05-15T09:32Z | `npm run flowchain:node:status` | passed | node status showed block height `8913` and running PID `22008` |
| 2026-05-15T09:32Z | `npm run flowchain:rpc:e2e` | passed | `devnet/local/rpc-e2e/flowchain-rpc-e2e-report.json`; public readiness remained `BLOCKED` on public RPC env names |
| 2026-05-15T09:32Z | `npm run flowchain:bridge:live:check` | blocked, exit 1 | `devnet/local/bridge-live-readiness/bridge-live-readiness-report.json`; missing Base 8453 env names only |
| 2026-05-15T09:36Z | `npm run flowchain:wallet:e2e` | passed | `devnet/local/production-l1-e2e/wallet-e2e-report.json`; local wallets created, signed, and submitted without secret material export |
| 2026-05-15T09:36Z | `npm run flowchain:wallet:transfer:e2e` | passed | `devnet/local/production-l1-e2e/wallet-transfer/wallet-transfer-e2e-report.json`; wallet-to-wallet transfer included in block `0xcc36dd0a25006afe94f6e26c3c55d3fb4f858dd56f15ed0008d4dad4fbaf4b75` |
| 2026-05-15T09:36Z | `npm run flowchain:real-value-pilot:bridge` | passed | `services/bridge-relayer/out/real-value-pilot-e2e/bridge-real-value-pilot-e2e-report.json`; replay, wrong-chain, and unapproved-contract checks passed |
| 2026-05-15T09:37Z | `npm run flowchain:no-secret:scan` | passed | `devnet/local/production-l1-e2e/no-secret-scan-report.json`; rerun after wallet/bridge artifacts |
| 2026-05-15T09:37Z | live-infra/docs no-secret scan | passed | `docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json`; included docs, live-infra reports, and bridge pilot evidence |
| 2026-05-15T09:37Z | `node infra/scripts/check-unsafe-claims.mjs` | passed | checked README, docs, contracts after evidence updates |
| 2026-05-15T09:37Z | `git diff --check` | passed with CRLF warnings | no whitespace errors |
| 2026-05-15T09:37Z | `npm run flowchain:service:status` | passed | node PID `22008`, control-plane PID `5836`, latest height `9115` |
| 2026-05-15T09:55Z | `npm test --prefix services/control-plane` after live node-inbox send routing | passed | 30 tests, including live node inbox forwarding coverage |
| 2026-05-15T09:55Z | `npm run flowchain:service:restart -- -LiveProfile` | passed | restarted running service so `/wallets/send` used the patched live node inbox path |
| 2026-05-15T09:56Z | `npm run flowchain:wallet:live-service:e2e` | passed after probe timing fix | `docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json`; local service accepted `/wallets/send`, node applied transfer, sender `75`, recipient `25` |
| 2026-05-15T10:07Z | `npm run flowchain:live-product:e2e` with live-service wallet probe included | blocked, exit 1 | `docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json`; production aggregate passed, live-service wallet transfer passed, live infra blocked only on owner env names |
| 2026-05-15T10:08Z | `npm run flowchain:service:status` | passed | node PID `50468`, control-plane PID `47208`, latest height `9965` |
| 2026-05-15T10:10Z | `npm run flowchain:service:status` final refresh | passed | node PID `50468`, control-plane PID `47208`, latest height `10050` |
| 2026-05-15T10:13Z | `npm run flowchain:wallet:live-tester:e2e` initial multi-tester probe | passed | four local tester accounts funded and transferred through live RPC; this exposed that distinct wallet creation needed stronger coverage |
| 2026-05-15T10:18Z | `npm test --prefix services/control-plane` after isolated wallet creation support | passed | `/wallets/create` can create distinct isolated tester wallets without returning private key, ciphertext, or credential material |
| 2026-05-15T10:19Z | `npm run flowchain:wallet:live-tester:e2e` with isolated tester wallets | passed | four isolated tester wallets created through live RPC, funded, transferred in a ring, and settled on produced blocks |
| 2026-05-15T10:40Z | `npm run flowchain:live-product:e2e` with isolated-wallet tester network | blocked, exit 1 | `docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json`; production aggregate passed, single wallet transfer passed, four-tester wallet network passed, live infra blocked only on owner env names |
| 2026-05-15T10:40Z | `npm run flowchain:service:status` | passed | node PID `32660`, control-plane PID `33672`, latest height `10548` |
| 2026-05-15T10:42Z | `npm run flowchain:service:status` final refresh | passed | node PID `32660`, control-plane PID `33672`, latest height `10633` |
| 2026-05-15T10:45Z | `npm run flowchain:tester:readiness -- -AllowBlocked` | blocked as expected | `docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json`; local tester rehearsal ready, external sharing blocked on exact public RPC/backup/Base env names |
| 2026-05-15T10:45Z | `npm run flowchain:service:status` | passed | node PID `32660`, control-plane PID `33672`, latest height `10744` |
| 2026-05-15T10:49Z | `npm test --prefix services/control-plane` after server-side rate limiting | passed | 31 tests; configured per-client rate limit returns JSON `429` without echoing env names |
| 2026-05-15T10:50Z | `npm run flowchain:service:restart -- -LiveProfile` | passed | restarted live service onto isolated-wallet and rate-limit server code |
| 2026-05-15T10:51Z | `npm run flowchain:wallet:live-tester:e2e` after restart | passed | isolated tester wallets created through restarted service; chain advanced from block `10874` to `10902` |
| 2026-05-15T11:00Z | `npm run flowchain:live-product:e2e` after rate-limit hardening | blocked, exit 1 | `docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json`; production aggregate passed, both live wallet probes passed, live infra blocked only on owner env names |
| 2026-05-15T11:01Z | `npm run flowchain:tester:readiness -- -AllowBlocked` | blocked as expected | local tester rehearsal ready, external sharing false, observed height `11016` |
| 2026-05-15T11:04Z | `npm test --prefix services/control-plane` after `/rpc/readiness` env validation | passed | 31 tests; malformed public RPC env values force readiness `FAILED` without printing env values |
| 2026-05-15T11:16Z | `npm run flowchain:live-product:e2e` after readiness validation hardening | blocked, exit 1 | `docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json`; production aggregate passed, both live wallet probes passed, live infra blocked only on owner env names |
| 2026-05-15T11:16Z | `npm run flowchain:tester:readiness -- -AllowBlocked` | blocked as expected | local tester rehearsal ready, external sharing false, observed height `11255` |
| 2026-05-15T11:26Z | `npm run flowchain:completion:audit -- -AllowBlocked` | blocked as expected | `docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json` and `COMPLETION_AUDIT.md`; 8 passed, 4 blocked, 0 failed, latest height `11657` |

## Fix Notes

- `infra/scripts/flowchain-live-product-e2e.ps1` now runs npm subcommands through `cmd.exe /d /s /c npm.cmd ...` instead of resolving the `npm.ps1` shim.
- The live-product restore step is detached, then followed by a bounded service-status polling loop, so the aggregate does not wait forever on long-lived node/control-plane descendants.
- The aggregate no longer redirects service-restore stdout/stderr into report-log files that can be inherited by live service descendants.
- `crates/flowmemory-devnet/src/storage.rs` retries transient Windows atomic replace sharing errors.
- `infra/scripts/flowchain-node-stop.ps1` writes the stop marker directly and preserves pid command-line checks without invoking cargo.
- `infra/scripts/flowchain-common.ps1` sets repo-local cargo temp directories for FlowChain cargo commands.
- `services/bridge-relayer/src/bridge-pilot-e2e.ts` now asserts negative bridge coverage by verifying rejected credits and absence of applied runtime bridge records.
- `crates/flowmemory-devnet/src/cli.rs` batches multi-transaction inbox submissions so account create and faucet/transfer transactions keep order in one node-consumed inbox file.
- `services/control-plane/src/wallet-runtime.ts` queues non-direct `/wallets/send` transactions into the live node inbox at `devnet/local/node`.
- `infra/scripts/flowchain-live-service-wallet-e2e.ps1` verifies wallet funding and wallet-to-wallet transfer through the running RPC service before checking exact post-transfer balances.
- `services/control-plane/src/server.ts` supports isolated local tester wallets through `/wallets/create` so a tester group can create distinct public-only wallet metadata without replacing the operator wallet.
- `services/control-plane/src/server.ts` enforces `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE` when configured, returning JSON `429` with retry timing and without env-value echo.
- `services/control-plane/src/methods.ts` now validates malformed public RPC URL, wildcard public CORS, invalid rate-limit values, and missing TLS acknowledgement in `/rpc/readiness`.
- `infra/scripts/flowchain-completion-audit.ps1` maps each explicit L1/public RPC/wallet/bridge/block-production requirement to report-backed evidence and exits blocked until the exact owner env names are provided.
- `infra/scripts/flowchain-live-service-tester-network-e2e.ps1` creates four isolated tester wallets through the running service, funds their account ids, sends a transfer ring through `/wallets/send`, and verifies exact balances and transfer histories.

## Notes For Final Run

The final local result without owner inputs is `blocked`, not a pass claim. The exact missing env names are recorded in `flowchain-live-infra-check-report.json` and `flowchain-live-product-e2e-report.json`. The running local service can create isolated tester wallets, fund their account ids with local test units, and move local units wallet-to-wallet through `/wallets/send`; public RPC/backup/Base inputs are still required before a public live-ready claim.
