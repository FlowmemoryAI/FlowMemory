# FlowChain Local Control Plane API

Status: private/local L1-shaped control-plane contract.

This document defines the local JSON-RPC 2.0 API for the FlowChain / FlowMemory control-plane. It gives dashboard, wallet, bridge, agent, verifier, and devnet tooling one deterministic local surface for FlowMemory objects, local runtime status, local file-backed signed transaction intake, bridge intake, and L1-style inspection.

It is still local/private and no-value unless a later gate explicitly changes that. It is not a hosted public RPC, public validator network, production bridge, custody surface, production tokenomics system, or verifier economics surface.

Every JSON-RPC result includes `responseProvenance`:

```json
{
  "schema": "flowmemory.control_plane.response_provenance.v1",
  "apiVersion": "flowchain-control-plane-production-l1.v1",
  "method": "chain_status",
  "runtimeSource": "live|imported|deterministic_fixture|unavailable",
  "storageSource": "live|imported|deterministic_fixture|unavailable",
  "indexerSource": "live|imported|deterministic_fixture|unavailable",
  "bridgeSource": "live|imported|deterministic_fixture|unavailable"
}
```

The schema catalog is published at:

```text
schemas/flowmemory/control-plane-production-l1.schema.json
```

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
fixtures/bridge/local-runtime-bridge-handoff.json
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
    "code": -32041,
    "message": "signed envelope signature verification failed",
    "data": {
      "schema": "flowmemory.control_plane.error.v1",
      "reasonCode": "transaction.bad_signature",
      "errorCode": "BAD_SIGNATURE",
      "message": "signed envelope signature verification failed",
      "correlationId": "control-plane-local",
      "recoverable": true,
      "retryable": false,
      "sourceComponent": "control-plane",
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
| `-32040` | Secret-shaped request or response material was rejected. |
| `-32041` | Signed transaction or bridge replay was rejected. |
| `-32042` | Live runtime is unavailable. |
| `-32043` | Storage source is unavailable. |

Machine-readable `errorCode` values:

`MALFORMED_REQUEST`, `UNSIGNED_TRANSACTION`, `BAD_SIGNATURE`,
`WRONG_CHAIN_ID`, `STALE_NONCE`, `DUPLICATE_TX`, `UNKNOWN_BLOCK`,
`UNKNOWN_TX`, `UNKNOWN_ACCOUNT`, `UNKNOWN_TOKEN`, `UNKNOWN_POOL`,
`BRIDGE_REPLAY`, `LIVE_RUNTIME_UNAVAILABLE`, `STORAGE_UNAVAILABLE`, and
`UNSAFE_SECRET_DETECTED`.

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
GET /explorer/summary
GET /product-flow/status
GET /pilot/status
GET /bridge/status
GET /bridge/deposits?limit=50
GET /bridge/credits?limit=50
GET /bridge/credit-status
POST /transfer/send
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

### `sync_status`

Params: none.

Returns current height, target height, finalized height, catch-up state, live runtime availability, and whether fallback state was used.

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
    "schema": "flowchain.signed_transaction_envelope.v1",
    "chainId": "flowmemory-local-devnet-v0",
    "signer": "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "nonce": "0",
    "signatureScheme": "flowchain-local-digest-v1",
    "payload": {
      "schema": "flowchain.transaction.transfer.v1",
      "type": "transfer",
      "from": "account:alice",
      "to": "account:bob",
      "tokenId": "local-test-unit",
      "amount": "7"
    },
    "signature": "0x..."
  },
  "submittedBy": "local-operator"
}
```

Accepts only versioned FlowChain signed transaction envelopes. Plain `transaction`, `tx`, or `txs` params are rejected. The method checks chain id, signer format, nonce, payload schema, duplicate tx id, and local deterministic signature digest. It rejects secret-shaped material and appends an accepted intake row plus local receipt to `devnet/local/intake/transactions.ndjson`. It does not broadcast to a public chain.

Structured rejection codes include `UNSIGNED_TRANSACTION`, `BAD_SIGNATURE`,
`WRONG_CHAIN_ID`, `STALE_NONCE`, `DUPLICATE_TX`, and
`UNSAFE_SECRET_DETECTED`.

### `transfer_send`

Params:

```json
{
  "from": "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "to": "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "amount": "2",
  "tokenId": "flowchain-bridge-credit",
  "memo": "dashboard-bridge-credit-transfer-test"
}
```

Creates a deterministic local signed transfer envelope for an already credited
FlowChain account, submits it through the same local transaction intake path as
`transaction_submit`, and returns a machine-readable receipt:

```json
{
  "schema": "flowmemory.control_plane.transfer_send_result.v1",
  "accepted": true,
  "status": "accepted_local",
  "receipt": {
    "schema": "flowmemory.control_plane.transfer_receipt.v1",
    "status": "accepted_local"
  },
  "noBaseReleaseBroadcast": true,
  "localOnly": true
}
```

The method refuses the placeholder `0x5555...5555` FlowChain recipient, checks
spendable local balance before accepting, and never broadcasts a Base release
transaction.

### `mempool_list`

Params:

```json
{ "limit": 50 }
```

Returns pending local transaction/intake rows.

### `event_list`, `event_get`

Event methods expose FlowPulse observations, rejected logs, and local
transaction-intake events.

List params:

```json
{
  "blockNumber": "123457",
  "blockHash": "0x...",
  "txId": "0x...",
  "accountId": "0x...",
  "eventType": "ROOT_COMMITTED",
  "limit": 50
}
```

Get params:

```json
{ "eventId": "0x..." }
```

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

Returns the local spendable balance for an account. When an applied bridge
credit exists for the account, the response includes `spendableBalance`,
`bridgeCreditAmount`, `pendingAcceptedDelta`, and `valueBearingPilot`. Without
an applied Base 8453 credit, the balance remains a no-value local test-unit
record.

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
GET /pilot/deposits?limit=50
GET /pilot/credits?limit=50
GET /pilot/withdrawal-intents?limit=50
GET /pilot/release-evidence?limit=50
GET /pilot/cap-status
GET /pilot/pause-status
GET /pilot/retry-status
GET /pilot/emergency-status
```

