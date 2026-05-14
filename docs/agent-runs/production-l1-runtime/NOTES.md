# Production L1 Runtime Notes

## Current Observations

- Work started from branch `agent/production-l1-runtime`.
- The repo already exposes the requested root npm aliases for node, status, stop, tx, faucet, and node smoke.
- The task remains bounded to private/local L1 behavior; no production mainnet, public validator, tokenomics, audited bridge, or custody claims.
- The local branch is behind `origin/main` by two real-value pilot bridge/contract commits. Those commits are outside this task's allowed edit scope except for unrelated package scripts, so this runtime work remains scoped and should merge/rebase before PR finalization.

## Current Runtime Map

- CLI commands now include `node`, `node-stop`, `node-status`, `node-restart`, `tick`, `submit-tx`, `list-mempool`, query shortcuts, `export-state`, `import-state`, and `node-smoke`.
- Default persistent state path is `devnet/local/state.json`; node operator files live under `devnet/local/node/`; smoke proof files live under `devnet/local/node-smoke/`.
- Runtime status is written as `node/status.json`; append-only node activity is written as `node/node.log.jsonl`.
- Transaction intake supports direct CLI submission and node file inbox ingestion. Signed local transaction envelopes are validated against the crypto fixture shape without editing `crypto/`.
- Current block format stores number, parent hash, logical time, tx ids, receipts, events, state root, receipt root, event root, finalized height, and block hash.
- Current transaction surface includes local object lifecycle payloads plus local balance transfer, token launch/transfer/mint, DEX pool/liquidity/swap flows, Base 8453 bridge credit application, and withdrawal intent recording.
- Runtime gaps that remain intentionally local/private: no production consensus, no public peer networking, no gas market, no custody system, no audited bridge security claim, and no production withdrawal broadcast.

## Implementation Notes

- State roots include application state maps and bridge/withdrawal state, while mempool/query indexes are kept out of the application state root so rejected or pending txs do not mutate canonical app state.
- Signed envelope replay is tracked by tx id, nonce, and replay key. Locally authorized txs keep deterministic ids and can be used for private smoke automation.
- Bridge credit execution requires `sourceChainId` 8453 and a one-time replay key before crediting local spendable test units or an existing local token asset.
- Handoff JSON is written both next to state and inside a `handoff/` directory for dashboard, indexer, verifier, and control-plane agents.
