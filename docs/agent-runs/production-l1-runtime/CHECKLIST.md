# Production L1 Runtime Checklist

- [x] Current runtime map documented.
- [x] Runtime config includes chain id, network profile, genesis path, data dir, block interval, signer identity reference, and peer config path.
- [x] Persistent store tracks latest/finalized block, roots, accounts, balances, token state, pools, LP positions, bridge credits, receipts, and events.
- [x] Mempool accepts signed or locally authorized envelopes exactly once.
- [x] Mempool rejects wrong chain, malformed signature, duplicate tx id, replay, stale nonce, future nonce conflict, insufficient balance, unknown payload, and bridge replay.
- [x] Block production supports manual tick and interval or bounded loop mode.
- [x] Queries cover status, mempool, block, transaction, receipt, account, token, pool, bridge credit, and finality receipt.
- [x] Restart preserves height, latest hash, finalized height, state root, balances, receipts, pending mempool transactions, and bridge replay keys.
- [x] Export/import preserves deterministic roots.
- [x] Handoff JSON is written for control-plane and dashboard agents.
- [x] Required proof and handoff docs are written.
- [x] Final cargo tests, node smoke, npm smoke, and `git diff --check` pass.