The four HTTP list endpoints accept the same `limit` bound as the JSON-RPC list methods. Invalid limits return the standard JSON-RPC invalid params error envelope as JSON.

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

### `finality_status`

Params: none.

Returns chain-level finalized height/hash, finality row counts, and whether finality state is live local runtime state or degraded fallback state.

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
Duplicate bridge replay keys are rejected with `BRIDGE_REPLAY`.

HTTP bridge observation endpoints are also available:

```text
GET /bridge/observations
POST /bridge/observations
```

### `bridge_deposit_list`, `bridge_deposit_get`

Expose local bridge-deposit test objects. These do not imply a production bridge, withdrawal, lockbox, or asset claim.

### `bridge_credit_list`, `bridge_credit_get`, `bridge_credit_status`

`bridge_credit_list` exposes local bridge-credit rows from runtime/control-plane
handoff maps or bridge-deposit projections.

`bridge_credit_get` accepts `creditId`, `depositId`, `accountId`,
`flowchainAccount`, `txHash`, or `baseTxHash`. When multiple rows match the same
Base transaction, the applied runtime credit is preferred over projected
artifacts.

`bridge_credit_status` accepts the same lookup aliases and returns the live
wallet/dashboard status panel data:

```json
{
  "schema": "flowmemory.control_plane.bridge_credit_status.v1",
  "readinessLabel": "LIVE PILOT|LOCAL ONLY|NOT READY",
  "exposureLabel": "LOCAL ONLY",
  "baseTxHash": "0x...",
  "confirmationStatus": "base_observed",
  "lifecycleStatus": {
    "observed": "observed",
    "queued": "queued",
    "applied": "applied",
    "idempotent": "unique_or_idempotent"
  },
  "creditedAccount": "0x...",
  "spendableBalance": "10",
  "transferActionStatus": "not_run|accepted_local",
  "firstUsableAt": "2026-05-14T12:00:02.000Z",
  "latencyMs": 2000,
  "noBaseReleaseBroadcast": true,
  "localOnly": true
}
```

