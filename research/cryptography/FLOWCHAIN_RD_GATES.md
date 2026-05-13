# FlowChain Cryptography RD Gates

Status: boundary document for Local Alpha.

The current `crypto/` package defines Keccak typed IDs, schemas, fixtures, and
local signature-envelope validation. It does not implement production proof
systems or audited cryptography.

## Gated Tracks

| Track | Gate Before Implementation Or Claim |
| --- | --- |
| Process-Witness | Accepted public inputs, witness format, replay policy, privacy boundary, and cross-language vectors. |
| SEAL/dependency privacy | Dependency atom schema, disclosure policy, verifier checks, challenge behavior, and dashboard status vocabulary. |
| Synthetic Non-Amplification | Formal rule, fixture corpus, verifier module behavior, invalid vectors, and review decision. |
| Advanced encrypted compute | Threat model, key lifecycle, leakage policy, deterministic verifier boundary, and failure reporting. |
| GPU proofs | Proof system choice, public inputs, cost model, verifier module ID, local vectors, and reproducible proof fixtures. |
| Audited production proof systems | Named audit artifact, merged decision record, issue acceptance, verifier enforcement path, and production go/no-go record. |

## Current Boundary

- Use `crypto/fixtures/local-alpha-objects.json` for Local Alpha object and
  envelope vectors.
- Use `schemas/flowmemory/` for local/test JSON document shape.
- Treat nearby RD crates as research inputs only unless a compatibility adapter
  and matching vectors are accepted.
- Do not claim full trustlessness, production L1 readiness, storage permanence,
  model-output correctness, encrypted-compute security, GPU proof security, or
  audit coverage from the current package.
