# Production L1 Runtime Handoff

## Command List

Root npm aliases:

```powershell
npm run flowchain:node
npm run flowchain:node:stop
npm run flowchain:node:status
npm run flowchain:node:restart
npm run flowchain:tx -- --tx-file <path>
npm run flowchain:node:smoke
```

Direct Rust commands:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-stop
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-status
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- tick
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- submit-tx --tx-file <path>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- list-mempool
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query --kind <kind> --id <id>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- export-state --out <path>
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- import-state --from <path>
```

## Runtime Output Paths

- State: `devnet/local/state.json`
- Node status: `devnet/local/node/status.json`
- Node log: `devnet/local/node/node.log.jsonl`
- Node identity reference: `devnet/local/node/node-identity.json`
- Runtime handoff: `devnet/local/runtime-handoff.json`
- Preferred control-plane handoff: `devnet/local/handoff/control-plane-handoff.json`
- Preferred dashboard handoff: `devnet/local/handoff/dashboard-state.json`
- Preferred indexer handoff: `devnet/local/handoff/indexer-handoff.json`
- Preferred verifier handoff: `devnet/local/handoff/verifier-handoff.json`
- Smoke report: `devnet/local/node-smoke/production-node-smoke-report.json`

## Transaction Intake Path

Use `submit-tx --tx-file <path>` for direct local submission. A running node also ingests JSON transaction files from its local inbox under `<node-dir>/tx/`; processed files are moved under `<node-dir>/processed/`, and rejected intake writes structured evidence with a rejection reason.

Accepted transaction files can contain:

- A signed `flowchain.local_transaction_envelope.v0` envelope.
- A single local `tx`.
- A batch under `txs`.

## State Query Paths

Use CLI query commands now; an RPC agent should map them directly:

- `node-status` for chain/node status.
- `list-mempool` for pending txs.
- `query-block --id <height-or-hash>`.
- `query-tx --id <tx-id>`.
- `query-receipt --id <tx-id-or-receipt-id>`.
- `query-account --id <account-id>`.
- `query-token --id <token-id>`.
- `query-pool --id <pool-id>`.
- `query-bridge-credit --id <credit-id>`.
- `query-finality --id <finality-receipt-id>`.

## RPC Fields To Expose

Expose these fields from `node-status` and the handoff JSON:

- `chainId`
- `networkProfile`
- `genesisPath`
- `dataDirectory`
- `blockIntervalMs`
- `validatorIdentityRef`
- `peerConfigPath`
- `status`
- `nodeId`
- `statePath`
- `nodeDir`
- `latestHeight`
- `latestHash`
- `finalizedHeight`
- `stateRoot`
- `receiptRoot`
- `eventRoot`
- `pendingTxs`
- `maxMempoolTxs`
- `accountNonces`
- `consumedTxs`
- `bridgeReplayKeys`
- `receipts`
- `events`
- `logPath`
- `lastError`

For object queries, expose accounts, local balances, token definitions, token balances, pools, LP positions, bridge observations, bridge credits, withdrawal intents, transactions, receipts, and events.

## Incomplete Execution Payloads

- Production consensus and public peer networking are not implemented.
- Gas, fee market, tokenomics, staking, rewards, and slashing are not implemented.
- Bridge credit is a local/private execution handoff, not audited production bridge security.
- Withdrawal intent records local requested withdrawals but does not broadcast a live Base release.
- ToolReceipt, EvalReceipt, and DependencyAtom remain outside this runtime change unless mapped by another agent.
