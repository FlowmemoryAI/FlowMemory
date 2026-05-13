# FlowChain Local Control Plane API

Status: local runtime-backed V0 contract with deterministic fixture fallback.

This document defines the local JSON-RPC 2.0 API for the FlowChain / FlowMemory control-plane. It gives dashboard, agent, verifier, bridge, and devnet tooling one deterministic local surface for FlowMemory objects.

It is not a production RPC endpoint, public L1 API, hosted service, production wallet API, production bridge API, token API, or verifier economics surface.

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
npm run flowchain:full-smoke
```

The service reads ignored local runtime files first and falls back to committed deterministic fixtures. It does not require secrets, RPC URLs, private keys, API keys, or production services.

Primary data sources:

```text
devnet/local/state.json
devnet/local/launch-v0-state.json
devnet/local/handoff/generated/*.json
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
services/bridge-relayer/out/control-plane-observations.json
fixtures/bridge/base-sepolia-mock-deposit.json
```

If the generated launch-core fixture is missing, the service rebuilds the in-memory view from indexer/verifier outputs or raw fixture receipts and artifact fixtures. This recovery path is local. Transaction and bridge observation write endpoints forward only into the existing local runtime or bridge-agent intake files.

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

Returns local stack status, live/fixture source status, block counters, object counters, capabilities, and limitations.

Key result fields:

```json
{
  "schema": "flowmemory.control_plane.chain_status.v0",
  "chainId": "flowmemory-local-devnet-v0",
  "environment": "private-local-devnet",
  "source": "local-runtime-file",
  "currentBlock": "123461",
  "finalizedBlock": "123457",
  "localOnly": true
}
```

### `node_status`

Params: none.

Returns bounded local runtime status, current block, state root, pending
transaction count, runtime mode, and source file. The current runtime reports
`longRunningNode: false` because it is still the deterministic Rust CLI, not a
daemon.

### `peer_list`

Params: none.

Returns the local self peer for the single-process runtime. LAN peer discovery
is not implemented in this package.

### `mempool_list`

Params:

```json
{
  "limit": 50
}
```

Returns pending transaction envelopes from the local devnet state or
control-plane handoff.

### `devnet_state`

Params:

```json
{
  "includeBlocks": false
}
```

Returns local no-value devnet state, handoff summaries, rootfield counts, work receipt counts, report counts, and optional block data.

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

Params: one of:

```json
{ "tx": { "type": "RegisterRootfield" } }
```

```json
{ "txs": [{ "type": "RegisterRootfield" }] }
```

```json
{ "signedTransaction": { "tx": { "type": "RegisterRootfield" }, "signature": "0x..." } }
```

The control-plane writes a local fixture under
`devnet/local/control-plane-intake/` and forwards it to the existing runtime
intake path:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/state.json submit-fixture --fixture <generated-fixture>
```

The endpoint queues transactions only. It does not produce a block by itself.
Payloads containing secret-bearing fields such as `privateKey`, `mnemonic`,
`seedPhrase`, `rpcUrl`, `apiKey`, or webhook credentials are rejected.

### `account_list` / `account_get`

Return local public account rows for operator key references and `AgentAccount`
objects. Balances are no-value local devnet balances.

### `balance_list` / `balance_get`

Return explicit zero/no-value balances. The private/local runtime has no token
value, gas accounting, staking, rewards, or faucet funds.

### `faucet_event_list` / `faucet_event_get`

Return a stable disabled faucet event explaining that the local devnet has no
token value or faucet funds.

### `wallet_metadata_list` / `wallet_metadata_get`

Return public operator key-reference metadata only: key reference ids, operator
ids, signature scheme labels, and verifier-set roots. No signing secret
material is returned.

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

### `agent_account_list` / `agent_account_get`

Return native private/local `AgentAccount` objects from the devnet runtime state
or handoff files.

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

### `model_passport_list` / `model_passport_get`

Return native private/local `ModelPassport` objects from the devnet runtime
state or handoff files.

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

### `bridge_observation_submit`

Params: one of:

```json
{ "observation": { "schema": "flowmemory.bridge_deposit_observation.v0" } }
```

```json
{ "deposit": { "schema": "flowmemory.bridge_deposit.v0" } }
```

Stores local bridge-agent observations in
`services/bridge-relayer/out/control-plane-observations.json`. This is local
observation intake only; it does not custody funds, sign releases, or implement
production bridge security.

### `bridge_observation_list` / `bridge_observation_get`

Return bridge observations from bridge-relayer output, control-plane intake, or
the committed mock deposit fixture.

### `bridge_deposit_list` / `bridge_deposit_get`

Return bridge deposit rows derived from bridge observations.

### `bridge_credit_list` / `bridge_credit_get`

Return local bridge-credit projections for observed deposits. Pending credits do
not imply production bridge accounting.

### `withdrawal_list` / `withdrawal_get`

Return local withdrawal handoff rows when present. Without native withdrawal
handoff data, `withdrawal_get` returns a stable `not_opened` placeholder.

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
- `bridgeObservation`
- `bridgeObservationIntake`
- `bridgeDepositFixture`

Returns the raw loaded local JSON object for dashboard/workbench debug views. It does not accept arbitrary filesystem paths.

## Dashboard Consumption Notes

Dashboard agents should prefer:

1. `health`, `chain_status`, and `node_status` for source health and global counters.
2. `block_list`, `transaction_list`, and `mempool_list` for chain/devnet tables.
3. `account_list`, `wallet_metadata_list`, `balance_list`, and `faucet_event_list` for local account panels.
4. `rootfield_list` and `rootfield_get` for Rootfield detail.
5. `agent_account_list`, `model_passport_list`, `work_receipt_list`, `receipt_list`, `verifier_module_list`, and `verifier_report_list` for lifecycle tables.
6. `receipt_get`, `work_receipt_get`, `verifier_report_get`, and `provenance_get` for detail drawers.
7. `artifact_availability_list`, `memory_cell_list`, `agent_list`, and `model_list` for dashboard/workbench panels.
8. `challenge_get`, `challenge_list`, `finality_get`, and `finality_list` for local challenge/finality labels.
9. `bridge_observation_list`, `bridge_deposit_list`, `bridge_credit_list`, and `withdrawal_list` for bridge-agent inspection.
10. `raw_json_get` for raw JSON inspection.

HTTP helpers are available for browser workbench reads at `/node/status`,
`/peers`, `/mempool`, `/blocks`, `/transactions`, `/accounts`, `/balances`,
`/faucet/events`, `/wallets`, `/agents`, `/models`, `/work-receipts`,
`/artifacts/availability`, `/verifier-modules`, `/verifier-reports`,
`/memory-cells`, `/challenges`, `/finality`, `/bridge/observations`,
`/bridge/deposits`, `/bridge/credits`, and `/withdrawals`. Write helpers are
available at `POST /transactions` and `POST /bridge/observations`; JSON-RPC
remains the canonical API envelope.
