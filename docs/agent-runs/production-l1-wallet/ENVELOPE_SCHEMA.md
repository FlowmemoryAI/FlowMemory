# Envelope Schema

The human-facing wallet output is `flowchain.wallet_signed_envelope.v0`.

Required public fields:

- `version`: current value `0`.
- `txId`: deterministic transaction id, equal to the inner local envelope id.
- `chainId`: local/private chain binding.
- `payloadType`: document schema, such as `flowchain.product_transfer.v0`.
- `payload` and `tx`: the signed payload body. `tx` is present so the existing control-plane `transaction_submit` method can consume the envelope.
- `signerAddress`: local FlowChain account address, derived from the public key.
- `signer`: public signer id, signer key id, role, public key, public key reference, and key scheme.
- `nonce`: account/envelope nonce.
- `fee`: local V0 support flag. Fees are not supported yet, so the amount is `0`.
- `validity`: issuance time plus expiry support flag. Expiry is not part of the current local transaction hash unless explicitly supplied.
- `signature`: secp256k1 signature from the inner local transaction envelope.
- `localEnvelope`: existing `flowchain.local_transaction_envelope.v0`.
- `verification`: signature, chain, signer, payload hash, tx id, and replay-key verification result.

Hash and signature rules:

1. Canonical JSON hash is computed over the payload body.
2. The inner local envelope hashes `chainId`, domain separator, signer id, signer key id, signer role, nonce, payload hash, object id, object type hash, and issued time.
3. The EIP-712-style digest signs the inner local envelope hash.
4. The wrapper `txId` must equal `localEnvelope.envelopeId`.
5. The wrapper `signature` must equal `localEnvelope.signature`.
6. Verification recomputes payload hash, object id, envelope id, signing digest, public-key-derived signer address, and signature validity.

Verification output:

```json
{
  "schema": "flowchain.wallet_envelope_verification.v0",
  "valid": true,
  "signatureValid": true,
  "chainIdMatch": true,
  "signerDerivedAddress": "0x70cc34b88ea98239192ca6329498fdb7bf92173206f5f7d33e97b9e09d9add9f",
  "payloadHash": "0x...",
  "transactionId": "0x...",
  "replayKey": "31337:flowchain.local-alpha.v0.local-transaction-envelope:chain:31337:<signer>:<nonce>",
  "rejectionReason": null,
  "errors": []
}
```
