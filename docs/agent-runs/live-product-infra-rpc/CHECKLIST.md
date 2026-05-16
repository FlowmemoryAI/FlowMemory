# FlowChain Live Infra RPC Checklist

## Setup

- [x] Read `AGENTS.md`.
- [x] Read `docs/START_HERE.md`, `docs/FLOWMEMORY_HQ_CONTEXT.md`, and `docs/CURRENT_STATE.md`.
- [x] Read the live infrastructure goal prompt and required task docs/scripts.
- [x] Checked branch/worktree state: local branch is `agent/live-product-infra-rpc`; no remote branch with this exact name existed at start.
- [x] Confirmed `origin/main` is an ancestor of this worktree.

## Build

- [x] Public RPC readiness script exists and writes a machine-readable report.
- [x] Public RPC readiness fails closed without the five required public RPC env names.
- [x] Public RPC readiness calls `/health`, `/rpc/discover`, and `/rpc/readiness`.
- [x] Public RPC readiness verifies chain state against local node state when configured.
- [x] Public RPC readiness probes the configured endpoint CORS header and fails public mode if wildcard CORS is returned.
- [x] Public RPC readiness tolerates active block production by matching the endpoint block against `devnet/local/state.json`, not only a single moving-tip sample.
- [x] Control-plane HTTP server honors `FLOWCHAIN_RPC_ALLOWED_ORIGINS` when configured and rejects disallowed browser origins.
- [x] Control-plane HTTP server enforces `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE` when configured and returns fail-closed JSON `429` responses without echoing env values.
- [x] `/rpc/readiness` validates malformed public RPC URL, wildcard public CORS, invalid rate-limit values, and missing TLS acknowledgement without printing env values.
- [x] Service scripts start/status/stop/restart supervised processes without deleting state.
- [x] Service scripts fail closed on stale/cross-worktree control-plane processes occupying port 8787.
- [x] Service stop refuses to terminate pid-file processes whose command line does not match the expected FlowChain process.
- [x] Service live profile refuses bounded `MaxBlocks` mode.
- [x] Node stop writes the stop marker directly and no longer depends on `cargo run` during service shutdown.
- [x] Repo-local cargo temp directories are used for FlowChain cargo invocations to avoid user `%TEMP%` response-file failures.
- [x] Devnet state persistence retries transient Windows atomic-replace sharing errors while preserving fail-closed storage behavior.
- [x] Control-plane chain status prefers active runtime blocks from `devnet/local/state.json` over fixture/indexer block numbers.
- [x] `block_get` and `block_list` can expose active local runtime blocks with provenance back to `devnet/local/state.json`.
- [x] Backup readiness verifies path, writability, latest timestamp, and state readback.
- [x] Bridge infra readiness verifies chain ID, lockbox bytecode, token mode, caps, range, confirmations, ack, and emergency commands.
- [x] Real-value pilot bridge E2E verifies rejected wrong-source and unapproved-lockbox credits do not create applied runtime bridge records.
- [x] Lockbox deployment runbook separates dry-run, broadcast, verification, and post-deploy checks.
- [x] Transaction diagnosis path is documented with env names only.
- [x] `npm run flowchain:live-infra:check` exists.
- [x] `npm run flowchain:live-product:e2e` runs the production-shaped local aggregate, restores the live service profile, then runs live-infra readiness.
- [x] Live-product aggregate isolates child processes, detaches the long-lived service restore, and polls service status so the command exits `blocked` instead of hanging.
- [x] Live-product aggregate includes a live-service wallet transfer probe against the running RPC service.
- [x] Live-product aggregate includes a four-tester isolated-wallet network probe against the running RPC service.
- [x] External tester readiness report fails closed before public sharing while local tester rehearsal is ready.
- [x] Completion audit report maps every explicit L1 goal requirement to concrete evidence and blocks completion until only exact owner inputs remain.
- [x] Aggregate report is written under `docs/agent-runs/live-product-infra-rpc/`.

## Required Command Evidence

