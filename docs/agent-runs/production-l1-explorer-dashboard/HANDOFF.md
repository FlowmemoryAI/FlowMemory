# Handoff

## API Fields And Routes

- Blocks: `block_list`, `block_get`, `GET /explorer/search`.
- Transactions: `transaction_list`, `transaction_get`, `transaction_submit`.
- Receipts/events: `receipt_list`, `receipt_get`, `work_receipt_list`, `work_receipt_get`.
- Accounts/wallets/balances: `account_list`, `account_get`, `balance_get`, `wallet_metadata_list`, `wallet_metadata_get`.
- Tokens: `token_list`, `token_get`, `token_balance_list`, `token_balance_get`, `token_transfer_list`, `token_transfer_get`.
- DEX: `pool_list`, `pool_get`, `lp_position_list`, `lp_position_get`, `swap_list`, `swap_get`.
- Bridge/pilot: `bridge_observation_list/get`, `bridge_deposit_list/get`, `bridge_credit_list/get`, `withdrawal_list/get`, `pilot_deposit_observation_list`, `pilot_credit_list`, `pilot_withdrawal_intent_list`, `pilot_release_evidence_list`, `pilot_cap_status`, `pilot_pause_status`, `pilot_retry_status`, `pilot_emergency_status`.
- Search/raw: `explorer_search`, `raw_json_get`.

## Dashboard Views

Existing `apps/dashboard` workbench views now cover overview, node/API, peers, blocks, transactions, mempool, accounts, balances, wallet metadata, token launches, token balances, token transfers, DEX pools, LP/liquidity, swaps, receipts/events, explorer records, finality, bridge deposits, bridge credits, bridge withdrawals, bridge releases, errors/recovery, provenance, hardware signals, and raw JSON.

## Evidence

- Desktop screenshot: `dashboard-desktop-playwright.png`.
- Mobile screenshot: `dashboard-mobile-playwright.png`.
- Browser DOM/search evidence: `browser-dom-evidence.json`.
- API search evidence: `search-proof-queries.json`.

## Commands

- `npm test --prefix services/indexer`: pass, 19 tests.
- `npm test --prefix services/control-plane`: pass, 21 tests.
- `npm test --prefix apps/dashboard`: pass, 10 tests.
- `npm run build --prefix apps/dashboard`: pass.
- `npm run control-plane:smoke`: pass, `ok: true`, 79 methods.
- `npm run flowchain:l1-e2e`: pass, report `devnet/local/full-smoke/flowchain-full-smoke-report.json`.
- `npm run flowchain:real-value-pilot:control-dashboard`: pass, `ok: true`.
- Browser verification: pass, Playwright evidence saved here.
- `npm run flowchain:real-value-pilot:e2e`: pass after reconciling with `origin/main`; report `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`.

## Reconciliation Note

GitHub issues #133, #138, and #134 are closed. This worktree was reconciled with `origin/main` using `git merge --no-commit --no-ff origin/main`, which brought in the contracts, bridge-relayer, and runtime proof commands needed by the final root pilot gate. The merge is present in the working tree but no commit was created.

No unresolved API/dashboard/indexer dependency remains for this handoff. Public launch, open-validator readiness, tokenomics, broad bridge readiness, and custody claims remain out of scope.
