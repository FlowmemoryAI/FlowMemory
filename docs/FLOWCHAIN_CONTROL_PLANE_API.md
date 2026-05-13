# FlowChain Local Control Plane API

Status: local runtime/fixture-backed V0 contract.

This document defines the local JSON-RPC 2.0 API for the FlowChain / FlowMemory control-plane. It gives dashboard, agent, verifier, and devnet tooling one deterministic local surface for FlowMemory objects, local runtime status, local file-backed transaction intake, and bridge-observation intake.

It is not a production RPC endpoint, public L1 API, hosted service, wallet API, bridge API, token API, or verifier economics surface.

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
```

If local runtime state is missing, the service falls back to generated launch-core and committed fixtures. If the generated launch-core fixture is missing, the service rebuilds the in-memory view from indexer/verifier outputs or raw fixture receipts and artifact fixtures.

Mutable local intake methods write ignored files only:

```text
devnet/local/intake/transactions.ndjson
devnet/local/intake/bridge-observations.ndjson
```

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
  "signedTransaction": "{...}",
  "transaction": {
    "schema": "flowchain.local_transaction_envelope.v0"
  },
  "submittedBy": "local-operator"
}
```

Accepts a production-shaped local test transaction envelope or plain local test object, rejects secret-shaped material, and appends an intake row to `devnet/local/intake/transactions.ndjson`. It does not broadcast to a public chain.

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

Expose local bridge-credit test objects. These are no-value local accounting objects only.

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
9. `bridge_observation_list`, `bridge_deposit_list`, `bridge_credit_list`, and `withdrawal_list` for local bridge-shaped test panels.
10. `raw_json_get` for raw JSON inspection.

The API is local-only for V0. The submit methods are local file intake, not public chain broadcast. Live indexing, production settlement, production wallet custody, and production bridge methods require separate scoped work.
