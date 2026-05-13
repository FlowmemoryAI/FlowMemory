# Future ReceiptVerifier Boundary

Status: draft boundary for issue #28.

This document defines what a future `ReceiptVerifier` contract may verify after FlowMemory v0 schemas are accepted. It is not a contract implementation.

## Why Wait

`ReceiptVerifier` should wait until these schemas are accepted or superseded:

- FlowPulse observation identity
- receipt hashing
- verifier report id
- worker and verifier signature envelopes
- artifact root scheme
- storage receipt commitment format

Premature implementation risks baking in the wrong observation identity or replay domain.

## What A v0 Contract Could Verify

A future contract can safely verify compact, already-derived inputs:

- `observationId` hash recomputation from supplied chain/log metadata
- `eventArgsHash` recomputation from supplied FlowPulse args
- `receiptHash` recomputation from supplied observation and commitment fields
- `artifactRoot` envelope hash recomputation
- Merkle proof verification for accepted root schemes
- `reportId` recomputation from supplied report fields
- EIP-712 digest construction for worker or verifier signatures
- secp256k1 signer recovery, if key registry policy exists

## What A v0 Contract Must Not Claim

A future contract must not claim to verify:

- that `txHash`, `transactionIndex`, or `logIndex` were known during FlowPulse emission
- that a supplied receipt/log is canonical without an accepted chain proof or trusted oracle path
- that off-chain artifact bytes are available forever
- that a URI is short, private, resolvable, or honest
- that a verifier attestation is a trustless proof
- that model output or worker behavior is correct
- that a storage provider will satisfy future retrieval requests

## Required Inputs

Any future adapter should make its trust boundary explicit by accepting already-derived fields:

- `chainId`
- `emittingContract`
- `blockNumber`
- `blockHash`
- `txHash`
- `transactionIndex`
- `logIndex`
- `eventSignature`
- `pulseId`
- `rootfieldId`
- `eventArgsHash`
- `receiptHash`
- `reportId`

The caller, indexer, oracle, or proof system remains responsible for establishing that those fields are canonical.

## Implementation Prerequisites

Before adding Solidity beyond pure helpers:

- accept or revise `crypto/FLOWMEMORY_CRYPTO_SPEC.md`
- automate `crypto/test-vectors/flowpulse-observation-v0.json` validation
- define key registry and verifier set root governance
- decide whether on-chain verification is advisory, challenge evidence, or state-changing
- document gas limits for Merkle verification and signature recovery
- add focused tests for every accepted hash helper

## MVP Recommendation

Keep `ReceiptVerifier` out of production contracts for now. Add pure helper libraries in `contracts/shared/` only after schemas stabilize, then add tests against the JSON vectors. Treat any on-chain adapter as an evidence checker, not as proof of full trustlessness.
