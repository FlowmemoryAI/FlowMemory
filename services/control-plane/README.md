# FlowChain Control Plane V0

This package exposes a local JSON-RPC 2.0 control-plane for FlowMemory and FlowChain local runtime data. It prefers `devnet/local/` runtime state, falls back to deterministic committed fixtures, and keeps all mutable intake local-file backed.

It is not a production RPC endpoint, hosted service, wallet, sequencer, verifier network, token system, or production chain API.

## Commands

From the repository root:

```powershell
npm run control-plane:demo
npm run control-plane:test
npm run control-plane:smoke
npm run control-plane:serve
```

The demo and tests require no secrets, RPC URLs, wallets, or production services.
The server defaults to `http://127.0.0.1:8787`.

## Methods

The dispatcher supports:

- `health`
- `node_status`
- `peer_list`
- `chain_status`
- `devnet_state`
- `block_get`
- `block_list`
- `mempool_list`
- `transaction_get`
- `transaction_list`
- `transaction_submit`
- `account_get`
- `account_list`
- `balance_get`
- `faucet_event_list`
- `wallet_metadata_get`
- `wallet_metadata_list`
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
- `bridge_observation_get`
- `bridge_observation_list`
- `bridge_observation_submit`
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

The loader reads local runtime state first, then committed deterministic outputs:

- `devnet/local/state.json`
- `devnet/local/launch-v0-state.json`
- `fixtures/launch-core/flowmemory-launch-v0.json`
- `fixtures/launch-core/generated/devnet/state.json`
- `fixtures/launch-core/generated/devnet/indexer-handoff.json`
- `fixtures/launch-core/generated/devnet/verifier-handoff.json`
- `fixtures/launch-core/generated/devnet/control-plane-handoff.json`
- `services/indexer/out/indexer-state.json`
- `services/verifier/out/reports.json`
- `services/verifier/fixtures/artifacts.json`
- `fixtures/handoff/sample-txs.json`
- `services/bridge-relayer/out/bridge-observation.json`

If the launch-core fixture is missing, the loader rebuilds the in-memory view from indexer/verifier outputs or the raw fixture receipts and artifact resolver. It does not fetch from live RPC or write production state.

`transaction_submit` writes production-shaped local test transaction envelopes to `devnet/local/intake/transactions.ndjson` by default. `bridge_observation_submit` writes bridge-agent observations to `devnet/local/intake/bridge-observations.ndjson`. These files are local runtime intake, not committed fixtures.

`npm run control-plane:smoke` runs an in-process JSON-RPC client over the complete local lifecycle surface: health, node status, peers, chain status, blocks, transactions, mempool, accounts, balances, faucet events, wallet public metadata, rootfields, agents, models, work receipts, artifact availability, verifier modules, verifier reports, memory cells, challenges, finality, bridge observations, bridge deposits, bridge credits, withdrawals, provenance, and raw JSON.

All JSON-RPC responses are scanned before return and rejected if they contain private-key, mnemonic, seed phrase, RPC credential, API key, or webhook URL shaped material.
