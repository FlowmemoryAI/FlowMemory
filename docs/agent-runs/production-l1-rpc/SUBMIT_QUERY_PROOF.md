# Submit Query Proof

Command:

```powershell
npm run control-plane:smoke
```

Smoke submitted a versioned signed transfer envelope:

```json
{
  "schema": "flowchain.signed_transaction_envelope.v1",
  "chainId": "flowmemory-local-devnet-v0",
  "signer": "0x<20-byte-local-smoke-signer>",
  "nonce": "0",
  "signatureScheme": "flowchain-local-digest-v1",
  "payload": {
    "schema": "flowchain.transaction.transfer.v1",
    "type": "transfer",
    "from": "account:submit:alice",
    "to": "account:submit:bob",
    "tokenId": "local-test-unit",
    "amount": "7"
  }
}
```

The API returned:

- method: `transaction_submit`
- result schema: `flowmemory.control_plane.transaction_submit_result.v1`
- status: `accepted_local`
- source: `local-file-intake`
- receipt source: `flowmemory.control_plane.transaction_receipt.v1`

The same smoke then queried:

- `transaction_get` with the submitted `txId`;
- `receipt_get` with `{ "txId": submittedTxId }`;
- `balance_get` with `{ "accountId": "account:submit:bob", "tokenId": "local-test-unit" }`.

The balance proof returned `amount: "7"` with `pendingAcceptedDelta: "7"`, proving the submitted local transfer is visible through stable account/balance fields without file scraping.

The smoke also verified expected rejection paths:

- invalid signature -> `BAD_SIGNATURE`;
- duplicate transaction -> `DUPLICATE_TX`;
- wrong chain id -> `WRONG_CHAIN_ID`;
- stale nonce -> `STALE_NONCE`.
