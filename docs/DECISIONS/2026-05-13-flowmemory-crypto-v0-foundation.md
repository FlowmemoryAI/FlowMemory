# FlowMemory Crypto v0 Foundation

Date: 2026-05-13

## Status

Proposed for cross-agent review; implemented as a runnable V0 package candidate.

## Context

FlowMemory now has a FlowPulse contracts foundation and open issues for canonical observation identity, verifier status vocabulary, and receipt/attestation schema vocabulary. Contracts emit `pulseId`, roots, commitments, counters, and advisory URI strings. Indexers and verifiers must derive `txHash`, `transactionIndex`, `logIndex`, and block metadata after receipts and logs exist.

## Decision

Adopt draft v0 crypto schemas under `crypto/` as the review target for:

- `pulseId`, `observationId`, and `reportId` separation
- Keccak-256 typed object hashes
- FlowPulse receipt hashing
- artifact roots and Merkle formats
- worker and verifier EIP-712 signature envelopes
- deterministic verifier reports
- replay protection and reorg handling

This is not a production protocol acceptance. It is the schema foundation for cross-agent review, package tests, and deterministic test-vector validation.

## Consequences

- Contracts should not add CursorRegistry or proof-carrying receipt logic until observation identity is accepted.
- Verifier services can target deterministic report schemas without inventing local formats.
- Artifact and storage commitments remain off-chain and challengeable.
- Verifier attestations remain signed claims, not trustless proofs.
- Future zk work can use receipt and report hashes as stable public-input candidates.

## Follow-Ups

- Review and accept or revise the v0 type strings.
- Keep the reference hash implementation and tests under `crypto/` as the conformance source for services.
- Add Solidity shared hash library only after schema review.
- Use `contracts/shared/RECEIPT_VERIFIER_BOUNDARY.md` as the guardrail for issue #28 before adding any `ReceiptVerifier` contract.
- Decide URI policy separately.
- Define verifier set root and key registry governance.
