# FlowMemory Launch Demo Runbook

Status: beginner-safe launch demo script for the current V0 local/private and
guarded canary surfaces.

This runbook is for showing what exists today without overclaiming. It covers:

- the FlowChain private/local no-value workbench;
- the generated FlowMemory V0 dashboard fixtures;
- the guarded Base canary review route at `/canary`.

It is not a production runbook, production mainnet announcement, token launch,
public validator guide, production verifier-network guide, production bridge
guide, or audited-cryptography statement.

## One-Sentence Demo Frame

Use this at the start:

```text
This is FlowMemory V0: a local/private no-value FlowChain package and dashboard
workbench, plus a guarded Base canary review from known canary contracts. It
shows FlowPulse observations, Rootflow transitions, verifier/report state, and
operator evidence without claiming production readiness.
```

## What This Demo Proves

- A beginner can run the current local package from the repo root.
- The local devnet can initialize deterministic no-value state and produce demo
  output.
- The workbench can inspect local fixture state and, when started, the local
  control-plane API.
- The canary route can review committed Base canary reader output separately
  from local/private fixtures.
- The dashboard makes provenance, status, and boundaries visible instead of
  hiding them in raw JSON.

## What This Demo Does Not Prove

Do not claim:

- production readiness;
- mainnet readiness;
- a production L1;
- public validator readiness;
- tokenomics, token launch, or real-funds faucet behavior;
- production bridge readiness;
- production Uniswap v4 hook deployment;
- fully trustless verifier network;
- audited cryptography;
- AI, model weights, media, or heavy memory data stored on-chain;
- FlowRouter hardware manufacturing, certification, or field deployment.

Safe language:

- "local/private no-value validation";
- "fixture-backed workbench";
- "guarded Base canary review";
- "FlowPulse observations";
- "Rootflow transition model";
- "commitments, receipts, roots, and verifier reports";
- "source-verified current canary addresses, not production approval."

## Pre-Demo Setup

Run from the repo root:

```powershell
cd E:\FlowMemory\flowmemory-main
git fetch --all --prune
git status --short --branch
npm install
npm install --prefix apps/dashboard
npm install --prefix crypto
npm run flowchain:prereq
```

Expected result:

- `git status --short --branch` shows the intended branch and no unexpected
  dirty files.
- `flowchain:prereq` lists Git, Node.js, npm, Rust/Cargo, MSVC build tools,
  Foundry, and dependency install state.
- Missing dependencies are fixed before the demo starts.

For a full launch-day gate, run:

```powershell
npm run flowchain:full-smoke
```

Expected output files:

```text
devnet/local/smoke/flowchain-smoke-report.json
devnet/local/full-smoke/flowchain-full-smoke-report.json
```

If full smoke cannot run on the demo computer, say exactly which prerequisite or
step is missing. Do not replace it with "works locally."

## Generate Demo State

Run:

```powershell
npm run flowchain:init
npm run flowchain:start
npm run flowchain:demo
npm run flowchain:export
```

What each command does:

| Command | Meaning |
| --- | --- |
| `npm run flowchain:init` | Writes deterministic local state under `devnet/local/state.json` and a local-only operator file under `devnet/local/operator.local.json`. |
| `npm run flowchain:start` | Prepares launch-core fixtures, inspects local state, and writes bounded local stack status. This is not a daemon. |
| `npm run flowchain:demo` | Runs the deterministic no-value local demo and writes handoff output under `devnet/local/handoff/generated/`. |
| `npm run flowchain:export` | Writes local export files and a zip bundle under `devnet/local/export/` without including the local operator file. |

## Start The Services For The Browser Demo

Use two PowerShell windows.

Window 1, optional but recommended:

```powershell
cd E:\FlowMemory\flowmemory-main
npm run control-plane:serve
```

Expected local API:

```text
http://127.0.0.1:8787
```

Window 2:

```powershell
cd E:\FlowMemory\flowmemory-main
npm run workbench:dev
```

Open the Vite URL printed by the command. It is usually:

```text
http://127.0.0.1:5173/
```

If Vite chooses a different port, use the printed URL.

## Browser Click Script

### 1. Workbench

Open:

```text
http://127.0.0.1:5173/
```

Or click **Workbench** in the left nav.

Say:

```text
This is the local operator workbench. It checks the local control-plane API at
127.0.0.1:8787 and falls back to deterministic fixtures when the API is not
running. The fallback is intentional for demos; it is not pretending to be a
hosted production service.
```

Check the banner under the top bar:

- **Local API detected.** The workbench is reading the local API where
  available.
- **Fixture fallback active.** The control-plane service was not detected and
  the workbench is showing deterministic committed fixtures.

Main Workbench panels:

