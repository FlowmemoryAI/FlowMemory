# API Surface

The existing `services/control-plane/` service remains the only API service. All private/local L1-shaped capabilities are JSON-RPC 2.0 methods on `/rpc`; browser-safe HTTP mirrors are limited to existing health, state, explorer, product-flow, bridge-observation, and pilot routes.

## Schema Catalog

Published schema catalog:

```text
schemas/flowmemory/control-plane-production-l1.schema.json
```

The catalog lists every method, request schema, response schema, and result schema. The complete endpoint matrix with source component and smoke coverage is in `docs/agent-runs/production-l1-rpc/ENDPOINT_MATRIX.md`.

## Source Components

| Component | Paths | Provenance values |
| --- | --- | --- |
| Runtime | `devnet/local/state.json`, `devnet/local/launch-v0-state.json`, `fixtures/launch-core/generated/devnet/state.json` | `live`, `imported`, `deterministic_fixture`, `unavailable` |
| Storage/handoff | `fixtures/launch-core/generated/devnet/control-plane-handoff.json` | `imported`, `deterministic_fixture`, `unavailable` |
| Indexer | `services/indexer/out/indexer-state.json` or in-memory fixture recovery | `imported`, `deterministic_fixture` |
| Verifier | `services/verifier/out/reports.json` or in-memory fixture recovery | `imported`, `deterministic_fixture` |
| Bridge | `services/bridge-relayer/out/bridge-observation.json`, `fixtures/bridge/local-runtime-bridge-handoff.json`, bridge intake NDJSON | `imported`, `deterministic_fixture`, `unavailable` |
| Intake | `devnet/local/intake/transactions.ndjson`, `devnet/local/intake/bridge-observations.ndjson` | `local-file-intake` |

Every result includes `responseProvenance` so dashboards can show fallback state explicitly.

## Method Groups

- Status: `health`, `node_status`, `peer_list`, `sync_status`, `chain_status`, `finality_status`.
- Chain data: `block_list`, `block_get`, `transaction_list`, `transaction_get`, `transaction_submit`, `event_list`, `event_get`, `mempool_list`, `receipt_list`, `receipt_get`.
- Accounts and products: `account_list`, `account_get`, `balance_get`, `token_list`, `token_get`, `token_balance_list`, `token_balance_get`, `pool_list`, `pool_get`, `lp_position_list`, `lp_position_get`, `swap_list`, `swap_get`, `product_flow_status`, `faucet_event_list`, `wallet_metadata_list`, `wallet_metadata_get`.
- Flow Memory: `rootfield_list`, `rootfield_get`, `agent_list`, `agent_get`, `model_list`, `model_get`, `work_receipt_list`, `work_receipt_get`, `artifact_get`, `artifact_availability_list`, `artifact_availability_get`, `verifier_module_list`, `verifier_module_get`, `verifier_report_list`, `verifier_report_get`, `memory_cell_list`, `memory_cell_get`, `challenge_list`, `challenge_get`, `finality_list`, `finality_get`, `provenance_get`, `raw_json_get`.
- Bridge: `bridge_config_get`, `bridge_status`, `bridge_observation_list`, `bridge_observation_get`, `bridge_observation_submit`, `bridge_deposit_list`, `bridge_deposit_get`, `bridge_credit_list`, `bridge_credit_get`, `withdrawal_intent_list`, `withdrawal_intent_get`, `release_evidence_list`, `release_evidence_get`, `replay_rejection_list`, `replay_rejection_get`, `withdrawal_list`, `withdrawal_get`.
- Pilot compatibility: `pilot_status`, `pilot_deposit_observation_list`, `pilot_credit_list`, `pilot_withdrawal_intent_list`, `pilot_release_evidence_list`, `pilot_cap_status`, `pilot_pause_status`, `pilot_retry_status`, `pilot_emergency_status`.
