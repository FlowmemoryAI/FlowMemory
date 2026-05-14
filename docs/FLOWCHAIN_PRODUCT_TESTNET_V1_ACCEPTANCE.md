# FlowChain Product Testnet V1 Acceptance

Status: executable acceptance contract for the full local/testnet product chain.

Last updated: 2026-05-13.

## Command

The readiness command is:

```powershell
npm run flowchain:product-e2e
```

This command is intentionally stricter than `npm run flowchain:full-smoke`.
`flowchain:full-smoke` proves the current private/local foundation package.
`flowchain:product-e2e` is the gate for the user-facing product testnet flow.

## Required User Journey

The product testnet is not ready until the E2E command proves:

1. dependencies and prerequisite smoke checks pass;
2. a local node can start and produce blocks;
3. the control-plane API is reachable;
4. the workbench is reachable;
5. a local test wallet can sign and verify product transactions;
6. an account can receive local test units through faucet or test bridge credit;
7. a signed transfer is included in a block;
8. a local test token can be launched;
9. a DEX pool can be created;
10. liquidity can be added;
11. a swap changes balances and writes a receipt;
12. explorer/API/workbench surfaces show blocks, txs, accounts, tokens, pools,
    positions, swaps, and bridge records;
13. export/import preserves expected local state;
14. no public route returns private keys or secret-shaped material.

## Current Rule

If a required product surface is missing, `flowchain:product-e2e` must fail and
name the owning subsystem. Do not use partial subsystem smoke tests as readiness
evidence.

For coordination reports only, agents may run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-product-e2e.ps1 -AllowIncomplete
```

## Boundary

This target is for local/testnet validation. It may include local Anvil bridge
or Base Sepolia testnet flow. Base mainnet and real-funds bridge behavior remain
blocked behind a separate audited production release gate.

