# FlowMemory Control Plane V0

This package exposes a local JSON-RPC 2.0 control-plane for FlowMemory and FlowMemory local runtime data. It prefers `local-runtime/local/` runtime state, falls back to deterministic committed fixtures, and keeps all mutable intake local-file backed.

It is not a production RPC endpoint, hosted service, wallet, sequencer, verifier network, production token system, or production chain API.

## Commands

From the repository root:

```powershell
npm run control-plane:demo
npm run control-plane:test
npm run control-plane:smoke
npm run flowmemory:rpc:e2e
npm run control-plane:serve
npm run flowmemory:real-value-pilot:control-dashboard
```

The demo and tests require no secrets, RPC URLs, wallets, or production services.
The server defaults to `http://127.0.0.1:8787`.

## Methods

The dispatcher supports:

- `health`
- `rpc_discover`
- `rpc_readiness`
- `node_status`
- `peer_list`
- `chain_status`
- `pilot_status`
- `pilot_deposit_observation_list`
- `pilot_credit_list`
- `pilot_withdrawal_intent_list`
- `pilot_release_evidence_list`
- `pilot_cap_status`
- `pilot_pause_status`
- `pilot_retry_status`
- `pilot_emergency_status`
- `localRuntime_state`
- `block_get`
- `block_list`
- `mempool_list`
- `transaction_get`
- `transaction_list`
- `transaction_submit`
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
- `bridge_deposit_get`
- `bridge_deposit_list`
- `bridge_credit_get`
- `bridge_credit_list`
- `withdrawal_get`
- `withdrawal_list`
- `provenance_get`
- `raw_json_get`

The API contract is documented in [docs/FLOWMEMORY_CONTROL_PLANE_API.md](../../docs/FLOWMEMORY_CONTROL_PLANE_API.md).

## Data Sources

The loader reads local runtime state first, then committed deterministic outputs:

- `local-runtime/local/state.json`
- `local-runtime/local/launch-v0-state.json`
- `fixtures/launch-core/flowmemory-launch-v0.json`
- `fixtures/launch-core/generated/local-runtime/state.json`
- `fixtures/launch-core/generated/local-runtime/indexer-handoff.json`
- `fixtures/launch-core/generated/local-runtime/verifier-handoff.json`
- `fixtures/launch-core/generated/local-runtime/control-plane-handoff.json`
- `services/indexer/out/indexer-state.json`
- `services/verifier/out/reports.json`
- `services/verifier/fixtures/artifacts.json`
- `fixtures/handoff/sample-txs.json`
- `services/bridge-relayer/out/bridge-observation.json`
- `fixtures/bridge/local-runtime-bridge-handoff.json`

If the launch-core fixture is missing, the loader rebuilds the in-memory view from indexer/verifier outputs or the raw fixture receipts and artifact resolver. It does not fetch from live RPC or write production state.

`transaction_submit` accepts signed local test transaction envelopes only and writes them to `local-runtime/local/intake/transactions.ndjson` by default. When called with `runtimeSubmit: true` or `runtimeSubmitMode: "direct"`, it also forwards the contained localRuntime transaction into the active Rust runtime state file so `mempool_list`, block production, transaction reads, account reads, and balance reads can see it. `bridge_observation_submit` writes bridge-agent observations to `local-runtime/local/intake/bridge-observations.ndjson`. These files are local runtime intake, not committed fixtures.

`npm run control-plane:smoke` runs an in-process JSON-RPC client over the complete local lifecycle surface: RPC discovery/readiness, health, node status, peers, chain status, real-value pilot status/list/status methods, blocks, transactions, mempool, accounts, balances, tokens, token balances, pools, LP positions, swaps, product-flow status, faucet events, wallet public metadata, rootfields, agents, models, work receipts, artifact availability, verifier modules, verifier reports, memory cells, challenges, finality, bridge observations, bridge deposits, bridge credits, withdrawals, provenance, and raw JSON.

`npm run flowmemory:rpc:e2e` verifies the FlowMemory-native JSON-RPC discovery and readiness methods, required method coverage, no-secret report boundary, runtime-backed transaction submission, mempool visibility, block/transaction/account/balance/token-balance/provenance reads, and restart continuity. It writes `local-runtime/local/rpc-e2e/flowmemory-rpc-e2e-report.json` and intentionally reports public RPC readiness as blocked until the explicit public RPC deployment inputs are configured.

`npm run flowmemory:real-value-pilot:control-dashboard` verifies that the API exposes the capped owner-testing pilot lifecycle, rejects secret-shaped material, and that the dashboard source renders the pilot evidence and next operator command without browser secret storage. The root `flowmemory:real-value-pilot:e2e` command is the upstream final HQ pilot gate and depends on proof commands from multiple owner branches.

All JSON-RPC responses are scanned before return and rejected if they contain private-key, mnemonic, seed phrase, RPC credential, API key, or webhook URL shaped material.
