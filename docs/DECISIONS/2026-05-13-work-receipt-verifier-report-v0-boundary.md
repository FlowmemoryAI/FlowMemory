# Work Receipt And Verifier Report v0 Boundary

Date: 2026-05-13

## Status

Accepted

## Context

FlowMemory needs minimal contract surfaces for compact work receipts and verifier reports. These contracts should support local testing and indexer integration without pretending to provide a complete verifier network.

## Decision

WorkReceiptRegistry v0 stores compact work receipt commitments from owner-authorized workers. A receipt binds:

- `rootfieldId`
- work lane
- subject
- input and output roots
- artifact commitment
- optional parent receipt id

VerifierReportRegistry v0 stores compact verifier report commitments from owner-authorized verifiers. A report binds:

- rootfield id or receipt id
- report status
- report digest
- evidence commitment
- verifier address

Both registries emit advisory URI strings as on-chain log data only. URI length, content, format, and resolver behavior are not enforced.

## Work Lanes

The initial lanes are:

- `MEMORY_REFRESH`
- `FAILURE_DISCOVERY`
- `FAILURE_REPAIR`
- `MANIFOLD_DISCOVERY`
- `STEERING_VALIDATION`
- `CHECKPOINT_STORAGE`
- `GPU_TRAINING`
- `EVAL_COUNTEREXAMPLE`

The lane value is a categorization commitment. It does not prove work quality, priority, payment, or scheduler correctness.

## Report Statuses

VerifierReportRegistry v0 accepts `VALID`, `INVALID`, `UNRESOLVED`, `UNSUPPORTED`, and `REORGED`. These are verifier-submitted claims, not on-chain proof outcomes. The contract does not cryptographically verify receipts, artifacts, model outputs, or chain reorgs.

## Authorization Semantics

V0 uses local owner-controlled allowlists for workers and verifiers. This is intentionally simple and reviewable. It is not decentralized governance, staking, Sybil resistance, or a production verifier network.

## Intentionally Excluded

- Tokenomics
- Dynamic fees
- Rewards
- Slashing
- External protocol calls
- On-chain receipt verification
- Raw artifact or evidence storage
- Production hook integration
- Mainnet deployment assumptions
- Production audit claims

## Future Options

Future versions should decide whether authorization connects to WorkerRegistry and VerifierRegistry, whether report evidence moves to CID/hash-only fields, whether work receipts emit FlowPulse directly, and whether verifier adapters need stronger proof systems or signature formats.
