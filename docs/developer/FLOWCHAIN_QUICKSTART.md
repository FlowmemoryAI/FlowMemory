# FlowChain Developer Quickstart

Status: local/private developer quickstart. This is not a public production RPC
or live bridge launch guide.

## Prerequisites

- Windows PowerShell.
- Node.js and npm.
- Rust toolchain for the local devnet runtime.
- A clean checkout with dependencies installed.

## Start Or Attach To Local RPC

From the repository root:

```powershell
npm run flowchain:service:status -- -AllowBlocked
```

If the service is stopped:

```powershell
npm run flowchain:service:start -- -LiveProfile
```

The local developer RPC defaults to:

```text
http://127.0.0.1:8787/rpc
```

Do not expose this endpoint publicly. Public exposure must go through the public
deployment contract, TLS, CORS, rate limits, backup proof, bridge readiness, and
tester packet gates.

## Discover The RPC

```powershell
npm run flowchain:devkit -- discover --json
```

## Check Readiness

```powershell
npm run flowchain:devkit -- readiness --json
```

For local development, readiness should show `localOnly=true`,
`productionReady=false`, and exact missing owner input names for public RPC and
Base 8453 bridge configuration.

## Read Chain Status

```powershell
npm run flowchain:devkit -- status --json
```

The chain is locally alive when `nodeRunning=true` and `currentBlock` advances
between checks.

## Read Wallet Activity

```powershell
npm run flowchain:devkit -- wallet-balances --json --limit 5
npm run flowchain:devkit -- wallet-transfers --json --limit 5
```

These commands read the actual control-plane RPC. They do not return private
keys, seed phrases, mnemonics, passphrases, or vault material.

## Send A Local Wallet Transfer

Choose two local no-value account IDs from `wallet-balances`, then submit a
runtime-backed local transfer:

```powershell
npm run flowchain:devkit -- wallet-send --json --from <account-id> --to <account-id> --amount-units 1 --memo devkit-local-test
```

This uses the local control-plane wallet send path. It is for local no-value
testing only and is not a live bridge or public endpoint action.

## Read Bridge Readiness

```powershell
npm run flowchain:devkit -- bridge-readiness --json
```

Without owner Base 8453 inputs, the correct result is blocked with env names
only. The devkit must not invent live bridge values.

## Run The Dev Pack Proof

```powershell
npm run flowchain:dev-pack:e2e
```

This command attaches to local RPC, verifies discovery/readiness, checks block
height, reads wallet balances and transfer history, submits a runtime-backed
local wallet send, runs a CLI command with JSON output, and regenerates the RPC
reference.

Outputs:

- `docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json`
- `docs/agent-runs/live-product-dev-pack/DEV_PACK.md`
- `docs/agent-runs/live-product-dev-pack/HANDOFF.md`
- `docs/sdk/RPC_REFERENCE.generated.md`

## Current Limits

- The SDK/devkit is FlowChain-native JSON-RPC, not EVM JSON-RPC.
- Public RPC remains blocked until owner public endpoint inputs are configured.
- Live bridge remains blocked until owner Base 8453 inputs and operator
  acknowledgement are configured.
- Signed transaction envelope SDK examples are still a follow-up. The current
  devkit wallet send uses the existing local control-plane wallet-send path.
