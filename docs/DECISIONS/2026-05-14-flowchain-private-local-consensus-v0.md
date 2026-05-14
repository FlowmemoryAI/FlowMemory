# FlowChain Private/Local Consensus V0

Date: 2026-05-14

## Status

Accepted for private/local runtime implementation.

## Context

The Rust devnet previously produced deterministic local blocks without validator
identity, fork-choice evidence, or chain-finality receipts. The next
private/local L1 package needs real local authority identity and deterministic
block validation without claiming public permissionless validator readiness.

## Decision

FlowChain private/local consensus V0 uses a genesis authority set with one
dashboard-safe public validator identity:

- `validator:local-private:alpha`
- role metadata: `validator`, `sequencer`, `proposer`, `finality-signer`
- consensus key reference only; no secret material in state or handoff output
- explicit separation from user wallet keys and bridge release keys

Blocks include chain id, genesis hash, authority-set id, proposer id,
transaction root, receipt root, event root, state root, a local authority proof,
and block hash. Validation rejects wrong chain id, wrong genesis hash, wrong
parent, wrong height, timestamp bounds, invalid proposer, root mismatch,
duplicate transaction ids, and block-hash/proof mismatch.

Fork choice chooses highest valid height, then lexicographically lowest block
hash as a deterministic tie-breaker. Invalid branches and valid orphaned
branches produce machine-readable fork evidence. Duplicate proposals at the same
height by the same proposer produce misbehavior evidence.

Finality is immediate for validated canonical blocks in the single-authority
private/local profile. Each finalized block produces a chain finality receipt
and certificate. Export/import preserves finalized height, finalized hash, and
finalized state root.

Bridge replay keys are recorded as local no-value replay guards only. A bridge
credit or release consumer must compare the containing block height with the
consensus finalized height before treating that local record as final.

## Consequences

- The local runtime now has a production-grade private/local authority model for
  second-computer validation.
- Public validators, staking, slashing, public network consensus, production
  bridge custody, and tokenomics remain out of scope.
- Control-plane and dashboard consumers can read consensus and finality fields
  from generated runtime output without reading secret material.