`LIVE PILOT` is only returned when the running local node/control-plane state has
an applied Base chain ID `8453` credit to a non-placeholder FlowChain account.
Fixture, mock, Base Sepolia, or placeholder-recipient fallback is labeled
`NOT READY`; an unexposed local control-plane remains `LOCAL ONLY`.

### `bridge_config_get`, `bridge_status`

`bridge_config_get` returns browser-safe bridge mode, cap summary, pause status,
replay-protection counts, and runtime-intake readiness without exposing env
values.

`bridge_status` returns bridge readiness, observation/credit/withdrawal/release
counts, replay status, and `envValuesExposed: false`.

Browser-safe bridge HTTP mirrors are also available:

```text
GET /bridge/status
GET /bridge/deposits?limit=50
GET /bridge/credits?limit=50
GET /bridge/credit-status?txHash=0x...
GET /bridge/credit-status?accountId=0x...
POST /transfer/send
```

### `withdrawal_intent_list`, `withdrawal_intent_get`

Expose local bridge withdrawal-intent test objects. These are aliases over the
same source rows as `withdrawal_list` with dashboard-oriented field names.

### `release_evidence_list`, `release_evidence_get`

Expose local release-evidence records from bridge runtime handoffs. If no
release evidence exists but a withdrawal intent exists, the API returns an
explicit `pending_operator_release_evidence` projection so the dashboard can
show the missing step without parsing logs.

### `replay_rejection_list`, `replay_rejection_get`

Expose duplicate replay rejections when present. If there are no duplicates, the
list returns an explicit `idempotent_no_duplicate` record for dashboard and
relayer readiness checks.

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

Returns the raw loaded local JSON object for dashboard/workbench debug views. It does not accept arbitrary filesystem paths.

## Dashboard Consumption Notes

Dashboard agents should prefer:

1. `health`, `node_status`, `sync_status`, `chain_status`, and `finality_status` for source health and global counters.
2. `block_list`, `transaction_list`, `event_list`, and `mempool_list` for chain/devnet tables.
3. `account_list`, `balance_get`, `faucet_event_list`, and `wallet_metadata_list` for local identity and public metadata panels.
4. `rootfield_list` and `rootfield_get` for Rootfield detail.
5. `work_receipt_list`, `receipt_list`, `verifier_module_list`, and `verifier_report_list` for lifecycle tables.
6. `receipt_get`, `work_receipt_get`, `verifier_report_get`, and `provenance_get` for detail drawers.
7. `artifact_availability_list`, `memory_cell_list`, `agent_list`, and `model_list` for dashboard/workbench panels.
8. `challenge_get`, `challenge_list`, `finality_get`, and `finality_list` for local challenge/finality labels.
9. `token_list`, `token_balance_list`, `pool_list`, `lp_position_list`, `swap_list`, and `product_flow_status` for product-testnet token/DEX/explorer panels.
10. `pilot_status`, the four pilot list methods, and the four pilot status methods for capped owner-testing real-value pilot evidence.
11. `bridge_config_get`, `bridge_status`, `bridge_credit_status`, `bridge_observation_list`, `bridge_deposit_list`, `bridge_credit_list`, `withdrawal_intent_list`, `release_evidence_list`, and `replay_rejection_list` for bridge-shaped operator panels.
12. `bridge_credit_get` by `txHash` or `baseTxHash`, `balance_get`, and `transfer_send` for wallet/dashboard credit lookup and local transfer receipt checks.
13. `raw_json_get` for raw JSON inspection.

The API is local-only for V0. The submit methods are local file intake, not public chain broadcast. Live indexing, production settlement, production wallet custody, and production bridge methods require separate scoped work.