| Command | Status | Evidence |
| --- | --- | --- |
| `npm run flowchain:doctor` | degraded, exit 0 | `devnet/local/doctor/flowchain-doctor-report.json` |
| `npm run flowchain:node:status` | passed | local state summary printed for `devnet/local/state.json`; latest observed node-status block height `8913` |
| `npm run flowchain:rpc:e2e` | passed | `devnet/local/rpc-e2e/flowchain-rpc-e2e-report.json`; generated `2026-05-15T09:32:43.172Z` |
| `npm run flowchain:wallet:e2e` | passed | `devnet/local/production-l1-e2e/wallet-e2e-report.json`; deterministic local wallets created/signed/submitted without exporting secret material |
| `npm run flowchain:wallet:transfer:e2e` | passed | `devnet/local/production-l1-e2e/wallet-transfer/wallet-transfer-e2e-report.json`; wallet transfer recorded in a block with state root `0x8069920a6bb0aaa70f8159a63a060f0404d40762a8b04796d3d08439a0f0961d` |
| `npm run flowchain:wallet:live-service:e2e` | passed | `docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json`; generated `2026-05-15T11:15:07.3887427Z`; `/wallets/send` queued through the running service, chain advanced from block `11180` to `11203`, sender ended at `75`, recipient ended at `25` |
| `npm run flowchain:wallet:live-tester:e2e` | passed | `docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json`; generated `2026-05-15T11:15:52.9490853Z`; four isolated tester wallets created through `/wallets/create`, funded, transferred in a ring, chain advanced from block `11208` to `11234`, balances settled at `108/98/96/98` |
| `npm run flowchain:tester:readiness -- -AllowBlocked` | blocked, exit 0 | `docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json`; generated `2026-05-15T11:16:29.7046977Z`; local tester rehearsal ready, external sharing false until public RPC/backup/Base env names are configured |
| `npm run flowchain:completion:audit -- -AllowBlocked` | blocked, exit 0 | `docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json`; generated `2026-05-15T11:26:21.4529835Z`; 8 requirements passed, 4 blocked, 0 failed; latest observed height `11657` |
| `npm test --prefix services/control-plane` | passed | 31 control-plane unit/integration tests, including active runtime block status/list/get, isolated tester wallet creation, CORS, configured rate-limit, and fail-closed `/rpc/readiness` validation coverage |
| `npm run flowchain:control-plane:smoke` | passed | full local lifecycle RPC smoke returned `flowmemory.control_plane.smoke.v0` |
| `npm run flowchain:bridge:live:check` | blocked, exit 1 | `devnet/local/bridge-live-readiness/bridge-live-readiness-report.json`; missing Base 8453 env names only |
| `npm run flowchain:real-value-pilot:bridge` | passed | `services/bridge-relayer/out/real-value-pilot-e2e/bridge-real-value-pilot-e2e-report.json`; replay, wrong-chain, and unapproved-contract negative checks passed |
| `npm run flowchain:service:start -- -LiveProfile` | started, exit 0 | `devnet/local/services/flowchain-service-start-report.json` |
| `npm run flowchain:service:status` | passed | `docs/agent-runs/live-product-infra-rpc/service-status-report.json`; node PID `14052`, control-plane PID `29264`, height `11255` |
| `npm run flowchain:live-infra:check` | blocked, exit 1 | `docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json`; generated `2026-05-15T11:16:11.6439986Z`; service/no-secret passed, no blocked processes, public RPC/backup/bridge blocked on owner inputs |
| `npm run flowchain:live-product:e2e` | blocked, exit 1 | `docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json`; generated `2026-05-15T11:16:12.2737108Z`; production local aggregate `passed-with-live-blockers`, live-service wallet transfer passed, live-service tester network passed, live infra `blocked` |
| `npm run flowchain:production-l1:e2e` | passed-with-live-blockers, exit 0 | `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json` |
| `npm run flowchain:no-secret:scan` | passed | `devnet/local/production-l1-e2e/no-secret-scan-report.json` |
| `node infra/scripts/check-unsafe-claims.mjs` | passed | output: `Checked launch claims in README.md, docs, contracts.` |
| `git diff --check` | passed with CRLF warnings | no whitespace errors |

## Remaining Blockers

- Owner must provide public RPC env values before public endpoint readiness can pass.
- Owner must provide Base 8453 bridge env values before bridge infrastructure readiness can pass.
- A state backup path is required before the aggregate gate can pass.
- The node/control-plane service path is currently running in live profile with `MaxBlocks=0`; latest completion-audit height was `11657`. Use `npm run flowchain:service:status` to inspect it or `npm run flowchain:service:stop` to stop it.
