# FlowChain Bridge Relayer POC

Status: fixture-first bridge observer for local/Base Sepolia testing.

This package converts explicit `BaseBridgeLockbox` deposit records into
FlowChain bridge observation, credit, withdrawal-intent, and local runtime
handoff JSON. It does not custody funds, sign releases, run a production
relayer, or prove finality.

Local mock:

```powershell
npm run bridge:mock
```

Local credit smoke:

```powershell
npm run bridge:local-credit:smoke
```

This writes the current runtime-agent handoff file:

```text
fixtures/bridge/local-runtime-bridge-handoff.json
```

Base Sepolia guarded smoke:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-sepolia-smoke.ps1 `
  -RpcUrl <base-sepolia-rpc-url> `
  -LockboxAddress <deployed-lockbox> `
  -FromBlock <from> `
  -ToBlock <to>
```

Base Sepolia observation from root package env vars:

```powershell
$env:BASE_SEPOLIA_RPC_URL="<base-sepolia-rpc-url>"
$env:BASE_BRIDGE_LOCKBOX_ADDRESS="<deployed-lockbox>"
$env:BASE_BRIDGE_FROM_BLOCK="<from>"
$env:BASE_BRIDGE_TO_BLOCK="<to>"
npm run bridge:sepolia:observe
```

No private key is required. The command reads `BridgeDeposit` logs over an
explicit block range and writes observation, credit, and handoff JSON under
`services/bridge-relayer/out/`.

Local Anvil observation uses the same log decoder with chain id `31337`:

```powershell
$env:ANVIL_BRIDGE_LOCKBOX_ADDRESS="<deployed-lockbox>"
$env:ANVIL_BRIDGE_FROM_BLOCK="<from>"
$env:ANVIL_BRIDGE_TO_BLOCK="<to>"
npm run bridge:anvil:observe
```

Base mainnet canary reads are disabled unless the operator explicitly passes
the real-funds acknowledgement and keeps the requested cap at or below 25 USD.

No private key, seed phrase, RPC credential, or API key belongs in this package
or in committed fixtures.
