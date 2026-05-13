# No-Value Local Appchain Prototype

Date: 2026-05-13

## Status

Accepted

## Context

FlowMemory needs a runnable local execution environment that can model appchain-style state transitions before any real Base Appchain or sovereign L1 work. Existing research already recommends Base-first, appchain-later, and sovereign-L1-last. The next useful step is an executable prototype that can produce deterministic state roots, block hashes, handoff fixtures, and Base settlement anchor placeholders.

The prototype must remain honest: no production consensus, no tokenomics, no validator economics, no mainnet deployment, no bridge security claims, and no full trustlessness claims.

## Decision

Build the local prototype as a simple custom Rust devnet under `crates/flowmemory-devnet`.

The devnet uses:

- Deterministic genesis.
- Local JSON persistence.
- Canonical JSON plus Keccak-256 for transaction ids, state roots, block hashes, and anchor ids.
- Gasless no-value transaction processing.
- A deterministic block builder.
- Fixture import/export commands for indexer, verifier, and dashboard handoff.

The prototype intentionally does not implement consensus. It is a local execution model for FlowMemory state transitions and future appchain criteria.

## Alternatives Considered

### TypeScript Devnet

Rejected for this phase because the long-term chain/node path is more likely to benefit from Rust types, Rust tests, and Rust binary distribution.

### OP Stack Or Base Appchain Devnet

Deferred. It is the right category for a later no-value appchain prototype, but it is too heavy before FlowMemory's state model, receipt schema, report schema, and Base anchor shape are stable.

### Sovereign L1

Rejected. The project has not met the criteria for independent consensus, validator operations, data availability, bridge security, or governance.

## Consequences

This gives FlowMemory a runnable local prototype that can be tested today:

- Developers can run `cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- demo`.
- Tests prove deterministic roots and block hashes.
- Invalid transactions are rejected without mutating state.
- Handoff fixtures can be exported for future indexer/verifier/dashboard work.

The tradeoff is that this is not an EVM, not a rollup, and not a production node. A later framework-selection issue must choose the first no-value appchain framework before real appchain prototyping.

## Follow-Ups

- Use issue #50 to select the no-value appchain prototype framework.
- Use issue #36 to refine Base settlement anchor fields with crypto/security review.
- Use issue #51 to turn generated handoff outputs into indexer/verifier fixture tests.
- Use issue #37 to refine hardware observer requirements.
- Use issue #41 before any bridge, DA, or value-bearing claim.
