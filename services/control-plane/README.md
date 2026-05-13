# FlowChain Control Plane V0

This package exposes a local JSON-RPC 2.0 control-plane for FlowMemory and FlowChain runtime/fixture data. It reads ignored `devnet/local/` state first, falls back to committed deterministic fixtures, and forwards local write intake to the existing devnet and bridge-relayer paths.

It is not a production RPC endpoint, hosted service, production wallet, sequencer, verifier network, token system, production bridge, or production chain API.

## Commands

From the repository root:

```powershell
npm run control-plane:demo
npm run control-plane:test
npm run control-plane:smoke
npm run control-plane:serve
npm run flowchain:full-smoke
```

The demo and tests require no secrets, RPC URLs, wallets, or production services.
The server defaults to `http://127.0.0.1:8787`.

## Methods

The dispatcher supports:

- `health`
- `chain_status`
- `devnet_state`
- `node_status`
- `peer_list`
- `mempool_list`
- `block_get`
- `block_list`
- `account_get`
- `account_list`
- `balance_get`
- `balance_list`
- `faucet_event_get`
- `faucet_event_list`
- `wallet_metadata_get`
- `wallet_metadata_list`
- `transaction_get`
- `transaction_list`
- `transaction_submit`
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
- `agent_account_get`
- `agent_account_list`
- `model_get`
- `model_list`
- `model_passport_get`
- `model_passport_list`
- `challenge_get`
- `challenge_list`
- `finality_get`
- `finality_list`
- `bridge_observation_submit`
- `bridge_observation_get`
- `bridge_observation_list`
- `bridge_deposit_get`
- `bridge_deposit_list`
- `bridge_credit_get`
- `bridge_credit_list`
- `withdrawal_get`
- `withdrawal_list`
- `provenance_get`
- `raw_json_get`

The API contract is documented in [docs/FLOWCHAIN_CONTROL_PLANE_API.md](../../docs/FLOWCHAIN_CONTROL_PLANE_API.md).

## Data Sources

The loader reads ignored local runtime outputs first when they exist:

- `devnet/local/state.json`
- `devnet/local/launch-v0-state.json`
- `devnet/local/handoff/generated/*.json`

It then falls back to committed deterministic outputs:

- `fixtures/launch-core/flowmemory-launch-v0.json`
- `fixtures/launch-core/generated/devnet/state.json`
- `fixtures/launch-core/generated/devnet/indexer-handoff.json`
- `fixtures/launch-core/generated/devnet/verifier-handoff.json`
- `fixtures/launch-core/generated/devnet/control-plane-handoff.json`
- `services/indexer/out/indexer-state.json`
- `services/verifier/out/reports.json`
- `services/verifier/fixtures/artifacts.json`
- `fixtures/handoff/sample-txs.json`
- `fixtures/bridge/base-sepolia-mock-deposit.json`

Bridge relayer output is read from `services/bridge-relayer/out/bridge-observation.json` and control-plane bridge intake is stored in `services/bridge-relayer/out/control-plane-observations.json`.

If the launch-core fixture is missing, the loader rebuilds the in-memory view from indexer/verifier outputs or the raw fixture receipts and artifact resolver. It does not fetch from production RPC or write production state.

`npm run control-plane:smoke` runs an in-process JSON-RPC client over the complete local lifecycle surface: health, chain status, node status, peers, mempool, blocks, transactions, transaction submission, accounts, balances, faucet status, wallet public metadata, rootfields, agents, agent accounts, models, model passports, work receipts, artifact availability, verifier modules, verifier reports, memory cells, challenges, finality, bridge observations/deposits/credits/withdrawals, provenance, raw JSON, and no-secret response scanning.
