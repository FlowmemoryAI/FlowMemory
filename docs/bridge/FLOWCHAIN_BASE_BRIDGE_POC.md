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
- `services/bridge-relayer/`: fixture-first observer that converts explicit
  bridge deposit records into FlowChain bridge observation JSON.
- `fixtures/bridge/base-sepolia-mock-deposit.json`: deterministic test deposit.
- `schemas/flowmemory/bridge-deposit.schema.json` and
  `schemas/flowmemory/bridge-observation.schema.json`: bridge object contracts.
- `infra/scripts/bridge-base-sepolia-smoke.ps1`: guarded Base Sepolia smoke.
- `infra/scripts/bridge-base-mainnet-canary-read.ps1`: disabled-by-default
  Base mainnet canary read wrapper.

## Architecture

```text
Base Sepolia user/test wallet
  -> BaseBridgeLockbox.lockERC20 or lockNative
  -> BridgeDeposit event
  -> bridge-relayer explicit reader/mock observer
  -> FlowChain bridge deposit observation fixture
  -> local control plane / workbench / devnet handoff
```

The POC does not mint production assets on FlowChain. Local acceptance is a
fixture/control-plane event until the private/local runtime explicitly consumes
bridge deposit objects.

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
```

Expected output:

```text
services/bridge-relayer/out/bridge-observation.json
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
`25` USD.

## Commands

```powershell
forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol
npm run bridge:test
npm run bridge:mock
git diff --check
```

## Not Production

This POC is not a production bridge, not a bridge launch, not audited, not a
tokenomics system, and not a public user deposit system. It exists so the
private/local FlowChain package can test a Base-origin deposit signal safely.
