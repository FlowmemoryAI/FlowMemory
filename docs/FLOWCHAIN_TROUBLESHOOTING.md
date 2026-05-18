# FlowChain Troubleshooting

Status: Windows-first troubleshooting guide for the private/local testnet package.

Use this guide when a clean second computer cannot run the current command
path from `docs/FLOWCHAIN_SECOND_COMPUTER_SETUP.md`.

## First Command

On a clean Windows computer, the first path should be the private-repo bootstrap
commands:

```powershell
winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli --exact --source winget --accept-package-agreements --accept-source-agreements
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
gh auth login
gh repo clone FlowmemoryAI/FlowMemory "$env:USERPROFILE\FlowMemory\FlowMemory"
cd "$env:USERPROFILE\FlowMemory\FlowMemory"
powershell -ExecutionPolicy Bypass -File .\INSTALL_FLOWCHAIN_WINDOWS.ps1
```

If the repo is already cloned, run from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\INSTALL_FLOWCHAIN_WINDOWS.ps1
```

To only check installed tools:

```powershell
powershell -ExecutionPolicy Bypass -File .\INSTALL_FLOWCHAIN_WINDOWS.ps1 -CheckOnly
```

## Repo Command Check

From the repo root:

```powershell
npm run flowchain:prereq
npm run flowchain:doctor
```

If that fails, fix the missing prerequisite before running init, demo, smoke,
or workbench commands.

## Common Failures

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `winget is missing` | Windows App Installer is missing or outdated. | Install or update **App Installer** from the Microsoft Store, then rerun `INSTALL_FLOWCHAIN_WINDOWS.ps1`. |
| Raw GitHub installer URL returns `404` | The repo is private, so unauthenticated raw GitHub download is blocked. | Use the private-repo bootstrap commands above or sign into GitHub and download the repo ZIP. |
| `gh` is not recognized | GitHub CLI is missing or PATH is stale after install. | Run the GitHub CLI `winget install` command above, then reopen PowerShell if needed. |
| `gh repo clone` asks for login | The second computer is not authenticated with GitHub. | Run `gh auth login` and choose GitHub.com, HTTPS, and browser login. |
| `git was not found on PATH` | Git for Windows is missing or PowerShell was opened before install. | Install Git for Windows, reopen PowerShell, rerun `npm run flowchain:prereq`. |
| `node` or `npm` missing | Node.js LTS is missing or PATH is stale. | Install Node.js LTS, reopen PowerShell, run `npm install`. |
| `cargo` or `rustc` missing | Rust toolchain is missing. | Install Rust with rustup, reopen PowerShell, run `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml`. |
| `forge is required` | Foundry is missing. | Run `powershell -ExecutionPolicy Bypass -File .\INSTALL_FLOWCHAIN_WINDOWS.ps1`; the installer uses Git Bash for Foundry. |
| Dashboard dependency error | Dashboard deps are separate from root npm workspaces. | Run `npm install --prefix apps/dashboard`. |
| Crypto dependency error during strict prereq | Crypto deps are separate from root npm workspaces. | Run `npm install --prefix crypto`. |
| Workbench does not open | Vite dev server did not start or the port changed. | Run `npm run workbench:dev` again and use the URL printed by Vite. |
| Smoke fails during hardware fixture check | Python is missing or not on PATH. | Install Python 3 or run `npm run flowchain:smoke -- -SkipHardware` for a scoped local smoke. |
| `flowchain:full-smoke` fails with missing command coverage | The full local/private L1 package is not complete yet. | Read `devnet/local/smoke/flowchain-full-smoke-report.json` and the owning issues #99-#108. Use `npm run flowchain:full-smoke -- -SkipMergedSmoke -AllowIncomplete` only to validate the temporary report wrapper. |
| Cargo output looks like a different worktree | A shared `CARGO_TARGET_DIR` is reusing stale binaries. | Use the root wrapper scripts; they pin cargo output to `crates/flowmemory-devnet/target` for this checkout. |
| Cargo cannot overwrite a Windows `.exe` under `target` | A running node, old test process, or stale shell is locking Cargo build output. | Run `npm run flowchain:node:stop`, close old PowerShell windows, and retry. If the lock remains, reboot before deleting ignored local build output. |
| Existing state blocks init | `devnet/local/state.json` already exists. | Run `npm run flowchain:demo`, or force reset with `powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-init.ps1 -Force`. |
| Import refuses to overwrite state | Import protects existing local state by default. | Run `npm run flowchain:import -- --BundlePath <zip> -Force`. |
| Final wrapper says dashboard dependencies are missing | Dashboard package dependencies have not been installed. | Run `npm install --prefix apps/dashboard`. |
| Final wrapper says crypto package dependencies are missing | Crypto package dependencies have not been installed. | Run `npm install --prefix crypto`. |
| Final wrapper reports live readiness `blocked` | Live Base pilot env values are intentionally absent. | Run `npm run flowchain:bridge:live:check` after setting the required env names locally. |
| Final wrapper reports missing strict live proof commands | Contracts, bridge, or runtime proof commands have not merged yet. | Read `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json` and the owner rows for issues #133, #138, and #134. |
| Evidence export refuses a path | The export stage found an excluded or secret-shaped file. | Move env, vault, key, seed phrase, mnemonic, RPC credential, API key, or webhook files outside the evidence source and rerun `npm run flowchain:emergency:export-evidence`. |
| Import root mismatch | Restored state does not match the exported root. | Rerun `npm run flowchain:export`, import to a fresh state path, and inspect `devnet/local/production-l1-e2e/export-import-root-compare.json`. |

## Clean Local Reset

This resets ignored local devnet state. It does not edit committed fixtures.

```powershell
npm run flowchain:stop -- -ResetLocalState
npm run flowchain:init
npm run flowchain:demo
```

## Workbench And Local Service Recovery

The launch demo uses the dashboard as a local workbench. It can run with either
the local control-plane API or deterministic fixture fallback.

### Workbench Loads With Fixture Fallback

This is not automatically a failure. It means the browser did not detect the
local control-plane API at `http://127.0.0.1:8787`.

