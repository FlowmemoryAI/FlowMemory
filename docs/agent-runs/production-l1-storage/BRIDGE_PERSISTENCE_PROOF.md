# Bridge Persistence Proof

## Persisted Bridge State

The runtime now persists:

- `bridgeObservations`
- `bridgeCredits`
- `withdrawalIntents`
- `releaseEvidence`
- `consumedReplayKeys`

Bridge transaction payloads:

- `RecordBridgeObservation`
- `ApplyBridgeCredit`
- `CreateWithdrawalIntent`
- `RecordReleaseEvidence`

## Durable Files

- `objects/bridge-observations.json`
- `objects/bridge-credits.json`
- `objects/withdrawal-intents.json`
- `objects/release-evidence.json`
- `objects/consumed-replay-keys.json`
- `indexes/storage-indexes.json`

## Proof

`npm run flowchain:storage:e2e` passed with:

- Bridge observation entries: `1`
- Bridge credit entries: `1`
- Replay key entries: `1`
- Bridge credit preserved: `true`
- Replay key preserved: `true`

Rust tests also verify:

- Export/import preserves bridge observations, bridge credits, withdrawal intents, and replay keys.
- Applying a bridge credit consumes the observation replay key exactly once.
- Bridge state contributes to deterministic state roots and map roots.

The export contains public evidence references only. It excludes local wallet vaults, env files, network endpoints, signing secrets, recovery phrases, and API credential/callback material.
