# Easy Second-Computer Setup

Status: beginner-first setup path for the FlowChain local/private test package.

This runs a local test package on your computer. It is not production mainnet,
not public validator software, and not a production bridge.

## Install These First

1. Git for Windows
2. Node.js LTS
3. Rust with Cargo
4. Foundry
5. Python 3

## One-Command Setup

Open PowerShell and run:

```powershell
git clone -b release/flowchain-private-testnet https://github.com/FlowmemoryAI/FlowMemory.git
cd FlowMemory
powershell -ExecutionPolicy Bypass -File .\START_FLOWCHAIN_LOCAL.ps1
```

The script installs dependencies, checks prerequisites, initializes local state,
runs the deterministic local chain demo, runs the smoke path, exports a local
bundle, runs the bridge mock, and opens the control plane and dashboard in
separate PowerShell windows.

## Faster Re-Run

After the first successful setup:

```powershell
powershell -ExecutionPolicy Bypass -File .\START_FLOWCHAIN_LOCAL.ps1 -SkipInstall
```

## Skip Server Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\START_FLOWCHAIN_LOCAL.ps1 -NoServers
```

## Useful URLs

- Dashboard/workbench: `http://127.0.0.1:5173/`
- Control plane: `http://127.0.0.1:8675/`

## Bridge Test

The setup script runs a local bridge mock. To run it alone:

```powershell
npm run bridge:mock
npm run bridge:test
forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol
```

Do not use Base mainnet bridge commands until the canary has been reviewed.
