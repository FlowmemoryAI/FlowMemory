# FlowChain Real-Value Pilot Goal Pack

Status: copy-ready `/goal` prompts for a capped real-value bridge pilot.

Last updated: 2026-05-14.

## Target

Build the missing path between the current local/product FlowChain testnet and a
capped real-value pilot that can be exercised by the project owner with a tiny
amount on Base public network chain ID `8453`.

This goal pack is for implementation, deployment tooling, operator checks, and
emergency controls. It does not claim broad public readiness.

## Current Baseline

Current `main` already has:

- local/private product testnet package;
- `npm run flowchain:product-e2e`;
- local chain runtime, token launch, DEX pool/liquidity/swap smoke;
- wallet signing and product transaction schemas;
- control-plane API, explorer/workbench surfaces, and bridge local-credit smoke;
- second-computer local verification.

Current long-loop agents are also working in these worktrees:

- `E:\FlowMemory\flowmemory-chain`
- `E:\FlowMemory\flowmemory-crypto`
- `E:\FlowMemory\flowmemory-indexer`
- `E:\FlowMemory\flowmemory-dashboard`
- `E:\FlowMemory\flowmemory-bridge-full`
- `E:\FlowMemory\flowmemory-contracts`
- `E:\FlowMemory\flowmemory-review`
- `E:\FlowMemory\flowmemory-hardware`
- `E:\FlowMemory\flowmemory-research`
- `E:\FlowMemory\flowmemory-hq-review-loop`

Real-value pilot agents must inspect those worktrees before coding and reuse
their completed work where practical. Do not rebuild duplicate systems.

## Final Stop Condition

The pilot is complete only when all of these pass from `main`:

```powershell
npm run flowchain:l1-e2e
npm run flowchain:real-value-pilot:e2e
```

`flowchain:real-value-pilot:e2e` must prove:

1. Base chain ID `8453` is verified before any live transaction path.
2. A deployed lockbox address is loaded from local ignored config, not hardcoded
   into public docs as a blanket endorsement.
3. Per-deposit and total pilot caps are enforced on-chain.
4. A pause path blocks new deposits while preserving recovery/release flows.
5. A tiny supported-asset deposit can be observed from Base public network.
6. The relayer derives a deterministic bridge observation and credit.
7. The local FlowChain runtime credits the matching local account once.
8. Replay of the same Base event is rejected or idempotent with evidence.
9. Withdrawal intent/release path is implemented for the pilot mode.
10. Operator can stop the bridge, revoke authority, export evidence, and recover
    from restart.
11. Dashboard/API show exact live/degraded/error state.
12. No private key, seed phrase, mnemonic, RPC credential, API key, or webhook is
    committed, logged, exported, or returned from public local routes.

## Local Secret Boundary

Agents may add `.env.example`, config schemas, and scripts that read local
environment variables. They must not commit real keys or RPC credentials.

Required local env names should be explicit and scoped, for example:

```text
FLOWCHAIN_BASE8453_RPC_URL
FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY
FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
FLOWCHAIN_PILOT_TOTAL_CAP_WEI
FLOWCHAIN_PILOT_OPERATOR_ACK
```

## Prompt Files

- `pilot-hq.md`
- `pilot-contracts.md`
- `pilot-bridge-relayer.md`
- `pilot-chain-runtime.md`
- `pilot-wallet-operator.md`
- `pilot-control-plane-dashboard.md`
- `pilot-ops-installer.md`

## Launcher

```powershell
cd E:\FlowMemory\flowchain-release
powershell -ExecutionPolicy Bypass -File .\infra\scripts\launch-flowchain-real-value-pilot-agents.ps1
```

Run with `-DryRun` first when checking worktree paths.
