# FlowChain L1 Pilot Explorer Data Contract

Boundary: this contract makes the existing local/control-plane/dashboard surfaces inspectable for capped owner pilot validation. It does not claim public readiness.

## Source Routes

- HTTP: `GET /health`, `GET /state`, `GET /explorer/summary`, `GET /explorer/search?q=...`, `GET /pilot/status`, `GET /pilot/deposits`, `GET /pilot/credits`, `GET /pilot/withdrawal-intents`, `GET /pilot/release-evidence`.
- JSON-RPC: `block_list`, `block_get`, `transaction_list`, `transaction_get`, `receipt_list`, `receipt_get`, `account_list`, `account_get`, `balance_get`, `wallet_metadata_list`, `token_list`, `token_get`, `token_balance_list`, `token_balance_get`, `token_transfer_list`, `token_transfer_get`, `pool_list`, `pool_get`, `lp_position_list`, `lp_position_get`, `swap_list`, `swap_get`, `bridge_observation_list`, `bridge_observation_get`, `bridge_deposit_list`, `bridge_deposit_get`, `bridge_credit_list`, `bridge_credit_get`, `withdrawal_list`, `withdrawal_get`, `pilot_*`, `explorer_search`, `raw_json_get`.
- Fallback: `fixtures/dashboard/flowchain-l1-explorer-fallback.json`, copied to `apps/dashboard/public/data/flowchain-l1-explorer-fallback.json`.

## Entity Fields

- Block: height, hash, parent hash, state root, receipt root when present, finalized, transaction count, event count, provenance.
- Transaction: tx ID, payload type, signer, nonce, status, block hash/height, receipt reference, failed error code/message.
- Receipt/event: receipt by tx ID, event ID, block, tx, account, token, pool, bridge IDs.
- Account: address/account ID, public key when available, native balance, token balances, nonce, recent txs, LP positions.
- Token: token ID, symbol, name, supply, issuer/owner, launch tx, balances, transfers.
- DEX: pool ID, token pair, reserves, LP supply, LP positions, liquidity actions, swaps.
- Bridge: observation ID, source chain ID, Base tx hash, log index, lockbox, depositor, local recipient, asset, amount, credit ID, withdrawal intent ID, release evidence ID, replay status.
- Provenance: live runtime, local import, Base observation, deterministic fixture fallback, with the fallback path visible to the UI.

## Search Keys

`explorer_search` indexes block heights/hashes, tx IDs, accounts, token IDs/symbols, pool IDs, Base tx hashes, bridge observations, bridge credits, withdrawal intents, release evidence, local transfer tx IDs, and swap tx IDs.
