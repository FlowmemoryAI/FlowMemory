# FlowChain Second-Computer Setup

Status: Windows-first setup guide for the private/local testnet milestone.

This guide is intentionally conservative. It names the commands that work in
the merged V0 repo today, what those commands currently prove, and what remains
blocked behind subsystem work.

Correct target:

```text
FlowChain private/local L1 testnet package for second-computer validation.
```

## Prerequisites

For the normal Windows path, do not manually install these first. The root
installer installs or verifies them for the user:

- Git for Windows.
- Node.js LTS with npm.
- Rust toolchain with Cargo.
- Visual Studio Build Tools with the C++ workload, which Rust needs on
  Windows to compile the local devnet crate.
- Foundry.
- Python 3.

Foundry is special on Windows. Foundry's installer does not support PowerShell
directly, so `INSTALL_FLOWCHAIN_WINDOWS.ps1` uses Git Bash for that step after
Git is installed.

Do not put private keys, RPC credentials, API keys, seed phrases, or webhook
URLs in committed files.

## Current Merged Setup Path

This repo is private, so a clean second computer needs GitHub authentication
before it can clone the code. The beginner setup path is:

```powershell
winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli --exact --source winget --accept-package-agreements --accept-source-agreements
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
gh auth login
gh repo clone FlowmemoryAI/FlowMemory "$env:USERPROFILE\FlowMemory\FlowMemory"
cd "$env:USERPROFILE\FlowMemory\FlowMemory"
powershell -ExecutionPolicy Bypass -File .\INSTALL_FLOWCHAIN_WINDOWS.ps1
```

This installs missing tools, clones or updates the repo, wraps the manual
commands below, and opens the control plane and workbench in separate
PowerShell windows.

When `gh auth login` asks questions, use GitHub.com, HTTPS, and browser login.

Use this path today on a clean second computer. It validates the merged V0
launch-core, no-value local devnet prototype, dashboard workbench, hardware
simulator fixture, bridge mock, control-plane fixture API, and Windows wrapper
layer. It does not yet prove the full long-running node, wallet signing,
native AgentAccount, ModelPassport, MemoryCell, Challenge, FinalityReceipt,
live control-plane, bridge local-credit, or live workbench lifecycle.

If the repo is already cloned, run from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\INSTALL_FLOWCHAIN_WINDOWS.ps1
```

## Manual Developer Path

Use this only when intentionally installing tools yourself or debugging the
installer.

Clone and install:

```powershell
git clone https://github.com/FlowmemoryAI/FlowMemory.git
cd FlowMemory
npm install
```

Install dashboard and crypto package dependencies when running the full
second-computer smoke path:

```powershell
npm install --prefix apps/dashboard
npm install --prefix crypto
```

Check prerequisites:

```powershell
npm run flowchain:prereq
```

Initialize local state and the ignored local-only operator file:

```powershell
npm run flowchain:init
```

Start the current bounded local stack:

```powershell
npm run flowchain:start
```

Run the deterministic demo and export state:

```powershell
npm run flowchain:demo
npm run flowchain:export
```

Run the full merged-surface smoke path:

```powershell
npm run flowchain:smoke
```

Check the full private/local L1 gate status:

```powershell
npm run flowchain:full-smoke -- -AllowIncomplete
```

This command writes
`devnet/local/smoke/flowchain-full-smoke-report.json`. It is expected to report
missing subsystem command coverage until issues #99 through #105 land. Without
`-AllowIncomplete`, it exits nonzero while the full local L1 package remains
incomplete.

Run the local workbench in a separate PowerShell window:

```powershell
npm run workbench:dev
```

Stop the current bounded local stack when done:

```powershell
npm run flowchain:stop
```

The workbench command prints the local URL. It usually uses
`http://127.0.0.1:5173/`. Press `Ctrl+C` in the workbench PowerShell window to
stop the Vite dev server.

Expected current result:

- `npm run flowchain:init` writes deterministic local state under
  `devnet/local/state.json` and a local-only operator file under
  `devnet/local/operator.local.json`.
- `npm run flowchain:start` regenerates launch-core fixtures and records
  bounded stack status under `devnet/local/flowchain-stack-status.json`.
- `npm run flowchain:demo` writes deterministic local block/state output.
- `npm run flowchain:export` writes ignored export files and a zip bundle under
  `devnet/local/export/`.
- `npm run flowchain:smoke` writes
  `devnet/local/smoke/flowchain-smoke-report.json` and compares deterministic
  replay roots.
- `npm run flowchain:full-smoke -- -AllowIncomplete` writes
  `devnet/local/smoke/flowchain-full-smoke-report.json` and names missing
  command coverage with owning issue numbers.
- `npm run workbench:dev` opens the existing dashboard as the local workbench.

Current stop point: if a second computer needs long-running node behavior,
signed transaction intake, encrypted key storage, native AgentAccount,
ModelPassport, MemoryCell, Challenge, FinalityReceipt, bridge local credits,
or full live workbench inspection of those entities, that is still the
private/local testnet package target owned by issues #99 through #108.

## Final Second-Computer Path

When the package is complete, a beginner should be able to run this exact shape
from a clean clone:

```powershell
git clone https://github.com/FlowmemoryAI/FlowMemory.git
cd FlowMemory
npm install
npm install --prefix apps/dashboard
npm install --prefix crypto
npm run flowchain:prereq
npm run flowchain:init
npm run flowchain:start
npm run control-plane:serve
npm run workbench:dev
npm run flowchain:full-smoke
npm run flowchain:export
```

