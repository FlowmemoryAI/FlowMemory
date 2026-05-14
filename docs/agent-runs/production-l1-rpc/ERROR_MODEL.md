# Error Model

All methods use the versioned JSON-RPC error data envelope:

```json
{
  "schema": "flowmemory.control_plane.error.v1",
  "reasonCode": "transaction.bad_signature",
  "errorCode": "BAD_SIGNATURE",
  "message": "signed envelope signature verification failed",
  "correlationId": "control-plane-local",
  "recoverable": true,
  "retryable": false,
  "sourceComponent": "control-plane",
  "localOnly": true
}
```

Raw exception text is replaced or redacted if it contains secret-shaped material.

| Code | JSON-RPC code | Recoverable | Retryable | Tested route or smoke case |
| --- | ---: | --- | --- | --- |
| `MALFORMED_REQUEST` | `-32600` or `-32602` | yes | no | malformed JSON-RPC request, invalid limits, bad raw JSON source |
| `UNSIGNED_TRANSACTION` | `-32041` | yes | no | `transaction_submit` with plain `transaction` |
| `BAD_SIGNATURE` | `-32041` | yes | no | `invalidSignature` smoke case |
| `WRONG_CHAIN_ID` | `-32041` | yes | no | `wrongChain` smoke case |
| `STALE_NONCE` | `-32041` | yes | no | `staleNonce` smoke case |
| `DUPLICATE_TX` | `-32041` | yes | no | `duplicateTransaction` smoke case |
| `UNKNOWN_BLOCK` | `-32004` | yes | no | `block_get` not-found path |
| `UNKNOWN_TX` | `-32004` | yes | no | `transaction_get` or `receipt_get` tx not-found path |
| `UNKNOWN_ACCOUNT` | `-32004` | yes | no | `account_get` or `balance_get` not-found path |
| `UNKNOWN_TOKEN` | `-32004` | yes | no | `token_get` not-found path |
| `UNKNOWN_POOL` | `-32004` | yes | no | `pool_get` not-found path |
| `BRIDGE_REPLAY` | `-32041` | yes | no | `bridge_observation_submit` duplicate replay-key path |
| `LIVE_RUNTIME_UNAVAILABLE` | `-32042` | yes | yes | available constructor; degraded runtime is represented in `sync_status` provenance |
| `STORAGE_UNAVAILABLE` | `-32043` | yes | yes | available constructor; degraded storage is represented in `responseProvenance` |
| `UNSAFE_SECRET_DETECTED` | `-32040` | no | no | secret-shaped transaction, bridge intake, and raw response tests |

Smoke expected error cases:

- `invalidSignature` -> `BAD_SIGNATURE`
- `duplicateTransaction` -> `DUPLICATE_TX`
- `wrongChain` -> `WRONG_CHAIN_ID`
- `staleNonce` -> `STALE_NONCE`

Unit test error cases:

- malformed request and bad params;
- unknown method;
- unsigned transaction;
- secret-shaped intake and response material;
- secret-shaped bridge/pilot-adjacent material.
