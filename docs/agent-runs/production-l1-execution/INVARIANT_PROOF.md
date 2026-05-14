# Invariant Proof

Status: implemented for private/local execution proof.

## Atomic Execution

Each block transaction runs against a cloned candidate state. On success the candidate becomes canonical. On failure, only an execution receipt and failed event are committed; the business mutation is discarded.

This protects:

- native balances from partial failed transfers
- token balances from partial failed token transfers
- pool reserves from partial failed swaps
- bridge credits from duplicate minting
- account nonces from failed transactions

## Covered Negative Cases

Tests cover:

- insufficient native balance
- insufficient token balance
- duplicate transaction id
- duplicate nonce
- stale nonce
- duplicate transfer id
- invalid token id
- invalid pool id
- invalid liquidity amount
- invalid swap amount
- minimum output not met
- duplicate bridge credit
- insufficient execution balance when native charging is enabled

## Invariants

Runtime tests assert:

- total token balances equal token total supply after transfers and failed transactions
- pool reserve changes match deterministic swap math
- pool total LP supply equals LP positions after add/remove
- duplicate bridge credit cannot mint twice
- account nonce state advances only on successful transactions
- failed transactions still produce failed receipts with stable error codes
- deterministic replay covers state roots and map roots
- execution E2E state survives restart inspection and export/import round trip

## Evidence

Primary tests:

- `execution_layer_records_failed_receipts_and_preserves_product_invariants`
- `execution_cost_charge_mode_rejects_insufficient_execution_balance_atomically`
- `cli_execution_e2e_writes_report_and_round_trips_state`
- `product_demo_transactions_apply_in_one_block_with_receipts`
- `token_launch_pool_liquidity_swap_and_remove_update_product_state`

Primary commands:

```powershell
cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml
npm run flowchain:execution:e2e
```
