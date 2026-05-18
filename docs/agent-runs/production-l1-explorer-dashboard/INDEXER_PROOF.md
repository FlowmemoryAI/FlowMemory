# Indexer Proof

Command evidence:

- `npm test --prefix services/indexer`: 19 tests passed.
- `npm run index:fixtures --prefix services/indexer`: passed and regenerated `services/indexer/out/indexer-state.json`.
- `npm run flowchain:l1-e2e`: passed.

Indexed explorer projection from the L1 smoke output:

- Blocks: 9.
- Transactions: 9.
- Receipts: 9.
- Events/logs: 10.
- Accounts: 4.
- Tokens: 1.
- Pools: 2.
- Bridge events: 2.
- Failed transactions: 2.
- Duplicate or replay-like events: 2.

Implementation evidence:

- `services/indexer/src/indexer.ts` now emits `state.explorer` with block, transaction, receipt, event, account, token, token-transfer, pool, LP, swap, bridge-event, failed transaction, duplicate/replay, and search-key projections.
- `services/indexer/fixtures/indexer-state.schema.json` requires the `explorer` object.
- `services/indexer/test/indexer.test.ts` asserts explorer counts, token/DEX/bridge fallback indexing, failed transactions, search keys, and duplicate/replay counters.

Coverage note: committed FlowPulse receipts still provide the live-style block/transaction/receipt/event/account/pool rows. Token launch, token transfer, LP, swap, Base 8453 bridge observation, credit, withdrawal, release, and replay rows are imported into the indexer explorer projection from `fixtures/dashboard/flowchain-l1-explorer-fallback.json` with fixture-fallback provenance, so they are visible without being mislabeled as live runtime rows.
