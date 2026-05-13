# Contracts Access-Control Review

Status: V0 launch hardening review.

## Summary

The current contracts use simple ownership or self-registration patterns. They do not implement staking, slashing, token custody, rewards, production governance, verifier consensus, or upgrade admin controls.

They also do not enforce cross-contract dependency existence. For example, a work receipt or verifier report may reference a nonzero `rootfieldId` or `receiptId` that another contract has not registered. That is intentional for this optional V0 event spine: indexers and verifiers reconcile dependencies off-chain from receipts, logs, fixtures, and reports.

No current contract exposes bridge finality or a challenge lifecycle. `REORGED` is an allowed verifier-report status for local/test reconciliation, not a Solidity finality proof, production bridge state, or challenge-resolution mechanism.

## RootfieldRegistry

Owner model: each `rootfieldId` has one owner.

Owner-gated functions:

- `submitRoot`
- `deactivateRootfield`
- `transferRootfieldOwnership`

Current protections:

- zero rootfield id rejected
- zero schema hash rejected
- duplicate rootfield id rejected
- zero root rejected
- zero artifact commitment rejected for root submissions
- inactive rootfield blocks root submission and transfer
- zero new owner rejected
- ownership transfer emits both a FlowPulse status event and a dedicated ownership event

Launch risk to watch:

- current ownership transfer uses `parentPulseId = bytes32(0)` by design; future versions may require explicit parent linkage.
- URI fields are advisory event data, not trusted storage pointers.

## Owner-Allowlist Registries

Contracts:

- `VerifierReportRegistry`
- `WorkReceiptRegistry`

Owner-gated functions:

- `setVerifierAuthorization`
- `setWorkerAuthorization`

Submitter-gated functions:

- `submitVerifierReport` requires an authorized verifier.
- `submitWorkReceipt` requires an authorized worker.

Current protections:

- zero worker/verifier rejected
- revoked worker/verifier authorization blocks future submissions
- duplicate report/receipt id rejected
- invalid report status rejected below and above the accepted V0 range
- invalid work lane rejected below and above the accepted V0 range
- zero target or commitment fields rejected

Launch risk to watch:

- deployer is permanent owner in V0; there is no multisig, timelock, or owner transfer.
- see `docs/OPERATIONS/V0_OPERATOR_POLICY.md` for the current canary operator policy and production gates.
- allowlists are coordination controls, not decentralized verifier consensus.

## Self-Registration Registries

Contracts:

- `WorkerRegistry`
- `VerifierRegistry`

Owner model: the registering address controls its own metadata lifecycle.

Current protections:

- duplicate registration rejected
- zero operator id rejected
- zero role rejected
- inactive records cannot update again

Launch risk to watch:

- registration does not prove work quality, correctness, identity, or stake.

## Per-Record Owner Registries

Contracts:

- `ArtifactRegistry`
- `CursorRegistry`

Owner-gated functions:

- `deprecateArtifact`
- `advanceCursor`

Current protections:

- zero ids and zero commitments rejected
- zero rootfield id rejected where a record belongs to a Rootfield namespace
- zero artifact schema hash rejected
- duplicate records rejected
- only the stored owner can mutate the record

Launch risk to watch:

- advisory URI strings are emitted as logs and are not validated content availability proofs.

## Open Submission Contracts

Contracts:

- `ReceiptVerifier`
- `WorkDebtScheduler`
- `FlowMemoryHookAdapter`

Current boundary:

- `ReceiptVerifier` accepts first-writer receipt-report commitments and does not cryptographically verify receipts. It rejects zero report ids, observation ids, rootfield ids, receipt commitments, and report hashes so local-alpha reports remain reconstructable by indexers/verifiers.
- `WorkDebtScheduler` allows any scheduler to assign work to a nonzero worker and allows scheduler or worker to mark completion.
- `FlowMemoryHookAdapter` validates nonzero inputs and emits an observation event. It also exposes a dependency-light Uniswap v4-shaped `afterSwap` callback path, but it is not a production Uniswap v4 hook deployment.

Launch risk to watch:

- open submission is acceptable for V0 commitments only if docs and demos treat outputs as untrusted until off-chain verifier reports exist.

## Required Review Before Expanding

Before adding rewards, staking, slashing, custody, dynamic fees, production hook permissions, or appchain/L1 settlement:

- create a threat model issue
- require a separate review worktree
- require event tests for every state transition
- require static analysis with Slither
- update this access-control review