| Panel | What it means |
| --- | --- |
| Node and API status | Current local chain/API health, block height, state root, pending transaction count, and API URL. If it says offline, the dashboard is still usable in fixture fallback mode. |
| Local setup path | The beginner command sequence the operator should run: install, launch candidate, start, smoke, and open workbench. |
| Control-plane endpoints and local actions | Endpoints advertised or probed from the local API. Browser action buttons only appear when the API advertises matching safe POST endpoints. |
| Workbench coverage metrics | Counts for data source, node views, chain objects, smoke objects, and open challenges in the current source. |
| Object switcher | Clickable object views for Node Status, Peers, Blocks, Transactions, Mempool, Accounts, Balances, Faucet Events, Wallet Metadata, Rootfields, Agents, Models, Work Receipts, Memory Cells, Artifacts, Verifier Modules, Verifier Reports, Challenges, Finality, bridge test objects, Provenance / Source, Hardware Signals, and Raw JSON. |
| Record grid | The records for the selected object view, including status, facts, and provenance. |
| Boundary notes | Reminder that this is one local workbench surface, not a second dashboard or production system. |

What to click:

1. Click **Node Status** in the object switcher and point out the state root,
   chain id, API URL, and provenance.
2. Click **Blocks** and **Transactions** to show deterministic local chain
   objects.
3. Click **Agents**, **Models**, **Work Receipts**, **Verifier Reports**,
   **Memory Cells**, **Challenges**, and **Finality** to show the local object
   lifecycle.
4. Click **Wallet Metadata** and say it is public metadata only. The browser
   does not ask for private keys.
5. Click **Bridge Deposits**, **Bridge Credits**, and **Bridge Withdrawals** and
   say these are private/local bridge-shaped test objects only.
6. Click **Provenance / Source** to show where the data came from.
7. Click **Raw JSON** only if a reviewer asks for the payload underneath the UI.

If local action buttons appear, describe them as optional browser-safe local API
actions. Do not promise they will appear on every machine.

### 2. Overview

Click **Overview** or open:

```text
http://127.0.0.1:5173/overview
```

Panels:

| Panel | What it means |
| --- | --- |
| Metric tiles | Counts and status for the generated V0 fixture stack. |
| Recent FlowPulse observations | The latest observed FlowPulse-style records with receipt-derived transaction/log metadata. |
| Verifier attention | Reports that need review, or an empty state when fixture reports are verified. |
| Hardware risk | FlowRouter POC heartbeat records that are stale or risky in fixtures. Hardware is optional for this demo. |
| Devnet block window | Deterministic local block and state-root view. |

Say:

```text
FlowPulse is the observation spine. Contracts emit compact events; indexers and
verifiers derive receipt facts such as transaction hash and log index after the
receipt exists.
```

### 3. Flow Memory / Rootflow

Click **Flow Memory** or open:

```text
http://127.0.0.1:5173/flowmemory
```

Say:

```text
This view turns observations, verifier reports, and roots into Flow Memory V0
objects: MemorySignals, MemoryReceipts, RootfieldBundles,
AgentMemoryViews, and RootflowTransitions.
```

Use this view to show parent/child state transitions and status vocabulary:

```text
observed, pending, finalized, verified, unresolved, failed, unsupported,
reorged, offline, stale
```

### 4. FlowPulse And Rootfields

Click **FlowPulse**:

```text
http://127.0.0.1:5173/flowpulse
```

Then click **Rootfields**:

```text
http://127.0.0.1:5173/rootfields
```

Say:

```text
Rootfields are namespaces and compact commitment state. They are not unlimited
storage, and metadata/evidence URIs are pointers or arbitrary log strings, not
raw model or artifact storage.
```

### 5. Work Lanes, Verifier, Devnet, Hardware, Alerts

Click these only if time allows:

| Route | What to show |
| --- | --- |
| `/work` | Work lanes and receipt status. |
| `/verifier` | Verifier reports and reason codes. These are local/test reports, not a production verifier network. |
| `/devnet` | Deterministic no-value local blocks and roots. |
| `/hardware` | FlowRouter POC heartbeat/control-signal records. This is not manufactured or field-deployed hardware. |
| `/alerts` | Operator warnings and recommended local actions. |

### 6. Base Canary

Click **Base canary** or open:

```text
http://127.0.0.1:5173/canary
```

Say:

```text
This route is intentionally separate from local fixture mode. It reviews a
guarded Base canary read over known V0 canary addresses and a small explicit
block range. It is visible on Base, but it is still a canary, not production
approval.
```

Current committed canary fixture summary:

| Field | Current value |
| --- | --- |
| Chain id | `8453` |
| Read window | `45955500` to `45955540` |
| Canary FlowPulse observations | `4` |
| Rootfields | `1` |
| Rootflow transitions | `4` |
| Rejected logs | `0` |
| Duplicates | `0` |
| Contracts in canary artifact | `10` |

Canary panels:

