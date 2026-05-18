# FlowChain Local Control Plane API

Status: local runtime/fixture-backed V0 contract.

This document defines the local JSON-RPC 2.0 API for the FlowChain / FlowMemory control-plane. It gives dashboard, agent, verifier, and devnet tooling one deterministic local surface for FlowMemory objects, local runtime status, local file-backed transaction intake, and bridge-observation intake.

It is not a production RPC endpoint, public L1 API, hosted service, wallet API, production bridge API, production token API, or verifier economics surface.

## Runtime Boundary

The V0 service is implemented in:

```text
services/control-plane/
```

Commands:

```powershell
npm run control-plane:test
npm run control-plane:demo
npm run control-plane:smoke
npm run flowchain:rpc:e2e
npm run control-plane:serve
```

The service uses deterministic local files only. It does not require secrets, RPC URLs, private keys, API keys, or production services. Wallet metadata returned by this API is browser-safe public metadata only.

Primary data sources:

```text
devnet/local/state.json
devnet/local/launch-v0-state.json
fixtures/launch-core/flowmemory-launch-v0.json
fixtures/launch-core/generated/devnet/state.json
fixtures/launch-core/generated/devnet/indexer-handoff.json
fixtures/launch-core/generated/devnet/verifier-handoff.json
fixtures/launch-core/generated/devnet/control-plane-handoff.json
services/indexer/out/indexer-state.json
services/verifier/out/reports.json
services/verifier/fixtures/artifacts.json
fixtures/handoff/sample-txs.json
services/bridge-relayer/out/bridge-observation.json
fixtures/bridge/local-runtime-bridge-handoff.json
```

If local runtime state is missing, the service falls back to generated launch-core and committed fixtures. If the generated launch-core fixture is missing, the service rebuilds the in-memory view from indexer/verifier outputs or raw fixture receipts and artifact fixtures.

Mutable local intake methods write ignored files only:

```text
devnet/local/intake/transactions.ndjson
devnet/local/intake/bridge-observations.ndjson
```

`transaction_submit` can also be asked to forward a valid local devnet transaction
into the active Rust runtime state with `runtimeSubmit: true` or
`runtimeSubmitMode: "direct"`. That mode is still local-only, but it proves the
RPC can drive the same state file that block production reads.

All JSON-RPC responses and local intake payloads are scanned for private-key, mnemonic, seed phrase, RPC credential, API key, and webhook-shaped material.

## JSON-RPC Envelope

Request:

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "method": "chain_status",
  "params": {}
}
```

Success:

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {
    "schema": "flowmemory.control_plane.chain_status.v0"
  }
}
```

