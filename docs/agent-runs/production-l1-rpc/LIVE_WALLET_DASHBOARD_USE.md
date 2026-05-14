# Live Wallet Dashboard Use

Final status: EXTERNAL-BLOCKED

Reason: the local runtime state is readable through the new control-plane and dashboard paths, but this machine does not have an applied Base chain ID `8453` bridge credit to a non-placeholder FlowChain account. The only loaded bridge credit during this run came from `fixtures/bridge/local-runtime-bridge-handoff.json`, used source chain `84532`, and credited the placeholder `0x5555...5555` account. The code correctly labels that state `NOT READY` and refuses transfer from the placeholder.

## What Changed

- Added `bridge_credit_status` and `transfer_send` to the control-plane API.
- Added HTTP routes:
  - `GET /bridge/status`
  - `GET /bridge/deposits?limit=`
  - `GET /bridge/credits?limit=`
  - `GET /bridge/credit-status`
  - `POST /transfer/send`
- Updated `bridge_credit_get` so lookup by `txHash` or `baseTxHash` prefers an applied runtime credit over projected artifacts.
- Updated `balance_get` so applied bridge credits contribute to `spendableBalance`.
- Added dashboard `/bridge`:
  - generates an in-memory FlowChain recipient or selects a non-placeholder account,
  - requires operator confirmation before preparing `lockNative(bytes32 flowchainRecipient, bytes32 metadataHash)`,
  - never defaults a real-funds transfer to `0x5555...5555`,
  - shows live credit status, tx-hash lookup, spendable balance, transfer status, first usable timestamp, and latency,
  - calls `transfer_send` for local FlowChain transfers and renders the machine-readable receipt.
- Added root gate `npm run flowchain:no-secret:scan`.

## How To Use

Start the control-plane:

```powershell
npm run control-plane:serve
```

Start the dashboard against that control-plane:

```powershell
$env:VITE_FLOWCHAIN_CONTROL_PLANE_URL = "http://127.0.0.1:8787"
npm run dev --prefix apps/dashboard
```

Open:

```text
http://127.0.0.1:5173/bridge
```

On `/bridge`:

1. Select an existing non-placeholder account, generate an in-memory FlowChain account, or enter a 32-byte FlowChain account.
2. Confirm the exact recipient shown in the panel.
3. Prepare the `lockNative` call draft. The dashboard does not broadcast it.
4. After a real Base `8453` deposit is observed and credited, use lookup by Base tx hash and then send a local transfer from the credited FlowChain account.

## Readiness Labels

- `LIVE PILOT`: only when running local node/control-plane state has an applied Base `8453` bridge credit to a non-placeholder account.
- `LOCAL ONLY`: the control-plane is local and not externally exposed.
- `NOT READY`: fixture/mock/Base Sepolia/placeholder fallback is visible.

## Evidence

Reports:

- `devnet/local/live-rpc-wallet-dashboard/control-plane-smoke.json`
- `devnet/local/live-rpc-wallet-dashboard/dashboard-control-plane-smoke.json`
- `devnet/local/live-rpc-wallet-dashboard/bridge-credit-lookup-transfer-probe.json`
- `devnet/local/live-rpc-wallet-dashboard/no-secret-scan-report.json`

Observed current state:

- `health.localOnly`: `true`
- `bridge_credit_status.source.runtime`: `live`
- `bridge_credit_status.source.bridge`: `imported`
- `bridge_credit_status.readinessLabel`: `NOT READY`
- `bridge_credit_status.creditedAccount`: placeholder `0x5555...5555`
- `bridge_credit_status.noBaseReleaseBroadcast`: `true`

The transfer receipt path is covered by `services/control-plane/test/control-plane.test.ts` with an applied Base `8453` non-placeholder credit and by `control-plane-smoke.json` for `transfer_send`. The current running state transfer is intentionally blocked because the loaded credit belongs to the placeholder account.

## Checks Run

- `npm test --prefix services/control-plane`: PASS
- `npm test --prefix apps/dashboard`: PASS
- `npm run build --prefix apps/dashboard`: PASS
- `npm run control-plane:smoke --silent`: PASS
- temporary control-plane/dashboard HTTP smoke on `8799`/`5199`: PASS for route and status response, external-blocked for live Base `8453` credit
- `npm run flowchain:no-secret:scan`: PASS
- `git diff --check`: PASS

## Risks And Follow-Ups

- EXTERNAL-BLOCKED: ingest a real Base `8453` lockbox deposit for a non-placeholder FlowChain recipient before claiming `LIVE PILOT`.
- EXTERNAL-BLOCKED: after that ingest, rerun `bridge_credit_get` by tx hash and `transfer_send` from the credited account against the running node state.
- LOCAL ONLY: no external/public RPC exposure was claimed or documented as ready.
- Browser private keys remain out of dashboard storage; the dashboard only creates in-memory recipient IDs and local transfer requests.
