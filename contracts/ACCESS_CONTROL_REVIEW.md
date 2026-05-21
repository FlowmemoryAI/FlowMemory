# Contracts Access-Control Review

Status: V0 launch hardening review.

## Summary

The current contracts use simple ownership or self-registration patterns. They do not implement staking, slashing, token custody, rewards, production governance, verifier consensus, or upgrade admin controls.

They also do not enforce cross-contract dependency existence. For example, a work receipt or verifier report may reference a nonzero `rootfieldId` or `receiptId` that another contract has not registered. That is intentional for this optional V0 event spine: indexers and verifiers reconcile dependencies off-chain from receipts, logs, fixtures, and reports.

No current contract exposes bridge finality or a challenge lifecycle. `REORGED` is an allowed verifier-report status for local/test reconciliation, not a Solidity finality proof, production bridge state, or challenge-resolution mechanism.

## BaseBridgeLockbox

Owner model: one constructor `initialOwner` controls the lockbox configuration.

Owner-gated functions:

- `transferOwnership`
- `setReleaseAuthority`
- `setPaused`
- `configureToken`

Release-authority-gated functions:

- `releaseNative`
- `releaseERC20`

Current protections:

- zero owner and zero release authority rejected
- only allowlisted tokens can be deposited
- allowed tokens require a nonzero per-deposit cap
- optional per-asset total cap prevents total locked accounting from exceeding
  the configured pilot cap
- total cap cannot be lowered below currently locked amount
- pause blocks new deposits
- releases require explicit release authority, a recorded deposit, matching
  token, available amount, and nonzero evidence hash
- release replay is blocked for identical deposit, recipient, token, amount, and
  evidence hash
- direct native transfers outside `lockNative` are rejected

Launch risk to watch:

- pause intentionally does not block releases, so pilot operators can unwind
  deposits while deposits are stopped.
- release authority is a trusted pilot role, not a decentralized validator set
  or finality proof.
- nonstandard ERC-20 behavior such as transfer fees, rebasing, or callbacks is
  outside the pilot safety claim.
- native releases use Solidity `transfer`; gas-heavy smart-contract recipients
  can fail and should not be used for pilot recovery without separate review.
- a compromised owner or release authority can misuse the POC; emergency
  response is limited to pause, cap changes, allowlist disablement, authority
  rotation, and explicit release/recovery calls.

## FlowChainSettlementSpine

Owner model: one constructor `initialOwner` controls submitter authorization.

Owner-gated functions:

- `transferOwnership`
- `setSubmitterAuthorization`

Submitter-gated functions:

- `commitObject` requires an authorized submitter.

Current protections:

- zero owner rejected
- zero submitter rejected for authorization changes
- owner is authorized as the first submitter
- unauthorized submitters cannot commit objects
- zero object type, object id, rootfield id, and commitment rejected
- duplicate object ids rejected
- committed object records can be read by object id

Launch risk to watch:

- submitter authorization is a coordination control, not proof of object
  correctness.
- unknown object types are allowed so local experiments can proceed, but
  downstream agents should treat unknown types as unsupported until documented.
- events omit `txHash`, `logIndex`, receipt status, and finality status;
  indexers derive locator fields after receipts and logs exist.

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


## Agent Bonds Production-Shaped Controls

Contracts:

- `AgentBondManager`
- `TaskBondEscrow`
- `AgentStakeRegistry`
- `TaskPolicyRegistry`
- `AgentBondTimelockedMultisig`

Owner model:

- two-step ownership for escrow, stake, policy, and manager controls
- optional owner-path transfer to `AgentBondTimelockedMultisig`
- separate `pauseGuardian` for immediate stop of new exposure

Current protections:

- capped pilot controls for requester, agent, verifier, payout, open exposure, and open task count
- independent verifier confirmation can be required by policy before settlement
- evidence availability commitment and retention window are required before report acceptance
- challenge bond is isolated from task payout and task bond
- settlement uses pull-withdrawals and explicit slash splits

Launch risk to watch:

- challenged outcomes still depend on explicit `resolutionAuthority`
- owner and guardian roles are safer than the earlier direct-EOA model but still require real operator separation and key management in deployment
- allowlists and caps are governance controls, not decentralization guarantees

## Required Review Before Expanding

Before adding rewards, staking, slashing, custody, dynamic fees, production hook permissions, or appchain/L1 settlement:

- create a threat model issue
- require a separate review worktree
- require event tests for every state transition
- require static analysis with Slither
- update this access-control review
