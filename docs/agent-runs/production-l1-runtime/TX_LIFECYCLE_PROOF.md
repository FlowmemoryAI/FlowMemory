# Transaction Lifecycle Proof

## Intake

The runtime accepts transactions through:

- `submit-tx --tx-file <path>` for direct local CLI submission.
- The node inbox path under `<node-dir>/tx/` for a running node.
- `--direct` for synchronous smoke and test automation.

Supported input shapes are signed local transaction envelopes, a single `tx`, or a batch under `txs`.

## Validation

Signed envelopes are validated before mempool insertion:

- Schema shape and transaction payload are parsed.
- Chain id must match the runtime chain id, default `31337`.
- Payload hash, domain separator, envelope hash, digest, signer role, public key, and secp256k1 signature are checked against the local crypto envelope rules.
- Nonce must be the next nonce for the signer; stale and future nonce conflicts are rejected.
- Tx id, replay key, and consumed transaction indexes reject duplicate or replayed transactions.
- A preflight execution check rejects insufficient balances, unknown payloads, duplicate object ids, wrong bridge source chain, and bridge replay keys before canonical block inclusion.
- The mempool is bounded at 1024 pending transactions.

## Inclusion

Block production selects pending transactions deterministically, executes them, stores a `StoredTransaction`, writes a `StoredReceipt`, emits one event per included transaction, updates indexes, and removes included txs from the mempool.

## Smoke Evidence

`npm run flowchain:node:smoke` submitted a signed transaction from `crypto/fixtures/local-transaction-vectors.json`, accepted it exactly once as:

```text
0xfba94617ac6fbae608393c67570280d7123b27dabb0c1f31427808ad955a7c46
```

The same tx was queried after inclusion and after restart. A replay submit was rejected with:

```text
duplicate-tx-id
```

The full evidence record is `devnet/local/node-smoke/production-node-smoke-report.json`.
