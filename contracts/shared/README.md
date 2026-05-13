# Shared Contract Crypto Formats

Status: placeholder for future implementation.

This folder is reserved for shared Solidity hash helpers once the v0 crypto schemas are reviewed.

Do not add production contract logic here until:

- `crypto/FLOWMEMORY_CRYPTO_SPEC.md` is accepted or revised
- `crypto/TEST_VECTORS.md` has automated checks
- `docs/DECISIONS/2026-05-13-flowmemory-crypto-v0-foundation.md` is accepted or superseded

Expected future contents:

- type hash constants
- pure hash functions for observation ids, receipts, artifact roots, storage commitments, reports, and signatures
- Merkle proof verification for accepted root schemes
- Solidity tests against the JSON vectors

See `RECEIPT_VERIFIER_BOUNDARY.md` for the draft boundary of a future `ReceiptVerifier` adapter.
