# FlowChain Guardrailed Live-Chain Build Goal Pack

Status: copy-ready `/goal` prompts for agents building FlowChain from the
current local/private runtime and capped owner pilot into a complete runnable
L1 product with wallet, bridge, transaction execution, explorer, desktop/mobile
wallet distribution, and full end-to-end verification.

These prompts are intentionally strict. They are not docs-only tasks. Every
agent must build production-shaped implementation, keep existing behavior
working, and leave machine-checkable proof.

## Shared Rule

Do not claim that FlowChain is ready for broad public funds, unaudited custody,
or public mainnet use until the final verification prompt proves the entire path
with configured live dependencies:

1. A FlowChain node starts, runs, persists state, restarts, and keeps finality.
2. A wallet creates/imports/backs up accounts and signs transactions.
3. A Base 8453 deposit is observed from a configured lockbox.
4. The exact deposit amount is credited to the matching FlowChain account.
5. The credited balance is spendable by the wallet in a FlowChain transfer.
6. Swap/asset flows work through the FlowChain runtime, not mock rows.
7. Withdrawal intent and release evidence are exported with replay protection.
8. Desktop and mobile wallet builds install and talk to the same runtime API.
9. Explorer/control-plane reads the same committed runtime state.
10. No public output includes private keys, seed phrases, RPC credentials, API
    keys, webhooks, or vault ciphertext.

## Final Stop Condition

The whole program is incomplete until this command exists and passes from a
clean checkout with documented environment configuration:

```powershell
npm run flowchain:live-product:e2e
```

That command must run the chain, wallet, bridge, control-plane, desktop wallet,
mobile build, swap, transfer, export/import, restart, and no-secret checks. If a
real external dependency is unavailable, the command must fail closed with the
exact missing variable or deployment artifact.

## Prompt Files

- `01-hq-orchestrator.md`
- `02-chain-runtime-consensus.md`
- `03-node-rpc-network.md`
- `04-wallet-keys-signing.md`
- `05-transaction-ledger-execution.md`
- `06-base8453-bridge-relayer.md`
- `07-bridge-credit-withdrawal.md`
- `08-assets-dex-swap.md`
- `09-control-plane-explorer.md`
- `10-desktop-mobile-wallet.md`
- `11-ops-installer-monitoring.md`
- `12-state-storage-recovery.md`
- `13-live-product-verification.md`

Launcher:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\launch-production-l1-live-chain-goals.ps1 -DryRun
```
