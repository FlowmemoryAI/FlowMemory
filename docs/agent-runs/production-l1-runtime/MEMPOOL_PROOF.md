# Mempool Proof

## Behavior

- Pending transactions are persisted in `state.pendingTxs`.
- The mempool is bounded at 1024 transactions.
- Ordering is deterministic by the runtime queue order and block production path.
- Duplicate tx ids are rejected.
- Signed transaction replay keys are rejected.
- Same signer nonce conflicts are rejected unless the next expected nonce is supplied.
- Pending transactions survive restart because they are part of the state file.
- Included transactions are removed from pending state and indexed in `transactions`, `receipts`, `consumedTxs`, and replay maps.

## Query Surface

Operators and RPC/dashboard agents can query:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- list-mempool
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-status
```

`node-status` exposes `pendingTxs`, `maxMempoolTxs`, `accountNonces`, `consumedTxs`, and `bridgeReplayKeys`.

## Smoke Evidence

The node smoke accepted 26 transactions, produced receipts for all 26, and ended with:

```text
pendingTxs: 0
maxMempoolTxs: 1024
accountNonces: 1
consumedTxs: 26
receipts: 26
events: 26
```

The signed transaction replay was rejected after inclusion with `duplicate-tx-id`.
