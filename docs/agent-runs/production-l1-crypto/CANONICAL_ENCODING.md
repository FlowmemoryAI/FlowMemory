# Canonical Encoding

Production-L1-shaped FlowChain signing extends the existing
`flowchain.local_transaction_envelope.v0` envelope. It does not introduce a
second transaction envelope.

## Payload Encoding

- Payload documents are canonical JSON through `canonicalJson()` in
  `crypto/src/encoding.js`.
- Object keys are sorted recursively.
- Hex strings are normalized to lowercase before hashing.
- Non-finite numbers are rejected.
- Payload hash is `canonicalJsonHash(document)`.

## Signed Preimage

Completed production-L1 envelopes use
`TYPE_STRINGS.localTransactionEnvelopeProductionL1V0` and the existing typed
Keccak ABI encoding helper. The signed digest includes:

- schema version
- chain ID
- network profile hash
- domain separator
- signer account ID
- signer key ID
- signer role code
- nonce
- payload type hash
- canonical payload hash
- object ID
- object type hash
- issued timestamp fixed at signing time
- expiration timestamp fixed at signing time
- local execution cost hash
- fee policy hash
- signature algorithm hash

The preimage does not include local file paths, process IDs, command paths, or
verification-time timestamps.

## Compatibility

Legacy local-alpha envelopes are still accepted by compatibility validators.
`verifyFlowchainEnvelope()` and `validate:production-l1-crypto` require the
completed production-L1 fields.
