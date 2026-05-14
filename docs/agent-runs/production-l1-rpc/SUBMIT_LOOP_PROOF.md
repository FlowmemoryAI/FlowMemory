# Submit Loop Proof

The submit/query loop is implemented inside the existing control-plane boundary:

1. `transaction_submit` accepts only `flowchain.signed_transaction_envelope.v1`.
2. It rejects unsigned/plain `transaction`, `tx`, and `txs` payloads.
3. It rejects secret-shaped requests before intake.
4. It checks the submitted `chainId` against `chain_status.chainId`.
5. It checks signer hex format.
6. It checks nonce ordering per signer.
7. It verifies the local deterministic signature digest.
8. It rejects duplicate transaction ids.
9. It appends accepted rows to `devnet/local/intake/transactions.ndjson`.
10. It exposes the accepted row through `transaction_get`, `mempool_list`, `receipt_get`, `event_list`, and `balance_get`.

Smoke evidence:

```json
{
  "methodCount": 91,
  "successCount": 87,
  "expectedErrorCount": 4,
  "queried": {
    "submittedTxId": "0x...",
    "tokenId": "local-test-unit"
  }
}
```

The submitted transfer is local/private and no-value. The API does not claim public-chain broadcast or production custody.
