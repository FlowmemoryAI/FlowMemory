# FlowChain Control Plane V0

This package exposes a local JSON-RPC 2.0 control-plane for FlowMemory and FlowChain fixture data. It is fixture-first, deterministic, and read-only.

It is not a production RPC endpoint, hosted service, wallet, sequencer, verifier network, token system, or production chain API.

## Commands

From the repository root:

```powershell
npm run control-plane:demo
npm run control-plane:test
npm run control-plane:smoke
npm run control-plane:serve -- --host 127.0.0.1 --port 8675
```

The demo and tests require no secrets, RPC URLs, wallets, or production services.

## Methods

The dispatcher supports:

- `health`
- `chain_status`
- `devnet_state`
- `block_get`
- `block_list`
- `transaction_get`
- `transaction_list`
- `rootfield_get`
- `rootfield_list`
- `artifact_get`
- `artifact_availability_get`
- `artifact_availability_list`
- `receipt_get`
- `receipt_list`
- `work_receipt_get`
- `work_receipt_list`
- `verifier_module_get`
- `verifier_module_list`
- `verifier_report_get`
- `verifier_report_list`
- `memory_cell_get`
- `memory_cell_list`
- `agent_get`
- `agent_list`
- `model_get`
- `model_list`
- `challenge_get`
- `challenge_list`
- `finality_get`
- `finality_list`
- `provenance_get`
- `raw_json_get`

The API contract is documented in [docs/FLOWCHAIN_CONTROL_PLANE_API.md](../../docs/FLOWCHAIN_CONTROL_PLANE_API.md).

## Data Sources

The loader reads committed deterministic outputs first:

- `fixtures/launch-core/flowmemory-launch-v0.json`
- `fixtures/launch-core/generated/devnet/state.json`
- `fixtures/launch-core/generated/devnet/indexer-handoff.json`
- `fixtures/launch-core/generated/devnet/verifier-handoff.json`
- `fixtures/launch-core/generated/devnet/control-plane-handoff.json`
- `services/indexer/out/indexer-state.json`
- `services/verifier/out/reports.json`
- `services/verifier/fixtures/artifacts.json`
- `fixtures/handoff/sample-txs.json`

If the launch-core fixture is missing, the loader rebuilds the in-memory view from indexer/verifier outputs or the raw fixture receipts and artifact resolver. It does not fetch from live RPC or write production state.

`npm run control-plane:smoke` runs an in-process JSON-RPC client over the complete local lifecycle surface: health, chain status, blocks, transactions, rootfields, agents, models, work receipts, artifact availability, verifier modules, verifier reports, memory cells, challenges, finality, provenance, and raw JSON.
