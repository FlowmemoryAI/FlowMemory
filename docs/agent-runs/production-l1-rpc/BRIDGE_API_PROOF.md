# Bridge API Proof

The bridge API loop is exposed through the existing control-plane JSON-RPC service.

## Covered Methods

- `bridge_config_get`
- `bridge_status`
- `bridge_observation_list`
- `bridge_observation_get`
- `bridge_observation_submit`
- `bridge_deposit_list`
- `bridge_deposit_get`
- `bridge_credit_list`
- `bridge_credit_get`
- `withdrawal_intent_list`
- `withdrawal_intent_get`
- `release_evidence_list`
- `release_evidence_get`
- `replay_rejection_list`
- `replay_rejection_get`
- compatibility aliases: `withdrawal_list`, `withdrawal_get`

## Smoke Evidence

`npm run control-plane:smoke` calls every method above. It submits a safe mock bridge observation with a unique replay key, then queries it back by `observationId`.

Bridge status fields:

- `readiness`
- `bridgeSource`
- `observationCount`
- `creditCount`
- `withdrawalIntentCount`
- `releaseEvidenceCount`
- `replayRejectionCount`
- `envValuesExposed: false`
- `lastError`

Bridge config fields:

- `mode`
- `productionReady: false`
- `cappedOwnerTesting: true`
- `pauseStatus`
- `pilotCaps`
- `replayProtection`
- `runtimeIntake`
- `source`

Release evidence behavior:

- If bridge runtime handoff includes release evidence, it is returned directly.
- If withdrawal intent exists but no release record exists, `release_evidence_list` returns an explicit `pending_operator_release_evidence` projection.

Replay behavior:

- Duplicate replay keys submitted to `bridge_observation_submit` are rejected with `BRIDGE_REPLAY`.
- If no duplicate exists, `replay_rejection_list` returns an explicit `idempotent_no_duplicate` row.

No bridge response exposes RPC URLs, private keys, env maps, API keys, webhooks, or vault contents.
