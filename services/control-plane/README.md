# FlowChain Control Plane V0

This package exposes a local JSON-RPC 2.0 control-plane for FlowMemory and FlowChain local runtime data. It prefers `devnet/local/` runtime state, falls back to deterministic committed fixtures, and keeps all mutable intake local-file backed.

It is not a production RPC endpoint, hosted service, wallet, sequencer, verifier network, production token system, or production chain API.

## Commands

From the repository root:

```powershell
npm run control-plane:demo
npm run control-plane:test
npm run control-plane:smoke
npm run control-plane:serve
npm run flowchain:real-value-pilot:control-dashboard
```

The demo and tests require no secrets, RPC URLs, wallets, or production services.
The server defaults to `http://127.0.0.1:8787`.

## Methods

The dispatcher supports:

- `health`
- `node_status`
- `peer_list`
- `sync_status`
- `chain_status`
- `finality_status`
- `pilot_status`
- `pilot_deposit_observation_list`
- `pilot_credit_list`
- `pilot_withdrawal_intent_list`
- `pilot_release_evidence_list`
- `pilot_cap_status`
- `pilot_pause_status`
- `pilot_retry_status`
- `pilot_emergency_status`
- `devnet_state`
- `block_get`
- `block_list`
- `mempool_list`
- `transaction_get`
- `transaction_list`
- `transaction_submit`
- `transfer_send`
- `event_get`
- `event_list`
- `account_get`
- `account_list`
- `balance_get`
- `token_get`
- `token_list`
- `token_balance_get`
- `token_balance_list`
- `pool_get`
- `pool_list`
- `lp_position_get`
- `lp_position_list`
- `swap_get`
- `swap_list`
- `product_flow_status`
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
- `bridge_config_get`
- `bridge_status`
- `bridge_deposit_get`
- `bridge_deposit_list`
- `bridge_credit_get`
- `bridge_credit_list`
- `bridge_credit_status`
- `withdrawal_intent_get`
- `withdrawal_intent_list`
- `release_evidence_get`
- `release_evidence_list`
- `replay_rejection_get`
- `replay_rejection_list`
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
- `fixtures/bridge/local-runtime-bridge-handoff.json`

If the launch-core fixture is missing, the loader rebuilds the in-memory view from indexer/verifier outputs or the raw fixture receipts and artifact resolver. It does not fetch from live RPC or write production state.

`transaction_submit` accepts signed local test transaction envelopes only and writes them to `devnet/local/intake/transactions.ndjson` by default. `transfer_send` builds a deterministic local signed transfer for an already credited FlowChain account, verifies spendable balance, refuses the `0x5555...5555` placeholder recipient, writes through the same local transaction intake path, and returns a machine-readable receipt. `bridge_observation_submit` writes bridge-agent observations to `devnet/local/intake/bridge-observations.ndjson`. These files are local runtime intake, not committed fixtures.

`bridge_credit_status` backs the dashboard wallet panel. It reports Base tx hash, confirmation/lifecycle/idempotent status, credited account, spendable balance, latest transfer action status, first usable timestamp, latency, `LIVE PILOT`/`LOCAL ONLY`/`NOT READY` labels, and `noBaseReleaseBroadcast: true`.

`npm run control-plane:smoke` runs an in-process JSON-RPC client over the complete local lifecycle surface: health, node status, peers, chain status, real-value pilot status/list/status methods, blocks, transactions, local transfer send, mempool, accounts, balances, tokens, token balances, pools, LP positions, swaps, product-flow status, faucet events, wallet public metadata, rootfields, agents, models, work receipts, artifact availability, verifier modules, verifier reports, memory cells, challenges, finality, bridge observations, bridge deposits, bridge credits, bridge credit status, withdrawals, provenance, and raw JSON.

`npm run flowchain:real-value-pilot:control-dashboard` verifies that the API exposes the capped owner-testing pilot lifecycle, rejects secret-shaped material, and that the dashboard source renders the pilot evidence and next operator command without browser secret storage. The root `flowchain:real-value-pilot:e2e` command is the upstream final HQ pilot gate and depends on proof commands from multiple owner branches.

All JSON-RPC responses are scanned before return and rejected if they contain private-key, mnemonic, seed phrase, RPC credential, API key, or webhook URL shaped material.