To switch to local API mode, run in a separate PowerShell window:

```powershell
cd E:\FlowMemory\flowmemory-main
npm run control-plane:serve
```

Refresh the workbench. The banner should change from **Fixture fallback
active.** to **Local API detected.**

### Control Plane Does Not Start

Run the smallest local recovery path:

```powershell
cd E:\FlowMemory\flowmemory-main
npm install
npm run launch:v0
npm test --prefix services/control-plane
npm run control-plane:serve
```

If port `8787` is already in use, inspect it:

```powershell
Get-NetTCPConnection -LocalPort 8787 -ErrorAction SilentlyContinue
```

Close the old PowerShell window that owns the service, or stop the process if
you intentionally started it and no longer need it.

### Port Conflicts

The control plane normally uses `http://127.0.0.1:8787/`, and the workbench
usually uses `http://127.0.0.1:5173/`. If either port is busy:

```powershell
Get-NetTCPConnection -LocalPort 8787 -ErrorAction SilentlyContinue
Get-NetTCPConnection -LocalPort 5173 -ErrorAction SilentlyContinue
```

Close the stale terminal that owns the port. Vite may choose another workbench
port automatically; use the URL printed by `npm run workbench:dev`.

### Workbench Dev Server Does Not Open

Install dashboard dependencies and rerun the wrapper:

```powershell
npm install --prefix apps/dashboard
npm run workbench:dev
```

Use the URL printed by Vite. It is usually `http://127.0.0.1:5173/`, but Vite
may choose another port if `5173` is busy.

### Browser Shows Stale Or Missing Dashboard Data

Refresh generated fixtures and sync the dashboard public copy:

```powershell
npm run launch:v0
npm run flowmemory:canary-dashboard
npm run sync:fixtures --prefix apps/dashboard
npm run workbench:dev
```

Do not refresh live canary data during a demo unless the operator explicitly
approves the RPC endpoint, canary addresses, and small block range.

