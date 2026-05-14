# Production L1 Crypto Foundation

Date: 2026-05-14

## Status

Accepted for the private/local FlowChain production-L1-shaped crypto package.

## Context

FlowChain runtime, control-plane, and wallet agents need one canonical crypto
surface for public identity, transaction signing, replay protection, bridge
source-event identity, and validator/finality objects. The existing crypto
package already had local-alpha envelopes, wallet helpers, product-testnet
vectors, and schema fixtures, so the new work must extend those surfaces rather
than creating a second wallet or transaction format.

## Decision

The existing `flowchain.local_transaction_envelope.v0` remains the canonical
transaction envelope. Production-L1-shaped signing completes that envelope with:

- `schemaVersion`
- `networkProfile`
- `payloadType`
- expiration
- local execution cost
- fee policy
- signature algorithm
- transaction ID
- canonical public identity metadata

Legacy local-alpha envelopes without those fields remain compatibility fixtures.
Runtime/API agents must use the stricter runtime validator and require the
completed production-L1 fields.

Runtime-safe verification is exported from:

```js
import { verifyFlowchainEnvelope } from "@flowmemory/crypto/runtime-validation";
```

That subpath imports validation, identity, hashing, and signature verification
only. It must not import wallet vault creation, unlock, rotation, or signing
code.

## Consequences

- Wallet, runtime, and control-plane agents can use one envelope schema path:
  `schemas/flowmemory/local-transaction-envelope.schema.json`.
- The canonical production-L1 vector fixture is
  `crypto/fixtures/production-l1-vectors.json`.
- `npm run validate:production-l1-crypto --prefix crypto` proves identity,
  hash helper, positive transaction family, exact negative failure, runtime
  import-boundary, and no-secret expectations.
- Bridge observation IDs are derived from receipt/log facts, including source
  chain, lockbox, token, depositor, recipient, amount, tx hash, log index, block
  number, and event nonce.
- Bridge credit IDs are derived from observation ID, local recipient, local
  chain ID, and credit amount.

## Scope Boundaries

This decision does not approve production deployment, public validators,
production bridge operation, tokenomics, audited custody, hardware wallet
support, or production key recovery. The package is a deterministic
local/private crypto foundation and validation contract for other agents.

## Follow-Ups

- Runtime and control-plane agents should import the runtime validation subpath
  and reject envelopes that do not include the completed production-L1 fields.
- Rust runtime agents should port the canonical JSON and typed-hash vectors from
  `crypto/fixtures/production-l1-vectors.json` before accepting live runtime
  submissions.
