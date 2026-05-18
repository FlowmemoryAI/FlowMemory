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
npm run flowchain:devkit -- node-status --json
npm run flowchain:devkit -- watch-height --seconds 30
```

The chain is locally alive when `nodeRunning=true` and `currentBlock` advances
between checks.

## Explore Blocks, Transactions, And Accounts

```powershell
npm run flowchain:devkit -- blocks --json --limit 5
npm run flowchain:devkit -- transactions --json --limit 5
npm run flowchain:devkit -- accounts --json --limit 5
npm run flowchain:devkit -- finality --json --limit 5
```

These commands read the same local control-plane RPC that wallets and the
tester packet use. They are the first checks to run before building an explorer,
indexer, wallet panel, or app integration.

## Read Wallet Activity

```powershell
npm run flowchain:devkit -- wallet-balances --json --limit 5
npm run flowchain:devkit -- wallet-transfers --json --limit 5
npm run flowchain:devkit -- wallet-metadata --json --limit 5
npm run flowchain:devkit -- faucet-events --json --limit 5
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
npm run flowchain:devkit -- bridge-deposits --json --limit 5
npm run flowchain:devkit -- bridge-credits --json --limit 5
npm run flowchain:devkit -- withdrawals --json --limit 5
```

Without owner Base 8453 inputs, the correct result is blocked with env names
only. The devkit must not invent live bridge values.

## Run The Dev Pack Proof

```powershell
npm run flowchain:sdk:e2e
npm run flowchain:dev-pack:e2e
```

These commands attach to local RPC, verify discovery/readiness, check block
height, read block/transaction/account/wallet/bridge surfaces, submit a
runtime-backed local wallet send, run CLI commands with JSON output, verify the
Node.js and browser examples, and regenerate the RPC reference.

Outputs:

- `docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json`
- `docs/agent-runs/live-product-dev-pack/DEV_PACK.md`
- `docs/agent-runs/live-product-dev-pack/HANDOFF.md`
- `docs/sdk/RPC_REFERENCE.generated.md`

## Run The Examples

```powershell
node examples/flowchain-node-quickstart.mjs
node examples/flowchain-node-quickstart.mjs --send
```

Open `examples/flowchain-browser-readiness/index.html` from a browser when you
need a fetch-only readiness example for a public or local RPC origin.

## Current Limits

- The SDK/devkit is FlowChain-native JSON-RPC, not EVM JSON-RPC.
- Public RPC remains blocked until owner public endpoint inputs are configured.
- Live bridge remains blocked until owner Base 8453 inputs and operator
  acknowledgement are configured.
- Signed transaction envelope SDK examples are still a follow-up. The current
  devkit wallet send uses the existing local control-plane wallet-send path, and
  public tester writes use the authenticated `/tester/wallets/*` gateway instead
  of the private local wallet routes.
