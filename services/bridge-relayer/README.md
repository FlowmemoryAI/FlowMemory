# FlowChain Bridge Relayer POC

Status: fixture-first bridge observer for local/Base Sepolia testing.

This package converts explicit `BaseBridgeLockbox` deposit records into
FlowChain bridge observation JSON. It does not custody funds, sign releases, run
a production relayer, or prove finality.

Local mock:

```powershell
npm run bridge:mock
```

The control plane can read `services/bridge-relayer/out/bridge-observation.json`
and can intake additional local bridge-agent observations through JSON-RPC
`bridge_observation_submit` or HTTP `POST /bridge/observations`. Readbacks are
available through `bridge_observation_list`, `bridge_deposit_list`,
`bridge_credit_list`, and `withdrawal_list`.

Base Sepolia guarded smoke:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-sepolia-smoke.ps1 `
  -RpcUrl <base-sepolia-rpc-url> `
  -LockboxAddress <deployed-lockbox> `
  -FromBlock <from> `
  -ToBlock <to>
```

Base mainnet canary reads are disabled unless the operator explicitly passes
the real-funds acknowledgement and keeps the requested cap at or below 25 USD.

No private key, seed phrase, RPC credential, or API key belongs in this package
or in committed fixtures.
