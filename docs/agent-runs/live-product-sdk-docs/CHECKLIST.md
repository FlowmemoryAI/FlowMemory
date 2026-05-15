# FlowChain SDK / Docs / Devkit Checklist

Date: 2026-05-15

## Implementation

- [x] Read required repository and control-plane context.
- [x] Confirm SDK surface is FlowChain-native JSON-RPC, not EVM-compatible.
- [x] Add SDK package.
- [x] Add SDK unit tests.
- [x] Add local devkit CLI with `--json`.
- [x] Add generated/checkable RPC reference.
- [x] Add Node example.
- [x] Add browser/Vite example.
- [x] Add bridge readiness example.
- [x] Add wallet send example.
- [x] Add developer docs.
- [x] Add `npm run flowchain:sdk:e2e`.
- [x] Write `flowchain-sdk-e2e-report.json`.
- [x] Write `HANDOFF.md`.

## Verification Commands

| Command | Status | Output / note |
| --- | --- | --- |
| `npm run flowchain:rpc:e2e` | passed | Report: `devnet/local/rpc-e2e/flowchain-rpc-e2e-report.json`. |
| `npm run flowchain:sdk:e2e` | passed | Report: `docs/agent-runs/live-product-sdk-docs/flowchain-sdk-e2e-report.json`. |
| `npm run flowchain:wallet:transfer:e2e` | passed | Report: `devnet/local/production-l1-e2e/wallet-transfer/wallet-transfer-e2e-report.json`. |
| `npm run flowchain:production-l1:e2e` | failed | Existing dependency/live blockers; see `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`. |
| `npm run flowchain:no-secret:scan` | passed | Report: `devnet/local/production-l1-e2e/no-secret-scan-report.json`. |
| `node infra/scripts/check-unsafe-claims.mjs` | passed | Checked README, docs, and contracts. |
| `git diff --check` | passed | Exit 0 with line-ending warnings for `package.json` and `package-lock.json`. |

## Known Live-Only Blockers

- Public RPC deployment remains blocked until the documented
  `FLOWCHAIN_RPC_*` names are configured.
- Base 8453 live bridge remains blocked until the documented
  `FLOWCHAIN_BASE8453_*` and `FLOWCHAIN_PILOT_*` names are configured.
- The SDK must report these names only and must not print values.
- Full production aggregate gate is additionally blocked in this checkout by
  missing installed dependencies: root `node_modules`, `crypto/node_modules`,
  and `apps/dashboard/node_modules`. An attempted `npm install --prefix crypto`
  failed with `ENOSPC`.
