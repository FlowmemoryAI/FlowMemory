# Bridge, DA, And Security Review Requirements

Status: research gate, no bridge implementation

The local FlowMemory devnet has no live bridge and no live Base settlement. `AnchorBatchToBasePlaceholder` only models compact anchor payloads for future review.

## Relationship To FlowChain Gates

| Gate | Status | Bridge meaning |
| --- | --- | --- |
| Local/private testnet | Local-alpha target | Bridge work is limited to no-value anchor placeholders, replay-boundary docs, and fixture checks. No asset movement. |
| Public devnet | Later research, Blocked | Public devnet may test no-value messages only after DA, replay, finality, monitoring, and emergency controls are documented. |
| Public L1/mainnet | Explicitly later, Blocked | Any value-bearing bridge requires independent bridge/security review, incident response drills, and an accepted production decision record. |

## Bridge Assumptions To Resolve Later

Before any appchain can carry value, FlowMemory must define:

- Deposit message format.
- Withdrawal message format.
- Message nonce and replay protection.
- Source chain and destination chain binding.
- Rootfield and receipt context binding.
- Withdrawal finality policy.
- Emergency pause authority and limits.
- Upgrade path and delay.
- Failed message recovery path.

## Data Availability Requirements

Before production appchain work, reviewers must be able to answer:

- Where is appchain transaction data posted?
- Can a new node reconstruct appchain state from public data?
- How long is data retained?
- What happens if data is missing?
- How does the indexer mark unavailable data?
- How does the verifier avoid claiming `verified` when data is unavailable?

Missing DA should make appchain work unresolved or invalid, not silently trusted.

## Fraud, Validity, And Proof Boundary

The local devnet does not implement:

- Fraud proofs.
- Validity proofs.
- ZK proofs.
- Permissionless fault challenges.
- Rollup withdrawal finality.

If a future prototype uses OP Stack-derived or Base Appchain infrastructure, FlowMemory must document the exact inherited proof assumptions instead of making generic rollup claims.

## Independent Review Gate

Before value moves:

- Bridge design review.
- DA review.
- Anchor schema review.
- Replay-protection review.
- Key custody review.
- Emergency pause review.
- Monitoring and incident response drill.

## No-Go Conditions

Any of these blocks value-bearing appchain work:

- Unclear withdrawal finality.
- Unclear DA source or retention.
- No replay protection.
- No emergency pause policy.
- No independent bridge/security review.
- Anchor roots cannot be reconciled by indexers.
- Verifier reports can be marked verified without available evidence.
- Appchain value requires moving raw memory, artifacts, or evidence on-chain.