If `flowchain:start`, `control-plane:serve`, or `workbench:dev` are
long-running commands, run each one in its own PowerShell window and run
`flowchain:full-smoke` from a fourth window after the services are healthy.

If final command names differ, this guide must be updated in the same PR that
adds the commands. The final path must still include prerequisite checks,
initialization, runtime start, control-plane serve, workbench dev, full smoke,
and export/import or snapshot behavior.

## Target One-Command Path

The final package should provide these root-level commands or documented
equivalents:

```powershell
npm run flowchain:prereq
npm run flowchain:init
npm run flowchain:start
npm run flowchain:stop
npm run flowchain:demo
npm run flowchain:smoke
npm run flowchain:full-smoke
npm run flowchain:export
npm run control-plane:serve
npm run workbench:dev
```

Current status:

| Target command | Status | Current fallback |
| --- | --- | --- |
| `npm run flowchain:prereq` | Implemented | `infra/scripts/flowchain-check-prereqs.ps1` |
| `npm run flowchain:init` | Implemented | `infra/scripts/flowchain-init.ps1` |
| `npm run flowchain:start` | Implemented bounded wrapper | Long-running node behavior remains missing. |
| `npm run flowchain:stop` | Implemented bounded wrapper | Use `npm run flowchain:stop -- -ResetLocalState` for an explicit reset. |
| `npm run flowchain:demo` | Implemented | Wraps the existing Rust devnet `demo`. |
| `npm run flowchain:smoke` | Implemented for merged surfaces | Native object/control-plane smoke coverage remains missing. |
| `npm run flowchain:full-smoke` | Temporary blocker-report wrapper | Runs merged smoke unless skipped, writes `devnet/local/smoke/flowchain-full-smoke-report.json`, and exits nonzero until #99-#105 command coverage lands. |
| `npm run flowchain:export` | Implemented | Writes ignored export directory and zip bundle. |
| `npm run flowchain:import -- --BundlePath <zip> -Force` | Implemented script path | Restores local state from an exported bundle. |
| `npm run control-plane:serve` | Implemented fixture-backed API | Live node adapters and transaction submission remain #101. |
| `npm run workbench:dev` | Implemented | Wraps `npm run dev --prefix apps/dashboard`. |

## Local Operator Keys

Second-computer validation needs local operator identity, but the merged repo
does not yet include a production wallet or encrypted operator vault.

Current wrapper behavior:

- `npm run flowchain:init` writes `devnet/local/operator.local.json`.
- The file is ignored by git through `devnet/local/`.
- The file is for private/local validation only and must not be committed.
- To import an existing local-only operator file, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-init.ps1 -ImportOperatorKeyPath <path-to-local-operator-json> -Force
```

Acceptance target:

- Generate or import local operator, agent, verifier, and optional hardware
  signal keys.
- Store private key material outside committed fixtures.
- Prefer an encrypted local vault or platform keystore-backed file.
- Make lock, unlock, import, export, rotate, and corrupt-vault states explicit.
- Keep public state reconstructable without private secrets.

Until that exists, do not claim wallet support or value-bearing key management.

## Private Genesis And Runtime

The current devnet starts from deterministic local state and writes default
state under:

```text
devnet/local/state.json
```

`devnet/local/` is ignored by git.

Private/local testnet acceptance requires a documented genesis/config flow that
can be rerun on a clean machine. The flow must say which files are generated,
which files can be committed as fixtures, and which files are local-only.

## Control Plane

The target package needs a documented local API for health, chain status,
blocks, transactions, agents, models, receipts, artifacts, verifier reports,
challenges, finality, memory cells, provenance, and raw JSON.

Active Local Alpha work defines a fixture-backed JSON-RPC control plane under
`services/control-plane/`, but that work is not merged in the current source of
truth yet.

Expected command once merged:

```powershell
npm run control-plane:serve
```

The API must not return secrets.

## Workbench

The workbench must extend the existing dashboard in `apps/dashboard/`.

Current command:

```powershell
npm run dev --prefix apps/dashboard
```

Target command:

```powershell
npm run workbench:dev
```

The first screen should be the usable local workbench, not a marketing page.
It should show local/private testnet state or deterministic fixtures with clear
local-only labels.

## Troubleshooting Checklist

Full guide: `docs/FLOWCHAIN_TROUBLESHOOTING.md`.

If setup fails on a second computer, check:

- `git status --short --branch` is clean after clone.
- Node and npm are available in the current PowerShell.
- Rust and Cargo are available in the current PowerShell.
- Foundry is installed if `npm run launch:candidate` fails during contract hardening.
- Dashboard dependencies were installed with `npm install --prefix apps/dashboard`.
- Crypto package dependencies were installed with `npm install --prefix crypto`
  before `npm run flowchain:smoke`.
- No `.env`, private key, RPC URL, or local vault file was committed.
- Generated state under `devnet/local/` can be deleted and recreated with `init`
  when local testing needs a clean reset.

## Completion Rule

This setup guide is complete for the HQ/Ops wrapper layer. The overall
private/local testnet package is complete only when the target one-command path
runs the full native-object smoke flow on a clean second computer, proves
control-plane and workbench coverage, and replays deterministically.
