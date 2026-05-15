# Wallet Integration

FlowChain wallet builders should integrate with the FlowChain-native JSON-RPC
surface, not EVM JSON-RPC compatibility.

## Account ID Shape

Local developer accounts commonly use readable IDs such as:

```text
local-account:alice
```

Base 8453 bridge recipients use 32-byte FlowChain account IDs:

```text
0x...64 hex characters...
```

Wallets should show the exact destination account ID before signing or
bridging.

## Signing Envelope Shape

`transaction_submit` accepts only signed envelopes:

```json
{
  "schema": "flowchain.local_transaction_envelope.v0",
  "tx": {
    "type": "TransferLocalTestUnits",
    "transferId": "transfer:wallet:001",
    "fromAccountId": "local-account:alice",
    "toAccountId": "local-account:bob",
    "amountUnits": 1,
    "memo": "wallet-send"
  },
  "signature": {
    "scheme": "local-dev-signature-placeholder",
    "signer": "operator:wallet",
    "digest": "local-dev-digest:TransferLocalTestUnits"
  }
}
```

The SDK validates envelope shape locally and rejects unsigned envelopes before
calling RPC.

## Receive Flow

1. Read wallet metadata with `wallet_metadata_list` or `wallet_metadata_get`.
2. Display the account ID exactly.
3. For bridge receive, require a bytes32 account ID.
4. Do not expose custody material in browser or server responses.

## Send Flow

1. Fetch balance with `balance_get` or wallet balance rows with
   `wallet_balance_list`.
2. Build a transaction object.
3. Sign locally.
4. Submit with `client.submitSignedTransaction(envelope, { runtimeSubmit: true })`.
5. Poll `transaction_get`, `block_list`, and `finality_get`.

## Activity Query Flow

Use:

- `transaction_list`
- `wallet_transfer_history`
- `bridge_credit_status`
- `finality_get`

## Backup And Import Boundaries

The SDK does not implement server-side custody. Wallet backup/import belongs in
local wallet tooling. Public metadata can be returned to browsers; custody
material must stay local and must not appear in RPC responses, logs, examples,
or generated docs.

## No Server-Side Custody Rule

Do not send custody material to FlowChain RPC. RPC writes must receive signed
envelopes only.