### Local State Looks Corrupt Or Confusing

Reset ignored local state only:

```powershell
npm run flowchain:stop -- -ResetLocalState
npm run flowchain:init
npm run flowchain:start
npm run flowchain:demo
```

This does not edit committed fixtures.

## Capped Owner Pilot Troubleshooting

Start with the dry-run:

```powershell
npm run flowchain:real-value-pilot:ops
```

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Live pilot says `FLOWCHAIN_PILOT_OPERATOR_ACK` is required | Missing explicit owner acknowledgement. | Set `$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"` in the local shell only. |
| Live pilot reports wrong chain | `FLOWCHAIN_BASE8453_RPC_URL` points to a non-Base endpoint or stale provider route. | Verify the endpoint with the provider, then rerun. The script must see chain id `8453` before live deploy or observer actions. |
| Live observer says the lockbox address is invalid | `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS` is missing, malformed, or from a different deployment. | Use the exact deployed lockbox address for this pilot. The script accepts only a 20-byte hex address. |
| Live observer finds no events | Block range is wrong, the contract is wrong, or the deposit has not been indexed by the RPC provider yet. | Set `FLOWCHAIN_BASE8453_FROM_BLOCK` and `FLOWCHAIN_BASE8453_TO_BLOCK` around the known transaction block, keep the range at `5000` blocks or less, and rerun observe. |
| Replay or duplicate credit evidence appears | The same Base event was observed more than once. | Keep the generated `replayKey` evidence and do not manually credit twice. Rerun `npm run flowchain:real-value-pilot -- --Mode Live --Action Observe` to regenerate deterministic evidence. |
| Pause or resume cannot broadcast | `cast` is missing, the owner key is missing, or the key is not the lockbox owner. | Install Foundry, verify `$env:FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY` in the local shell, and rerun the action. |
| Evidence export refuses a file | The evidence directory contains an env file, local vault, private-key file, build output, or secret-named path. | Move that file outside the evidence directory and rerun `npm run flowchain:real-value-pilot:export`. |

Current ops readiness check:

```powershell
npm run flowchain:bridge:live:check
```

This command refuses missing acknowledgement, missing RPC URL, wrong Base chain
ID, missing or malformed lockbox, missing token address when token mode requires
one, missing or oversized caps, unsafe confirmation depth, and broad block
ranges. It prints env names only.

## Smoke Evidence

After a successful smoke run, check:

```powershell
Get-Content -Raw devnet/local/smoke/flowchain-smoke-report.json
```

The report should show:

- `deterministicReplay` is `true`.
- `launchCandidate`, `devnetTests`, and `serviceTests` are `passed`.
- `cryptoTests` and `cryptoVectors` are `passed`.
- `noSecretExportScan` is `passed`.

The current smoke report also lists blocked lifecycle coverage. Those blocked
rows are expected until the chain, crypto, control-plane, and workbench
workstreams land the remaining native private/local testnet surfaces.

The full-L1 wrapper report is:

```powershell
Get-Content -Raw devnet/local/smoke/flowchain-full-smoke-report.json
```

Until the full workstreams land, it is expected to list missing command
coverage for long-running node, wallet/signing, live control plane, live
workbench, bridge local credit, optional hardware ingestion, and deterministic
full replay. Treat that as the integration checklist, not as passing evidence.

## Secret Hygiene

Do not commit:

- `.env` files.
- RPC URLs or API keys.
- Seed phrases or private keys.
- `devnet/local/`.
- Export bundles that include local operator files.

The export script writes handoff files and scans them for obvious secret
markers. It intentionally does not include `devnet/local/operator.local.json`.

## When To File Or Update An Issue

Update `docs/ISSUE_BACKLOG.md` or open a GitHub issue when:

- A command name changes.
- A wrapper points to a subsystem command that no longer exists.
- The first failing second-computer step changes.
- The smoke report exposes a new blocked lifecycle row.
- A failure requires edits outside the HQ/Ops allowed folders.
