# Private/Local L1 Execution Completion Audit

Status: complete for the assigned devnet execution scope.

## Objective

Implement and harden FlowChain private/local L1 devnet execution for:

- account balances and bridge credits
- deterministic gas/cost recording
- native transfers
- token launch, local test mint, token transfer, and balance queries
- DEX pool creation, liquidity add/remove, swaps, reserves, and LP positions
- success and failed receipts/events
- deterministic state roots and map roots
- E2E proof, negative/invariant tests, reports, and handoff docs

## Prompt-To-Artifact Checklist

| Requirement | Evidence | Status |
| --- | --- | --- |
| Create tracking files first | `PLAN.md`, `CHECKLIST.md`, `EXPERIMENTS.md`, `NOTES.md` in this directory | Done |
| Native local balance ledger | `LocalTestUnitBalance` includes units, bridge credited units, reserved units, faucet fields; transfer and bridge credit transactions mutate balances | Done |
| Bridge credited balance | `ApplyBridgeCredit`, `BridgeCreditReceipt`, bridge credit roots, execution E2E bridge credit report | Done |
| Reserved/pending balance where needed | `reservedUnits` represented; current flow has no cross-block reservation path | Done |
| Insufficient balance failure | Tests cover insufficient native and token balances; failed receipts include error codes | Done |
| Deterministic execution cost table | `execution_cost_units`; every execution receipt records `executionCostUnits` and charged flag | Done |
| Optional native execution charging | `charge-native` config test rejects insufficient execution balance atomically | Done |
| Wallet A to B transfer | Product flow transfers Alice local units to Bob | Done |
| Nonce increments | `accountNonces`; duplicate/stale tests; E2E report includes Alice and Bob nonces | Done |
| Receipt and event generation | `ExecutionReceipt`, `ExecutionEvent`, block receipt fields, event IDs | Done |
| Token launch validation | Token id, symbol, name, decimals, supply, duplicate id/symbol validation | Done |
| Local test mint | `MintLocalTestToken`, mint receipts, local/no-value doc boundary | Done |
| Token transfer and balance query state | `TransferToken`, `tokenBalances`, `tokenTransferReceipts`, product E2E token transfer | Done |
| Pool creation | `CreatePool`, deterministic pool id, product smoke report | Done |
| Add/remove liquidity | `AddLiquidity`, `RemoveLiquidity`, reserve/LP accounting, liquidity receipts | Done |
| Swap exact input | `SwapExactIn`, constant-product floor math, minimum output guard | Done |
| LP positions | `lpPositions`, LP supply and position invariant test | Done |
| Failed swap receipt | Negative E2E includes `min-output-not-met`, `invalid-swap-amount`, and `invalid-pool` failed receipts | Done |
| Failed transaction receipts | Atomic failure path commits failed execution receipt and `execution_failed` event only | Done |
| Execution error codes | E2E failed evidence includes duplicate nonce, stale nonce, insufficient balances, invalid token/pool/liquidity/swap, min-output, duplicate bridge credit, duplicate transaction | Done |
| State root includes execution maps | `state_root`, `state_map_roots`, anchors, reports include account nonce, bridge credit, token, pool, LP, swap, receipt, and event roots | Done |
| E2E flow from bridge credit to DEX | `npm run flowchain:execution:e2e`; report has bridge credit, transfer, token launch, token transfer, pool, add liquidity, swap, remove liquidity | Done |
| Negative tests | `execution_layer_records_failed_receipts_and_preserves_product_invariants` and CLI report test cover required negative cases | Done |
| Invariant tests | Token supply, LP supply/positions, bridge replay, nonce behavior, failed atomicity, export/import | Done |
| State survives restart and export/import | `cli_execution_e2e_writes_report_and_round_trips_state` inspects restarted state and compares exported/imported state JSON | Done |
| Product E2E command | `npm run flowchain:product-e2e` passed; report status `passed`, missing coverage `0` | Done |
| Execution E2E command | `npm run flowchain:execution:e2e` passed; report status summary has 11 success and 11 failed receipts | Done |
| Real-value pilot runtime proof | `npm run flowchain:real-value-pilot:runtime` passed and aliases to execution E2E | Done |
| Broader real-value pilot coordinator | `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete -SkipBaseline` reports only contracts and bridge-relayer proofs missing in this checkout | Runtime done; external gates pending |
| `git diff --check` | Passed after final docs/code changes | Done |
| Execution report JSON | `devnet/local/execution-e2e/execution-e2e-report.json` generated with tx IDs, receipt IDs, balances, pool reserves, LP positions, swap result, roots, and failed evidence | Done |
| Proof docs | `BALANCE_MODEL.md`, `TOKEN_PROOF.md`, `DEX_PROOF.md`, `BRIDGE_CREDIT_SPEND_PROOF.md`, `INVARIANT_PROOF.md` | Done |
| Handoff docs | `HANDOFF.md` lists transaction types, receipt fields, state output paths, and RPC/dashboard requirements | Done |
| Local devnet docs | `docs/LOCAL_DEVNET.md` documents execution commands, state maps, rules, roots, handoff maps, and non-goals | Done |
| Acceptance docs | `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md` includes execution acceptance and E2E evidence | Done |
| Unsafe production claims | `node infra/scripts/check-unsafe-claims.mjs` passed | Done |

## Report Evidence

Execution E2E report:

- Path: `devnet/local/execution-e2e/execution-e2e-report.json`
- Schema: `flowmemory.local_devnet.execution_e2e_report.v0`
- State root: `0xb59214e331c7ee9384a9409acbbe4f61049270005a80f4582fa53df3d186dcb3`
- Product transactions: 10
- Negative transactions: 11
- Execution receipts: 22
- Failed transaction evidence entries: 11
- Bridge credit receipts: 1
- Swap receipts: 1

Product E2E report:

- Path: `devnet/local/product-e2e/flowchain-product-e2e-report.json`
- Schema: `flowchain.product_testnet_v1.e2e_report.v0`
- Status: `passed`
- Missing coverage: 0
- Runtime product-smoke token launch, swap, and receipt-query checks: passed
- Wallet product smoke: passed

## Commands Verified

```powershell
npm ci
npm ci --prefix apps/dashboard
npm ci --prefix crypto
cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/product-execution-smoke/state.json product-smoke --out-dir devnet/local/product-execution-smoke
npm run flowchain:execution:e2e
npm run flowchain:product-e2e
npm run flowchain:real-value-pilot:runtime
npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete -SkipBaseline
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

## Known Integration Note

This worktree is behind `origin/main` by two real-value-pilot commits. The incoming changes add pilot aliases near the package script area. Merge/rebase should preserve the new `flowchain:execution:e2e` alias.
