# Crypto Integration Boundary

This document advances issue #47 inside the current service-only scope. It does not edit the crypto package or define a production cryptography API.

## Current V0 Position

The local indexer/verifier package includes narrow helpers for:

- EVM Keccak-256.
- ABI encoding of identity preimages.
- ABI decoding of the FlowPulse fixture event.
- Hex, address, and `bytes32` normalization.

These helpers exist so the fixture package can run without live RPC, external dependencies, or changes outside `services/`.

## Boundary Rule

Service code should depend on a small crypto adapter surface, not directly on future crypto internals.

Expected future adapter functions:

- `keccak256Hex(bytes): 0x...`
- `encodeObservationIdentity(fields): Uint8Array`
- `encodeCursorIdentity(fields): Uint8Array`
- `encodeReportDigestInput(reportCore): Uint8Array | string`
- `normalizeAddress(value): 0x...`
- `normalizeBytes32(value): 0x...`

The adapter must preserve current fixture outputs unless an explicit migration decision changes identities.

## Compatibility Fixtures

Before replacing local helpers with a dedicated crypto package, add compatibility tests for:

- Known Keccak vectors.
- `observationId` fixture output.
- `cursorId` fixture output.
- `reportId` fixture output.
- Rootfield registration commitment.
- Root commitment commitment.

These tests should run without RPC, secrets, production databases, or artifact fetching.

## Non-Goals

- No custom cryptographic primitives.
- No signature or attestation scheme in V0.
- No proof network.
- No edits to the crypto implementation from this service package task.
- No hardcoded private keys, API keys, seed phrases, or RPC secrets.

## Migration Note

When a dedicated crypto package is ready, services should switch through an adapter module and keep the current fixture outputs as regression tests. If any identity changes, record a new durable decision before changing code.
