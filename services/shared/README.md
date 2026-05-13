# FlowMemory Shared V0

This package contains dependency-free shared helpers for the local indexer/verifier V0 package. It is pure TypeScript: no live RPC, no database, no secrets, and no production runtime.

## Commands

From the repository root:

```powershell
npm test --prefix services/shared
npm test
```

## Shared Helpers

The package provides:

- FlowPulse v0 event signature and `topic0` constants.
- V0 verifier report status constants.
- Narrow ABI encoding/decoding helpers used by fixtures.
- EVM Keccak-256.
- Canonical JSON serialization.
- `deriveObservationId`.
- `deriveSourceSetId`.
- `deriveCursorId`.
- `deriveReportId`.
- `parseFlowPulseLogFixture`.

The helpers are intentionally narrow. They support the fixture-first package without becoming a full ABI, RPC, or crypto framework.

## Identity Terms

`pulseId`:

Contract-emitted FlowPulse id. It is decoded from the event and can link protocol actions, but it is not enough to identify a receipt/log occurrence.

`observationId`:

Indexer-derived id:

```text
keccak256(abi.encode(
  "flowmemory.flowpulse.observation.v0",
  chainId,
  sourceContract,
  txHash,
  logIndex
))
```

`cursorId`:

Indexer-derived scan cursor id:

```text
keccak256(abi.encode(
  "flowmemory.indexer.cursor.v0",
  chainId,
  sourceSetId,
  blockNumber,
  blockHash,
  transactionIndex,
  logIndex
))
```

`reportId`:

Verifier-derived digest:

```text
keccak256(canonical_json(reportCore))
```

## Canonicalization Rules

- Hex strings are lower-case and `0x` prefixed.
- Addresses are lower-case 20-byte hex strings.
- `bytes32` values are lower-case 32-byte hex strings.
- Integer-like EVM fields are decimal strings in JSON.
- Canonical JSON sorts object keys lexicographically.
- Arrays preserve documented order.
- Report digests exclude wall-clock timestamps, local paths, signatures, and operator notes.

## Crypto Boundary

The current package includes local Keccak and ABI helpers so the service package can run without expanding scope into the crypto implementation. Future integration with a dedicated crypto package should happen through a narrow adapter and compatibility fixtures.

See [CRYPTO_BOUNDARY.md](./CRYPTO_BOUNDARY.md).

## Boundaries

- No live RPC.
- No arbitrary artifact fetching.
- No database.
- No deployment config.
- No secrets in env files.
- No tokenomics or verifier economics.

See [docs/INDEXER_VERIFIER_MVP.md](../../docs/INDEXER_VERIFIER_MVP.md) for the full pipeline.
