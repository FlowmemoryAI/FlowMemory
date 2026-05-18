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
- [x] Service scripts start/status/stop/restart supervised processes without deleting state.
- [x] Service live profile refuses bounded `MaxBlocks` mode.
- [x] Backup readiness verifies path, writability, latest timestamp, and state readback.
- [x] Bridge infra readiness verifies chain ID, lockbox bytecode, token mode, caps, range, confirmations, ack, and emergency commands.
- [x] Lockbox deployment runbook separates dry-run, broadcast, verification, and post-deploy checks.
- [x] Transaction diagnosis path is documented with env names only.
- [x] `npm run flowchain:live-infra:check` exists.
- [x] Aggregate report is written under `docs/agent-runs/live-product-infra-rpc/`.

## Required Command Evidence

| Command | Status | Evidence |
| --- | --- | --- |
| `npm run flowchain:doctor` | degraded, exit 0 | `devnet/local/doctor/flowchain-doctor-report.json` |
| `npm run flowchain:node:status` | passed | local state summary printed for `devnet/local/state.json` |
| `npm run flowchain:rpc:e2e` | passed | `devnet/local/rpc-e2e/flowchain-rpc-e2e-report.json` |
| `npm run flowchain:bridge:live:check` | blocked, exit 1 | `devnet/local/bridge-live-readiness/bridge-live-readiness-report.json` |
| `npm run flowchain:live-infra:check` | blocked, exit 1 | `docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json` |
| `npm run flowchain:production-l1:e2e` | passed-with-live-blockers, exit 0 | `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json` |
| `npm run flowchain:no-secret:scan` | passed | `devnet/local/production-l1-e2e/no-secret-scan-report.json` |
| `node infra/scripts/check-unsafe-claims.mjs` | passed | output: `Checked launch claims in README.md, docs, contracts.` |
| `git diff --check` | passed with CRLF warnings | no whitespace errors |

## Remaining Blockers

- Owner must provide public RPC env values before public endpoint readiness can pass.
- Owner must provide Base 8453 bridge env values before bridge infrastructure readiness can pass.
- A running node/control-plane process and state backup path are required before the aggregate gate can pass. Service start/status/stop was verified, then stopped to avoid leaving hidden processes running.
