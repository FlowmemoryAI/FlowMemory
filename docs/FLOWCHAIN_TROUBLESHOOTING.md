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
| Existing state blocks init | `devnet/local/state.json` already exists. | Run `npm run flowchain:demo`, or force reset with `powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-init.ps1 -Force`. |
| Import refuses to overwrite state | Import protects existing local state by default. | Run `npm run flowchain:import -- --BundlePath <zip> -Force`. |

## Clean Local Reset

This resets ignored local devnet state. It does not edit committed fixtures.

```powershell
npm run flowchain:stop -- -ResetLocalState
npm run flowchain:init
npm run flowchain:demo
```

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