Error:

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "error": {
    "code": -32602,
    "message": "rootfield_get requires one of: rootfieldId",
    "data": {
      "schema": "flowmemory.control_plane.error.v0",
      "reasonCode": "params.invalid",
      "localOnly": true
    }
  }
}
```

Error codes:

| Code | Meaning |
| --- | --- |
| `-32700` | Parse error in HTTP server payload. |
| `-32600` | Invalid JSON-RPC request. |
| `-32601` | Unknown method. |
| `-32602` | Missing or invalid params. |
| `-32603` | Internal local control-plane error. |
| `-32004` | Requested local object was not found. |

## Methods

### `health`

Params: none.

Returns local service readiness, source health, core object counters, and `localOnly: true`.

HTTP health is also available:

```text
GET /health
```

Browser-safe summary endpoints are also available:

```text
GET /rpc/discover
GET /rpc/readiness
GET /explorer/summary
GET /product-flow/status
GET /pilot/status
```

### `rpc_discover`

Params: none.

Returns the FlowChain-native JSON-RPC method inventory for wallets, explorers,
relayers, and deployment checks. This method is intentionally not EVM JSON-RPC
or Solana JSON-RPC compatibility. It reports the supported FlowChain methods,
their categories, read/write mode, local-only boundary, and current production
readiness status.

HTTP mirror:

```text
GET /rpc/discover
```

### `rpc_readiness`

Params: none.

Returns a fail-closed machine-readable readiness object for the FlowChain RPC.
It reports whether active runtime state is readable, whether wallet/explorer/
bridge consumers can use the current RPC, and which public deployment inputs
are missing. It returns environment variable names only, never values.

Public RPC deployment inputs currently checked by name:

```text
FLOWCHAIN_RPC_PUBLIC_URL
FLOWCHAIN_RPC_ALLOWED_ORIGINS
FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
FLOWCHAIN_RPC_TLS_TERMINATED
FLOWCHAIN_RPC_STATE_BACKUP_PATH
```

HTTP mirror:

```text
GET /rpc/readiness
```

### `chain_status`

Params: none.

Returns local stack status, fixture source status, block counters, object counters, capabilities, and limitations.

Key result fields:

```json
{
  "schema": "flowmemory.control_plane.chain_status.v0",
  "chainId": "flowmemory-local-alpha",
  "environment": "local-devnet-fixture",
  "source": "fixture",
  "currentBlock": "123461",
  "finalizedBlock": "123457",
  "localOnly": true
}
```

### `devnet_state`

Params:

```json
{
  "includeBlocks": false
}
```

Returns local no-value devnet state, handoff summaries, rootfield counts, work receipt counts, report counts, and optional block data.

### `node_status`

Params: none.

Returns local node/control-plane status, runtime state source, latest block, latest root, object counters, and missing optional sources.

### `peer_list`

Params:

```json
{ "limit": 50 }
```

Returns local/private peer inventory when present. Current single-node mode returns local-only peer rows or an empty local list; it does not imply public validators.

### `block_list`

Params:

```json
{
  "source": "local-devnet",
  "includeTransactions": false,
  "limit": 50
}
```

All params are optional. Returns local devnet blocks and indexer-observed FlowPulse block groups.

### `block_get`

Params: one of:

```json
{ "blockNumber": "1", "includeTransactions": true }
```

```json
{ "blockHash": "0x..." }
```

### `transaction_list`

Params:

```json
{
  "blockNumber": "1",
  "rootfieldId": "0x...",
  "status": "finalized",
  "source": "flowpulse-indexer",
  "limit": 50
}
```

All params are optional. Returns local devnet transactions plus indexer transaction groups derived from `txHash`.

### `transaction_get`

Params: one of:

```json
{ "txId": "0x..." }
```

```json
{ "txHash": "0x..." }
```

### `transaction_submit`

Params:

```json
{
  "signedEnvelope": {
    "schema": "flowchain.local_transaction_envelope.v0",
    "tx": {
      "schema": "flowchain.local_transaction.v0"
    },
    "signature": "0x..."
  },
  "submittedBy": "local-operator",
  "runtimeSubmit": true
}
```

Accepts signed local test transaction envelopes only. Plain `transaction`, `tx`,
or `txs` params are rejected. The method rejects secret-shaped material and
appends an intake row to `devnet/local/intake/transactions.ndjson`. With
`runtimeSubmit` enabled, the contained devnet `tx` is also submitted directly to
the active local Rust runtime state. It does not broadcast to a public chain.

### `mempool_list`

Params:

```json
{ "limit": 50 }
```

Returns pending local transaction/intake rows.

### `account_list`

Params:

```json
{ "limit": 50 }
```

Returns local account/controller metadata, including devnet `AgentAccount` rows and projected local operator rows.

### `account_get`

Params:

```json
{ "accountId": "agent:demo:alpha" }
```

Returns one local account row.

### `balance_get`

Params:

```json
{ "accountId": "local-balance:demo:agent-alpha" }
```

Returns a no-value local test-unit balance record. This is not a token balance, reward, fee account, or bridge asset.

### `token_list`

Params:

```json
{
  "status": "launched",
  "limit": 50
}
```

All params are optional. Returns product-testnet token rows from devnet/control-plane handoff maps such as `tokens`, `tokenDefinitions`, `tokenLaunches`, `localTokens`, or `launchedTokens`. If no native token map exists but local test-unit balances exist, the API projects a no-value `local-test-unit` row so explorer panels can still render local funding state.

### `token_get`

Params: one of:

```json
{ "tokenId": "token:demo" }
```

```json
{ "symbol": "DEMO" }
```

### `token_balance_list`

Params:

```json
{
  "accountId": "account:alice",
  "tokenId": "token:demo",
  "limit": 50
}
```

All params are optional. Returns product-testnet token balance rows from handoff maps such as `tokenBalances`, `localTokenBalances`, or `accountTokenBalances`. Local test-unit balances are projected as `local-test-unit` token balances when native token-balance maps are not present.

### `token_balance_get`

Params: one of:

```json
{ "balanceId": "token-balance:demo:alice" }
```

```json
{
  "accountId": "account:alice",
  "tokenId": "token:demo"
}
```

### `pool_list`, `pool_get`

Pool methods expose DEX pool rows from `pools`, `dexPools`, `liquidityPools`, or `ammPools` handoff maps.

List params:

```json
{
  "tokenId": "token:demo",
  "limit": 50
}
```

Get params:

```json
{ "poolId": "pool:demo-ltu" }
```

### `lp_position_list`, `lp_position_get`

LP position methods expose liquidity position rows from `lpPositions`, `liquidityPositions`, or `poolPositions` handoff maps.

List params:

```json
{
  "accountId": "account:alice",
  "poolId": "pool:demo-ltu",
  "limit": 50
}
```

Get params:

```json
{ "positionId": "lp:alice:demo-ltu" }
```

### `swap_list`, `swap_get`

Swap methods expose DEX swap rows from `swaps`, `swapReceipts`, or `dexSwaps` handoff maps.

List params:

```json
{
  "accountId": "account:alice",
  "poolId": "pool:demo-ltu",
  "limit": 50
}
```

Get params:

```json
{ "swapId": "swap:001" }
```

```json
{ "txId": "0x..." }
```

### `product_flow_status`

Params: none.

Returns product-testnet readiness counters and stage labels for wallet, funding, transfer, token launch, DEX pool, liquidity, swap, bridge credit, and explorer visibility. This is a local acceptance/readiness view only; it does not claim production L1 or real-funds bridge readiness.

### Real-value pilot methods

The pilot methods expose a read-only, browser-safe projection of the capped owner-testing bridge lifecycle. They are for operator evidence review only. They do not expose private keys, seed phrases, mnemonics, RPC credentials, API keys, webhook URLs, wallet custody, public bridge readiness, or production release authority.

The control-plane builds the pilot view from bridge observations, local runtime bridge handoff data, and local devnet/control-plane handoff maps when present. Base mainnet pilot evidence is identified as chain ID `8453`; mock, local-anvil, and Base Sepolia evidence can still render as degraded operator state.

`pilot_status`

Params: none.

Returns:

```json
{
  "schema": "flowmemory.control_plane.real_value_pilot_status.v0",
  "label": "FlowChain capped owner real-value pilot",
  "state": "degraded",
  "baseChainId": 8453,
  "cappedOwnerTesting": true,
  "broadPublicReadiness": false,
  "browserStoresSecrets": false,
  "nextOperatorStep": {
    "command": "npm run bridge:observe -- --mode base-mainnet-canary --rpc-url <FLOWCHAIN_BASE8453_RPC_URL> --lockbox-address <FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS> --from-block <n> --to-block <n> --acknowledge-real-funds --max-usd 25"
  }
}
```

The result includes lifecycle rows for Base deposit observation, local credit application, replay/retry checks, withdrawal intent, release evidence, caps, pause, and emergency state.

`bridge_live_readiness`

Params: none.

Returns a fail-closed machine-readable readiness object for operator live-pilot
inspection. It always identifies Base as chain ID `8453`, reports whether the
lockbox, Base reader endpoint, block range, confirmation depth, cap env, and
operator acknowledgement are configured, and lists missing env names only. It
must not return env values.

Important fields:

```json
{
  "schema": "flowmemory.control_plane.bridge_live_readiness.v0",
  "baseChainId": 8453,
  "failClosedStatus": "BLOCKED",
  "readyForOperatorLivePilot": false,
  "missingEnvNames": ["FLOWCHAIN_BASE8453_RPC_URL"],
  "envValuesPrinted": false,
  "issues": [
    { "reasonCode": "missing_env", "status": "blocked" }
  ]
}
```

`failClosedStatus` is one of `BLOCKED`, `FAILED`, or
`READY_FOR_OPERATOR_LIVE_PILOT`. The dashboard must not present live mode as
ready until this field is `READY_FOR_OPERATOR_LIVE_PILOT` and the lockbox
address has been owner-verified outside the browser.

`pilot_lifecycle_record_list`

Returns deposit/credit lifecycle records keyed by Base tx hash, log index,
credit id, recipient wallet, asset, amount in smallest units, status, and
evidence path/id.

List params:

```json
{
  "baseTxHash": "0x...",
  "creditId": "0x...",
  "walletAddress": "0x...",
  "status": "release_evidence_recorded",
  "query": "optional free text",
  "limit": 50
}
```

Each record includes exact value equality fields:

```json
{
  "depositAmount": "1000000",
  "observedAmount": "1000000",
  "creditedAmount": "1000000",
  "walletDelta": "1000000",
  "transferableAmount": "1000000",
  "withdrawalAmount": "1000000",
  "releaseAmount": "1000000",
  "allEqual": true
}
```

`wallet_balance_list` and `wallet_transfer_history`

These methods expose wallet balances and transfer history needed to prove that
a credited FlowChain wallet can transfer the credited amount and that recipient
balances update exactly. They accept the same list filters for
`walletAddress`, `status`, `query`, and `limit`, and they return
`localOnly: true`, `productionReady: false`.

List methods:

- `pilot_deposit_observation_list`
- `pilot_credit_list`
- `pilot_withdrawal_intent_list`
- `pilot_release_evidence_list`

Each list accepts optional `{ "limit": 50 }`, capped from `1` to `100`, and returns `localOnly: true`, `productionReady: false`, and `cappedOwnerTesting: true`.

Status methods:

- `pilot_cap_status`
- `pilot_pause_status`
- `pilot_retry_status`
- `pilot_emergency_status`

Each status response includes an exact `state` (`live`, `degraded`, or `error` where applicable) and an operator command for the next safe local step.

Browser-safe HTTP mirrors are also available:

```text
GET /pilot/status
GET /bridge/live-readiness
GET /pilot/lifecycle?txHash=0x...&creditId=0x...&walletAddress=0x...&status=...
GET /pilot/deposits?limit=50
GET /pilot/credits?limit=50
GET /pilot/withdrawal-intents?limit=50
GET /pilot/release-evidence?limit=50
GET /pilot/cap-status
GET /pilot/pause-status
GET /pilot/retry-status
GET /pilot/emergency-status
GET /wallets/balances?walletAddress=0x...&status=credited
GET /wallets/transfers?walletAddress=0x...&status=applied
```

The HTTP list endpoints accept the same `limit` bound and filters as the JSON-RPC list methods. Invalid limits return the standard JSON-RPC invalid params error envelope as JSON.

### `faucet_event_list`

Params:

```json
{ "limit": 50 }
```

Returns no-value local faucet records used by smoke tests.

### `wallet_metadata_list`

Params:

```json
{ "limit": 50 }
```

Returns browser-safe public wallet/operator metadata only. It must not include private key material.

### `wallet_metadata_get`

Params:

```json
{ "walletId": "agent:demo:alpha" }
```

Returns one public wallet/operator metadata row.

### `rootfield_get`

Params:

```json
{
  "rootfieldId": "0x..."
}
```

Returns the Flow Memory `RootfieldBundle`, matching local devnet rootfield when present, memory cell id, agent view id, and provenance.

### `rootfield_list`

Params:

```json
{
  "status": "verified",
  "limit": 50
}
```

All params are optional. Returns launch-core and local devnet rootfield rows.

### `artifact_get`

Params: one of:

```json
{ "uri": "fixture://root-commit-valid" }
```

```json
{ "artifactId": "artifact:demo:001" }
```

```json
{ "commitment": "0x..." }
```

Returns fixture artifact resolver data or local devnet artifact commitment records. V0 does not fetch arbitrary HTTP or IPFS content.

### `artifact_availability_list`

Params:

```json
{
  "rootfieldId": "0x...",
  "status": "available_fixture",
  "limit": 50
}
```

All params are optional. Returns local artifact commitments, native availability proofs when handoff files contain them, and verifier fixture availability rows.

### `artifact_availability_get`

Params: one of:

```json
{ "availabilityId": "0x..." }
```

```json
{ "artifactId": "artifact:demo:001" }
```

```json
{ "commitment": "0x..." }
```

```json
{ "uri": "fixture://root-commit-valid" }
```

### `receipt_get`

Params: one of:

```json
{ "receiptId": "0x..." }
```

```json
{ "observationId": "0x..." }
```

```json
{ "reportId": "0x..." }
```

Returns a `MemoryReceipt` plus linked signal, transition, verifier report, and provenance when available. It also supports local devnet `workReceipts`.

### `receipt_list`

Params:

```json
{
  "rootfieldId": "0x...",
  "status": "verified",
  "limit": 50
}
```

All params are optional. `limit` must be between `1` and `100`.

Returns deterministic local receipt rows.

### `work_receipt_list`

Params:

```json
{
  "rootfieldId": "0x...",
  "status": "verified",
  "limit": 50
}
```

All params are optional. Returns local devnet work receipts and launch-core MemoryReceipt compatibility rows.

### `work_receipt_get`

Params: one of:

```json
{ "workReceiptId": "receipt:demo:001" }
```

```json
{ "receiptId": "0x..." }
```

```json
{ "observationId": "0x..." }
```

```json
{ "reportId": "0x..." }
```

### `verifier_module_list`

Params:

```json
{
  "status": "available_fixture",
  "limit": 50
}
```

All params are optional. Returns native verifier modules if present, plus stable projected modules from verifier report resolver policy and local devnet verifier ids.

### `verifier_module_get`

Params: one of:

```json
{ "moduleId": "0x..." }
```

```json
{ "verifierId": "verifier:local-demo" }
```

```json
{ "resolverPolicyId": "flowmemory.resolver.policy.v0.fixture" }
```

### `verifier_report_get`

Params: one of:

```json
{ "reportId": "0x..." }
```

```json
{ "observationId": "0x..." }
```

Returns the deterministic verifier report, linked memory receipt, and provenance. It also supports local devnet verifier reports.

### `verifier_report_list`

Params:

```json
{
  "rootfieldId": "0x...",
  "status": "valid",
  "limit": 50
}
```

All params are optional. `limit` must be between `1` and `100`.

### `memory_cell_get`

Params: one of:

```json
{ "rootfieldId": "0x..." }
```

```json
{ "memoryCellId": "0x..." }
```

When local devnet handoff files contain `memoryCells`, this method returns that record. Otherwise it returns a stable projected memory-cell shape built from `RootfieldBundle` and `AgentMemoryView` fixtures, with an explicit `extensionPoint` field.

### `memory_cell_list`

Params:

```json
{
  "rootfieldId": "0x...",
  "status": "verified",
  "limit": 50
}
```

All params are optional.

### `agent_get`

Params: one of:

```json
{ "rootfieldId": "0x..." }
```

```json
{ "viewId": "0x..." }
```

```json
{ "agentId": "0x..." }
```

Returns an `AgentMemoryView` and linked `RootfieldBundle`.

### `agent_list`

Params:

```json
{
  "rootfieldId": "0x...",
  "status": "verified",
  "limit": 50
}
```

All params are optional.

### `model_list`

Params:

```json
{
  "rootfieldId": "0x...",
  "status": "local-placeholder",
  "limit": 50
}
```

Returns native model passports when local devnet handoff files contain them, plus explicit projected rows from launch-core agent memory views so the workbench model API remains stable.

### `model_get`

Params: one of:

```json
{ "modelId": "0x..." }
```

```json
{ "rootfieldId": "0x..." }
```

### `challenge_get`

Params: one of:

```json
{ "targetId": "0x..." }
```

```json
{ "receiptId": "0x..." }
```

```json
{ "reportId": "0x..." }
```

When local devnet handoff files contain `challenges`, this method returns that record. Otherwise it returns a stable placeholder object with `status: "not_opened"` for known targets, preserving the future challenge API shape without implying a live challenge system.

### `challenge_list`

Params:

```json
{
  "status": "open",
  "limit": 50
}
```

All params are optional. Returns native challenge handoff rows when present.

### `finality_get`

Params: one of:

```json
{ "objectId": "0x..." }
```

```json
{ "rootfieldId": "0x..." }
```

```json
{ "receiptId": "0x..." }
```

```json
{ "reportId": "0x..." }
```

Returns local fixture finality only. When local devnet handoff files contain `finalityReceipts`, the result links that record. Result statuses include:

- `local-finalized`
- `local-pending`
- `local-rejected`
- `local-unsupported`
- `reorged`

### `finality_list`

Params:

```json
{
  "rootfieldId": "0x...",
  "status": "local-finalized",
  "limit": 50
}
```

All params are optional. Returns native finality receipts when present and projected local finality rows for launch-core receipts.

### `bridge_observation_list`

Params:

```json
{ "limit": 50 }
```

Returns local bridge observation rows from fixture or intake files. These are private/local test objects, not production bridge events.

### `bridge_observation_get`

Params: one of:

```json
{ "depositId": "0x..." }
```

```json
{ "observationId": "0x..." }
```

### `bridge_observation_submit`

Params:

```json
{
  "observation": {
    "schema": "flowmemory.bridge_deposit_observation.v0"
  }
}
```

Rejects secret-shaped material and writes an ignored local intake row to `devnet/local/intake/bridge-observations.ndjson`.

HTTP bridge observation endpoints are also available:

```text
GET /bridge/observations
POST /bridge/observations
```

### `bridge_deposit_list`, `bridge_deposit_get`

Expose local bridge-deposit test objects. These do not imply a production bridge, withdrawal, lockbox, or asset claim.

### `bridge_credit_list`, `bridge_credit_get`

Expose local bridge-credit test objects from runtime/control-plane handoff maps or bridge-deposit projections. These are no-value local accounting objects only.

### `token_transfer_list`, `token_transfer_get`

Expose browser-safe token transfer rows from runtime handoff maps or deterministic explorer fallback data. Rows include `transferId`, `txId`, `tokenId`, `fromAccount`, `toAccount`, `amount`, `status`, `blockNumber`, and provenance/source hints.

### `explorer_search`

Params:

```json
{
  "query": "0x...",
  "limit": 8
}
```

Searches loaded block heights/hashes, transaction IDs, accounts, tokens, pools, Base tx hashes, bridge observations, bridge credits, credited accounts, transfer tx IDs, swap tx IDs, withdrawal intents, and release evidence. Returns `flowmemory.control_plane.explorer_search.v0` with `matches[]`, `objectType`, `objectId`, route hints, provenance, and the matched object.

### `withdrawal_list`, `withdrawal_get`

Expose local bridge-withdrawal test objects. These do not release funds and do not imply bridge readiness.

### `provenance_get`

Params: one of:

```json
{ "objectId": "0x..." }
```

```json
{ "receiptId": "0x..." }
```

```json
{ "reportId": "0x..." }
```

```json
{ "rootfieldId": "0x..." }
```

```json
{ "uri": "fixture://root-commit-valid" }
```

Returns local source files and linked IDs for receipts, reports, memory signals, transitions, rootfields, agent views, and artifacts.

### `raw_json_get`

Params:

```json
{
  "source": "launchCore"
}
```

Allowed `source` values:

- `launchCore`
- `indexer`
- `verifier`
- `artifacts`
- `devnet`
- `devnetIndexerHandoff`
- `devnetVerifierHandoff`
- `devnetControlPlaneHandoff`
- `txFixtures`
- `txIntake`
- `bridgeObservations`
- `bridgeRuntimeHandoff`
- `explorerFallback`

Returns the raw loaded local JSON object for dashboard/workbench debug views. It does not accept arbitrary filesystem paths.

## Dashboard Consumption Notes

Dashboard agents should prefer:

1. `health`, `node_status`, and `chain_status` for source health and global counters.
2. `block_list`, `transaction_list`, and `mempool_list` for chain/devnet tables.
3. `account_list`, `balance_get`, `faucet_event_list`, and `wallet_metadata_list` for local identity and public metadata panels.
4. `rootfield_list` and `rootfield_get` for Rootfield detail.
5. `work_receipt_list`, `receipt_list`, `verifier_module_list`, and `verifier_report_list` for lifecycle tables.
6. `receipt_get`, `work_receipt_get`, `verifier_report_get`, and `provenance_get` for detail drawers.
7. `artifact_availability_list`, `memory_cell_list`, `agent_list`, and `model_list` for dashboard/workbench panels.
8. `challenge_get`, `challenge_list`, `finality_get`, and `finality_list` for local challenge/finality labels.
9. `token_list`, `token_balance_list`, `token_transfer_list`, `pool_list`, `lp_position_list`, `swap_list`, and `product_flow_status` for product-testnet token/DEX/explorer panels.
10. `pilot_status`, the four pilot list methods, and the four pilot status methods for capped owner-testing real-value pilot evidence.
11. `bridge_observation_list`, `bridge_deposit_list`, `bridge_credit_list`, and `withdrawal_list` for local bridge-shaped test panels.
12. `explorer_search` for global explorer lookup.
13. `raw_json_get` for raw JSON inspection.

The API is local-only for V0. The submit methods are local file intake, not public chain broadcast. Live indexing, production settlement, production wallet custody, and production bridge methods require separate scoped work.
