# Private/Local L1 Execution Handoff

Status: PR-ready local execution handoff.

## Transaction Types

Execution/product transaction types now supported by the Rust devnet:

- `CreateLocalTestUnitBalance`
- `FaucetLocalTestUnits`
- `TransferLocalTestUnits`
- `ApplyBridgeCredit`
- `LaunchToken`
- `MintLocalTestToken`
- `TransferToken`
- `CreatePool`
- `AddLiquidity`
- `RemoveLiquidity`
- `SwapExactIn`
- existing Rootflow and Flow Memory object transactions

Product flow order:

1. Create Alice and Bob local accounts.
2. Apply Alice bridge credit.
3. Transfer local units Alice to Bob.
4. Launch `FLOWT`.
5. Transfer `FLOWT` Alice to Bob.
6. Create local-unit/FLOWT pool.
7. Add liquidity.
8. Swap exact input.
9. Remove liquidity.
10. Anchor state.

## Receipt Fields

Block receipts now include:

- `txId`
- `receiptId`
- `status`
- `success`
- `error`
- `errorCode`
- `executionCostUnits`
- `executionCostCharged`
- `eventIds`
- `authorization`

Queryable execution receipts live in `executionReceipts` and include:

- `receiptId`
- `txId`
- `txType`
- `status`
- `success`
- `errorCode`
- `errorMessage`
- `executionCostUnits`
- `executionCostCharged`
- `payerAccountId`
- `eventIds`
- `blockNumber`
- `noValue`

Execution events live in `executionEvents` and include:

- `eventId`
- `receiptId`
- `txId`
- `eventType`
- `objectId`
- `accountId`
- `assetId`
- `amountUnits`
- `blockNumber`
- `status`

Success event types include `native_transfer`, `bridge_credit_applied`, `token_launched`, `token_minted`, `token_transfer`, `pool_created`, `liquidity_added`, `liquidity_removed`, `swap_executed`, and `transaction_applied`. Failures emit `execution_failed`.

## State Output Paths

Execution E2E:

```text
devnet/local/execution-e2e/state.json
devnet/local/execution-e2e/execution-e2e-report.json
devnet/local/execution-e2e/dashboard-state.json
devnet/local/execution-e2e/indexer-handoff.json
devnet/local/execution-e2e/verifier-handoff.json
devnet/local/execution-e2e/control-plane-handoff.json
devnet/local/execution-e2e/genesis-config.json
devnet/local/execution-e2e/operator-key-references.json
```

Product smoke:

```text
devnet/local/product-execution-smoke/state.json
devnet/local/product-execution-smoke/control-plane-handoff.json
```

Generated report schema:

```text
flowmemory.local_devnet.execution_e2e_report.v0
```

## Maps And Roots

New execution maps are part of deterministic state roots and map roots:

- `accountNonces`
- `balanceTransfers`
- `bridgeCreditReceipts`
- `tokenDefinitions`
- `tokenBalances`
- `tokenMintReceipts`
- `tokenTransferReceipts`
- `dexPools`
- `lpPositions`
- `liquidityReceipts`
- `swapReceipts`
- `executionReceipts`
- `executionEvents`

Dashboard, indexer, verifier, and control-plane handoff files include these maps.

## RPC And Dashboard Requirements

Control-plane/RPC surfaces should expose read methods for:

- account balance by account id
- account nonce by account id
- bridge credit receipt by credit id
- native transfer by transfer id
- token definition by token id
- token balance by token id and account id
- token transfer receipt by transfer id
- DEX pool by pool id
- LP position by pool id and owner account id
- liquidity receipt by id
- swap receipt by id
- execution receipt by receipt id and by tx id
- execution events by receipt id and tx id
- latest state root and map roots
- block by block hash or height

Dashboard requirements:

- Show native units, bridge credited units, reserved units, and available units.
- Show account nonce status.
- Show token metadata, supply, and per-account balances.
- Show pool pair, reserves, LP supply, LP position accounting, and swap result.
- Show success and failed receipts with error code, execution cost units, and event ids.
- Keep all copy local/no-value and avoid production bridge, tokenomics, public validator, or mainnet claims.

## Verification

Commands run for this handoff:

```powershell
cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/product-execution-smoke/state.json product-smoke --out-dir devnet/local/product-execution-smoke
npm run flowchain:execution:e2e
npm run flowchain:product-e2e
npm run flowchain:real-value-pilot:runtime
```

`npm run flowchain:product-e2e` passes after installing root, dashboard, and crypto dependencies from lockfiles. It writes `devnet/local/product-e2e/flowchain-product-e2e-report.json`.

`npm run flowchain:real-value-pilot:runtime` passes and points to the execution E2E. The broader `flowchain:real-value-pilot:e2e` coordinator still needs the contracts and bridge-relayer proof gates in this checkout.
