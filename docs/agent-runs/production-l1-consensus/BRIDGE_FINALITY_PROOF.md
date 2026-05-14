# Bridge Finality Proof

## Implemented Boundary

This pass does not implement production bridge custody or public bridge
security. It implements a local replay guard transaction:

```text
RecordBridgeReplayKey
```

The replay key is stored in devnet state and included in deterministic map roots.
Duplicate replay keys are rejected in later blocks and remain rejected after
restart/export/import because the replay-key map is persisted.

## Finality Rule For Bridge Consumers

Bridge credits are not final merely because a replay key exists. A bridge credit
consumer must treat a local bridge object as final only when:

```text
replayKey.firstSeenBlock <= consensusState.finalizedHeight
```

Release evidence must reference a finalized withdrawal intent in a future bridge
implementation, or explicitly state local-private pilot semantics. Consensus
keys do not sign bridge release instructions.

Rust coverage:

- `consensus_bridge_replay_rejection_survives_finality_and_restart_shape`

