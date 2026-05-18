# Live L1 Crypto Enforcement

Date: 2026-05-14

## Status

PASS

## What Changed

- Added a live-L1 crypto verification gate at `npm run flowchain:crypto:live-l1:verify`.
- Generated the machine-readable enforcement matrix at `devnet/local/live-l1-crypto/crypto-enforcement-matrix.json`.
- Generated the verification report at `devnet/local/live-l1-crypto/live-l1-crypto-verify-report.json`.
- Wired control-plane `transaction_submit` to require `flowchain.local_transaction_envelope.v0` document/envelope pairs and reject missing envelopes, wrong chain IDs, wrong domains, duplicate nonces, duplicate transaction IDs, mutated payloads, malformed public keys, and wrong signer roles through the crypto runtime validator.
- Wired bridge observation intake to recompute source-event replay keys and observation IDs from receipt/log/deposit facts, reject duplicate bridge replay keys, and enforce Base 8453 pilot guardrails for live pilot mode.
- Wired bridge release evidence generation to use crypto package bridge evidence hashes.
- Added root commands for wallet e2e, wallet transfer e2e, live-L1 crypto verification, and no-secret scanning.
- Kept the crypto implementation inside the existing `crypto/` package; no second crypto package was introduced.

## Inventory

The live-L1-required inventory is tracked in the matrix with `implemented`, `enforcedByRuntime`, `tested`, `liveL1Required`, and `blockedReason` fields:

- canonical JSON hashing
- Keccak typed IDs
- Merkle/state roots
- block hashes
- transaction IDs
- secp256k1 signatures and public-key metadata
- local transaction envelopes
- wallet public metadata
- bridge replay keys
- bridge evidence hashes
- finality receipt IDs
- validator/operator key references

All required entries are marked implemented, runtime-enforced, tested, live-L1-required, and unblocked in the generated matrix.

## Why It Changed

Crypto objects that were previously proven by fixtures and vector validation now gate state-changing runtime intake. Live bridge, wallet, transfer, finality, and control-plane paths fail closed when envelope, domain, chain ID, nonce, role, replay, hash, or public metadata checks fail.

## Tests And Checks

- `npm test --prefix services/control-plane`
- `npm test --prefix crypto`
- `npm run validate:vectors --prefix crypto`
- `npm run wallet:product-smoke --prefix crypto`
- `npm run flowchain:wallet:e2e`
- `npm run flowchain:wallet:transfer:e2e`
- `npm run flowchain:crypto:live-l1:verify`
- `npm run flowchain:no-secret:scan`
- `git diff --check`

## Reports

- `devnet/local/live-l1-crypto/crypto-enforcement-matrix.json`
- `devnet/local/live-l1-crypto/live-l1-crypto-verify-report.json`
- `devnet/local/live-l1-crypto/wallet-transfer-e2e-report.json`

## Risks, Assumptions, And Follow-Ups

- This is a local/private FlowChain live-L1 enforcement boundary, not audited cryptography and not approval for production deployment.
- Future proof systems, production custody, public validators, and hardware wallet support remain out of scope unless separately implemented and gated.
- The requested protocol specs were not present in this checkout; they were read from the sibling HQ worktree for context before implementation.
- Root `devnet/local/` reports are generated runtime artifacts and may be ignored by Git depending on local ignore rules.
