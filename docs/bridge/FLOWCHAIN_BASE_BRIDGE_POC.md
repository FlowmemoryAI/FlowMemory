# FlowChain Base Bridge POC

Status: test-only bridge lane for local and Base Sepolia validation.

This bridge POC is designed so a small canary can be reviewed later without
claiming production bridge readiness. It is not audited, not trustless, not a
public bridge, and not approved for broad mainnet use.

## What Exists

- `contracts/bridge/BaseBridgeLockbox.sol`: non-upgradeable lockbox with owner,
  pause, allowlisted tokens, per-deposit caps, total caps, deposit events, and
  owner-only release helpers.
- `tests/bridge/BaseBridgeLockbox.t.sol`: Foundry coverage for token
  allowlisting, ERC-20 deposits, native deposits, caps, pause behavior,
  ownership, release, and replay protection.
- `services/bridge-relayer/`: fixture-first and RPC-range observer that
  converts explicit bridge deposit records into FlowChain bridge observation,
  credit, withdrawal-intent, and runtime handoff JSON.
- `fixtures/bridge/base-sepolia-mock-deposit.json`: deterministic test deposit.
- `fixtures/bridge/local-runtime-bridge-handoff.json`: deterministic local
  bridge handoff consumed by the runtime/control-plane agent until a direct
  intake endpoint is merged.
- `schemas/flowmemory/bridge-deposit.schema.json` and
  `schemas/flowmemory/bridge-observation.schema.json`: bridge object contracts.
- `schemas/flowmemory/bridge-credit.schema.json`,
  `schemas/flowmemory/bridge-withdrawal-intent.schema.json`, and
  `schemas/flowmemory/bridge-runtime-handoff.schema.json`: canonical local
  credit, test withdrawal-intent, and handoff contracts.
- `infra/scripts/bridge-base-sepolia-observe.ps1`: env-friendly Base Sepolia
  observation wrapper that requires no private key.
- `infra/scripts/bridge-base-sepolia-smoke.ps1`: guarded Base Sepolia smoke.
- `infra/scripts/bridge-local-anvil-observe.ps1`: local Anvil observation
  wrapper for chain id `31337`.
- `infra/scripts/bridge-base-mainnet-canary-read.ps1`: disabled-by-default
  Base mainnet canary read wrapper.

## Architecture

```text
Base Sepolia user/test wallet
  -> BaseBridgeLockbox.lockERC20 or lockNative
  -> BridgeDeposit event
  -> bridge-relayer explicit reader/mock observer
  -> BridgeObservation with replay key
  -> BridgeCredit pending/applied local object
  -> local runtime/control-plane/workbench handoff
```

The POC does not mint production assets on FlowChain. Local acceptance is a
fixture/control-plane event until the private/local runtime explicitly consumes
bridge deposit objects.

The handoff includes a workbench-ready timeline:

```text
deposit observed -> credit pending -> credit applied -> withdrawal requested
```

The current workbench/control-plane packages are outside this bridge-agent
scope. Until their bridge intake lands, `fixtures/bridge/local-runtime-bridge-handoff.json`
is the exact file for the runtime/control-plane agent to consume.

## Risk Model

- Base mainnet uses real funds. Mainnet canary reads require
  `--acknowledge-real-funds` and `--max-usd 25` or lower.
- The lockbox owner can pause and release funds. That is a test operator model,
  not a decentralized bridge model.
- The relayer reads explicit chains, contracts, and block ranges. It must not
  broad-scan Base mainnet.
- No secrets, RPC keys, private keys, or seed phrases should be committed.
- Bridge observations are advisory local objects until the FlowChain runtime
  verifies and accepts them.

## Local Mock

```powershell
npm install
npm run bridge:mock
npm run bridge:test
npm run bridge:local-credit:smoke
```

Expected output:

```text
services/bridge-relayer/out/bridge-observation.json
services/bridge-relayer/out/bridge-credit.json
services/bridge-relayer/out/bridge-runtime-handoff.json
fixtures/bridge/local-runtime-bridge-handoff.json
```

## Base Sepolia Smoke

Deploy the lockbox with Foundry or a deployment script, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-sepolia-smoke.ps1 `
  -RpcUrl <base-sepolia-rpc-url> `
  -LockboxAddress <deployed-lockbox> `
  -FromBlock <from> `
  -ToBlock <to>
```

The script checks Base Sepolia chain id `84532`, requires an explicit lockbox,
requires an explicit block range, and writes a local observation output.

The root package also exposes an env-var smoke path that does not require a
private key:

```powershell
$env:BASE_SEPOLIA_RPC_URL="<base-sepolia-rpc-url>"
$env:BASE_BRIDGE_LOCKBOX_ADDRESS="<deployed-lockbox>"
$env:BASE_BRIDGE_FROM_BLOCK="<from>"
$env:BASE_BRIDGE_TO_BLOCK="<to>"
npm run bridge:sepolia:observe
```

This command reads only `BridgeDeposit` logs from the explicit lockbox and
range, then writes observation, credit, and handoff JSON under
`services/bridge-relayer/out/`.

## Local Anvil Observation

Local Anvil is supported as a mock Base event lane with chain id `31337`.
Deploy `BaseBridgeLockbox`, emit one or more deposits, then run:

```powershell
$env:ANVIL_BRIDGE_LOCKBOX_ADDRESS="<deployed-lockbox>"
$env:ANVIL_BRIDGE_FROM_BLOCK="<from>"
$env:ANVIL_BRIDGE_TO_BLOCK="<to>"
npm run bridge:anvil:observe
```

Use `-RpcUrl` or `ANVIL_RPC_URL` if the Anvil endpoint is not
`http://127.0.0.1:8545`.

## Base Mainnet Canary Read

Only after review, and only for a tiny capped canary:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-mainnet-canary-read.ps1 `
  -RpcUrl <base-mainnet-rpc-url> `
  -LockboxAddress <deployed-lockbox> `
  -FromBlock <from> `
  -ToBlock <to> `
  -AcknowledgeRealFunds `
  -MaxUsd 20
```

The script checks Base mainnet chain id `8453` and refuses a canary above
`25` USD. It is read-only and prints the chain, lockbox, block range, max USD
guardrail, and broadcast status before it reads logs.

## Commands

```powershell
forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol
npm run bridge:test
npm run bridge:mock
npm run bridge:sepolia:observe
npm run bridge:local-credit:smoke
npm run flowchain:full-smoke
git diff --check
```

## Not Production

This POC is not a production bridge, not a bridge launch, not audited, not a
tokenomics system, and not a public user deposit system. It exists so the
private/local FlowChain package can test a Base-origin deposit signal safely.
