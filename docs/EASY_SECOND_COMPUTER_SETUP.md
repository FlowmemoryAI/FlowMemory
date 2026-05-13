# Easy Second-Computer Setup

Status: beginner-first setup path for the FlowChain local/private test package.

This runs a local test package on your computer. It is not production mainnet,
not public validator software, and not a production bridge.

## Install These First

Nothing manually for the normal Windows path.

The root installer installs or verifies:

1. Git for Windows
2. Node.js LTS with npm
3. Python 3
4. Rust with Cargo
5. Foundry

Foundry is installed through Git Bash because Foundry's Windows installer does
not support PowerShell directly.

## Beginner Setup For This Private Repo

This repo is private. A clean second computer cannot download the installer
from the public raw GitHub URL until it has signed into GitHub.

Open PowerShell and run these lines:

```powershell
winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli --exact --source winget --accept-package-agreements --accept-source-agreements
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
gh auth login
gh repo clone FlowmemoryAI/FlowMemory "$env:USERPROFILE\FlowMemory\FlowMemory"
cd "$env:USERPROFILE\FlowMemory\FlowMemory"
powershell -ExecutionPolicy Bypass -File .\INSTALL_FLOWCHAIN_WINDOWS.ps1
```

When `gh auth login` asks questions, use GitHub.com, HTTPS, and browser login.
Windows may ask for permission while tools install. Click **Yes** if prompted.

The installer downloads this repo, installs dependencies, checks prerequisites,
initializes local state, runs the deterministic local chain demo, runs the smoke
path, exports a local bundle, runs the bridge mock, and opens the control plane
and dashboard in separate PowerShell windows.

## Already Cloned Setup

If the repo is already cloned:

```powershell
powershell -ExecutionPolicy Bypass -File .\INSTALL_FLOWCHAIN_WINDOWS.ps1
```

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
- Control plane: `http://127.0.0.1:8787/`

## Bridge Test

The setup script runs a local bridge mock. To run it alone:

```powershell
npm run bridge:mock
npm run bridge:test
forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol
```

Do not use Base mainnet bridge commands until the canary has been reviewed.
