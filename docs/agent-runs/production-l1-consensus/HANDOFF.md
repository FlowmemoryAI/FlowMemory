# Production L1 Consensus Handoff

## Runtime Output

Default runtime files under `devnet/local/`:

- `state.json`
- `genesis-config.json`
- `operator-key-references.json`
- `validator-set.json`
- `consensus-state.json`
- `finality-status.json`

Consensus smoke output:

- `devnet/local/consensus-smoke/consensus-report.json`
- `devnet/local/consensus-smoke/finality-proof.json`
- `devnet/local/consensus-smoke/fork-choice-proof.json`
- `devnet/local/consensus-smoke/state-snapshot.json`
- `devnet/local/consensus-smoke/handoff/control-plane-handoff.json`

## Finality Fields

Control-plane and dashboard handoffs include:

- `consensus.state.finalizedHeight`
- `consensus.state.finalizedHash`
- `consensus.state.finalizedStateRoot`
- `finality.finalizedHeight`
- `finality.finalizedHash`
- `finality.finalizedStateRoot`
- `chainFinalityReceipts`
- `consensusStateRoot`

## Validation Rules

Blocks validate chain id, genesis hash, authority-set id, height, parent hash,
timestamp bounds, proposer role/schedule, duplicate transaction ids, tx root,
receipt root, event root, state root for proposals, authority proof, block hash,
and finalized-height conflicts.

## RPC/Dashboard Fields

RPC/dashboard agents should surface:

- validator set id and validator public metadata
- canonical height and canonical head hash
- finalized height, finalized hash, finalized state root
- latest chain-finality receipt id
- fork evidence count and latest rejected fork records
- misbehavior evidence count and latest records
- bridge replay key finality by comparing `firstSeenBlock` to finalized height

This is private/local authority-set consensus. It is not public validator
readiness.