| Panel | What it means |
| --- | --- |
| Canary boundary hero | The high-level warning: visible on Base, still gated for production. |
| Reader command / review fixture / hard boundary strip | The exact reader shape, runtime fixture path, and no broad scan/no production/no real-funds boundary. |
| Canary metrics | Counts from the committed canary fixture, including rejected logs and duplicates. |
| Canary FlowPulse stream | The observed canary logs with block, pulse type, transaction hash, and log index. |
| FlowPulse contracts | Canary contracts that emitted FlowPulse logs in the review fixture. |
| Launch gates | Boundaries that remain before any production claim. |
| Canary Rootflow state | Rootflow transitions reconstructed from the canary observations. |
| Canary JSON | Full loaded canary dashboard payload for reviewer inspection. |

If someone asks how to refresh canary data, show the documented command but do
not run it unless the operator explicitly wants a live read and has approved the
RPC endpoint and block range:

```powershell
npm run index:base-canary -- --acknowledge-mainnet-canary --rpc-url https://mainnet.base.org --address 0x2a7ADd68a1d45C3251E2F92fFe4926124654a97C --address 0x179Df6d52e9DeF5D02704583a2E4E5a9FF427245 --from-block 45955500 --to-block 45955540 --finalized-block 45955540
npm run flowmemory:canary-dashboard
```

Boundary to say out loud:

```text
The guarded reader refuses broad scans and marks checkpoint output as not
production-ready. The canary dashboard data is review evidence, not a
production service.
```

## Recovery During A Live Demo

### Workbench Opens But Says Fixture Fallback

This is acceptable. Say:

```text
The local API is not detected, so the dashboard is showing deterministic
fixtures. That is an intended fallback path.
```

To recover live local API mode, start another PowerShell window:

```powershell
cd E:\FlowMemory\flowmemory-main
npm run control-plane:serve
```

Refresh the browser. The banner should change to **Local API detected.**

### Control Plane Fails To Start

Run:

```powershell
cd E:\FlowMemory\flowmemory-main
npm install
npm run launch:v0
npm test --prefix services/control-plane
npm run control-plane:serve
```

If the port is already in use:

```powershell
Get-NetTCPConnection -LocalPort 8787 -ErrorAction SilentlyContinue
```

Close the old PowerShell window that owns the service, or stop that process if
you intentionally started it and no longer need it.

### Workbench Does Not Open

Run:

```powershell
npm install --prefix apps/dashboard
npm run workbench:dev
```

Use the URL printed by Vite. If the browser is stale, refresh the page. If the
dev server is wedged, press `Ctrl+C` in the workbench window and rerun the
command.

### Local State Looks Wrong

Reset only ignored local devnet state:

```powershell
npm run flowchain:stop -- -ResetLocalState
npm run flowchain:init
npm run flowchain:start
npm run flowchain:demo
```

This does not edit committed fixtures.

### Canary Route Does Not Load

Refresh dashboard fixtures:

```powershell
npm run flowmemory:canary-dashboard
npm run sync:fixtures --prefix apps/dashboard
npm run workbench:dev
```

If the canary JSON is stale, say it is the committed canary review fixture and
point to:

```text
docs/DEPLOYMENTS/2026-05-13-base-canary-v0.md
```

Do not invent a newer canary status.

## Launch-Day Checklist

### Before The Demo

- Confirm the intended branch and clean state:

```powershell
git fetch --all --prune
git status --short --branch
```

- Check GitHub state:

```powershell
gh pr list --repo FlowmemoryAI/FlowMemory --state open
gh issue list --repo FlowmemoryAI/FlowMemory --state open --limit 80
```

- Run the acceptance gate when prerequisites are present:

```powershell
npm run flowchain:full-smoke
```

- Generate demo state:

```powershell
npm run flowchain:init
npm run flowchain:start
npm run flowchain:demo
npm run flowchain:export
```

- Start local API and workbench in separate windows:

```powershell
npm run control-plane:serve
```

```powershell
npm run workbench:dev
```

- Open these browser routes:

```text
http://127.0.0.1:5173/
http://127.0.0.1:5173/overview
http://127.0.0.1:5173/flowmemory
http://127.0.0.1:5173/canary
http://127.0.0.1:5173/raw
```

### During The Demo

- Keep private keys, seed phrases, RPC credentials, API keys, and webhook URLs
  off screen.
- Use the exact framing from this runbook.
- If a reviewer asks what is live, distinguish local/private runtime state,
  deterministic fixtures, and committed canary reader output.
- If a reviewer asks whether it is production-ready, answer "no."
- If a reviewer asks whether the canary is on Base, answer "yes, as a guarded
  V0 canary deployment for testing only."
- If a command fails, capture the first failing command and use
  `docs/FLOWCHAIN_TROUBLESHOOTING.md`.

### After The Demo

Stop local windows with `Ctrl+C`, then record stopped state:

```powershell
npm run flowchain:stop
```

Capture handoff evidence:

```powershell
Get-Content -Raw devnet/local/smoke/flowchain-smoke-report.json
Get-Content -Raw devnet/local/full-smoke/flowchain-full-smoke-report.json
git status --short --branch
```

End the handoff with:

- what was shown;
- commands run;
- whether full smoke passed or why it was skipped;
- any failure and first failing command;
- risks, assumptions, and follow-ups.

