# FlowChain SDK / Docs / Devkit Handoff

Date: 2026-05-15

## What Changed

- Added `packages/flowchain-sdk/`, a dependency-free FlowChain-native JSON-RPC
  SDK with typed helpers, signed-envelope validation, tagged errors, and
  redaction.
- Added `tools/flowchain-devkit.mjs` CLI commands for discovery, readiness,
  chain status, local account metadata, signed transfer submission, inclusion
  waits, balances, bridge readiness, bridge lifecycle, and finality.
- Added `tools/flowchain-rpc-reference.mjs` and generated
  `docs/sdk/rpc-reference.json` plus `docs/sdk/rpc-reference.md` from
  `rpc_discover`.
- Added `tools/flowchain-sdk-e2e.mjs` and root script
  `npm run flowchain:sdk:e2e`.
- Added Node, browser/Vite, bridge-readiness, and wallet-send examples under
  `examples/flowchain-*`.
- Added developer docs under `docs/developer/` and SDK docs under `docs/sdk/`.
- Updated root `package.json` and `package-lock.json` for SDK/devkit scripts and
  workspace registration.

## Changed Files

- `package.json`
- `package-lock.json`
- `packages/flowchain-sdk/**`
- `tools/flowchain-devkit.mjs`
- `tools/flowchain-rpc-reference.mjs`
- `tools/flowchain-sdk-e2e.mjs`
- `examples/flowchain-node-local/**`
- `examples/flowchain-browser-vite/**`
- `examples/flowchain-bridge-readiness/**`
- `examples/flowchain-wallet-send/**`
- `docs/sdk/**`
- `docs/developer/**`
- `docs/agent-runs/live-product-sdk-docs/**`

## Verification

| Command | Result |
| --- | --- |
| `npm run flowchain:rpc:e2e` | Passed. Report: `devnet/local/rpc-e2e/flowchain-rpc-e2e-report.json`. |
| `npm run flowchain:sdk:e2e` | Passed. Report: `docs/agent-runs/live-product-sdk-docs/flowchain-sdk-e2e-report.json`. |
| `npm run flowchain:wallet:transfer:e2e` | Passed. Report: `devnet/local/production-l1-e2e/wallet-transfer/wallet-transfer-e2e-report.json`. |
| `npm run flowchain:production-l1:e2e` | Failed. Report: `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`. |
| `npm run flowchain:no-secret:scan` | Passed. Report: `devnet/local/production-l1-e2e/no-secret-scan-report.json`. |
| `node infra/scripts/check-unsafe-claims.mjs` | Passed. |
| `git diff --check` | Passed with line-ending warnings for `package.json` and `package-lock.json`. |

## SDK E2E Proof

`npm run flowchain:sdk:e2e`:

- starts isolated local runtime state under `devnet/local/sdk-e2e/runtime`;
- serves the real control-plane JSON-RPC dispatcher over local HTTP;
- calls discovery/readiness through the SDK;
- checks generated RPC reference drift;
- verifies public RPC and Base 8453 blockers are names only;
- submits signed local create/faucet/transfer envelopes through
  `transaction_submit`;
- verifies mempool visibility before block production;
- produces a block with `crates/flowmemory-devnet`;
- reads block, transaction, account, balance, finality, and provenance;
- runs a CLI command with `--json`;
- runs bridge and node examples;
- checks docs/examples/reference presence and no-secret boundaries.

## Remaining Blockers

The SDK/local developer path is implemented and verified. The aggregate
production gate did not pass in this checkout for these non-SDK blockers:

- Missing installed dependencies:
  - root `node_modules` (`npm install`)
  - `crypto/node_modules` (`npm install --prefix crypto`)
  - `apps/dashboard/node_modules` (`npm install --prefix apps/dashboard`)
- Attempted `npm install --prefix crypto` failed with `ENOSPC`.
- `flowchain:wallet:e2e` failed because `@noble/hashes` is missing for
  `crypto/src/hashes.js`.
- `flowchain:product:e2e -- -SkipFullSmoke` failed because `ajv` is missing for
  `crypto/src/validate-product-testnet-fixtures.js`.
- `flowchain:dashboard:build` failed because dashboard dependencies are missing.
- `flowchain:real-value-pilot:e2e -- -AllowIncomplete -SkipBaseline` remains
  blocked by the bridge-relayer pilot assertion:
  `Missing expected rejection` for `pilot deposit must be from Base chain 8453`.
- Live Base 8453 remains blocked until these names are configured:
  `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_RPC_URL`,
  `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`,
  `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`,
  `FLOWCHAIN_BASE8453_TO_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`,
  `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, `FLOWCHAIN_PILOT_CONFIRMATIONS`.

## Integration Notes

- Use `createFlowChainClient({ rpcUrl: "http://127.0.0.1:8787/rpc" })`.
- Use `client.discover()` and `client.readiness()` before feature detection.
- Use `client.submitSignedTransaction(envelope, { runtimeSubmit: true })` for
  local writes. Do not use unsigned payloads or draft-row writes.
- Do not label the SDK EVM-compatible; discovery reports
  `evmJsonRpcCompatible: false`.
- Regenerate RPC reference after control-plane method changes:
  `node tools/flowchain-rpc-reference.mjs --rpc-url http://127.0.0.1:8787/rpc --write`.
- Re-run `npm run flowchain:sdk:e2e` after SDK, RPC, docs, CLI, or example
  changes.
