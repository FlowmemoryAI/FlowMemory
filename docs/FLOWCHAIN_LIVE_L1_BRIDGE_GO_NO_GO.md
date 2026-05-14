# FlowChain Live L1 Bridge Go/No-Go

Date: 2026-05-14

Final status: `EXTERNAL-BLOCKED ONLY`

## Standard

The go/no-go standard is not softened:

> A user can bridge a small amount of real ETH from Base 8453 into FlowChain,
> wait less than one minute after confirmation eligibility, see the credit in
> the running FlowChain L1 node state, and spend/transfer it on FlowChain.
> Nothing required for that path is mock-only.

## Decision

No-go for the live-funds bridge path.

The code-controlled verification gate exists and runs, but the strict live path
cannot pass in this environment because owner/operator Base 8453 live inputs are
not present. No live Base transaction was broadcast. No environment values were
printed. The running FlowChain node state still has `bridgeCredits: 0`, so PASS
is not claimed.

Machine evidence:

- `devnet/local/live-l1-bridge-e2e/flowchain-live-l1-bridge-e2e-report.json`
  reports `EXTERNAL-BLOCKED`.
- `devnet/local/live-l1-bridge-e2e/flowchain-live-l1-bridge-e2e-summary.md`
  reports zero credits in main state and unmeasured latency.
- `devnet/local/bridge-live-readiness/bridge-live-readiness-report.json`
  reports `blocked` with missing owner env names only.
- `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`
  reports aggregate `passed-with-live-blockers`.

## What Changed

- Added `npm run flowchain:live-l1-bridge:e2e`.
- Added a read-only Base 8453 transaction diagnostic command:
  `npm run flowchain:bridge:diagnose:tx`.
- Added the live L1 bridge gate under
  `infra/scripts/flowchain-live-l1-bridge-e2e.ps1`.
- Hardened node startup so the live gate verifies a real running node process
  without hanging on a long-running wrapper.
- Updated the control-plane server to reload state per request instead of
  holding stale startup state.
- Extended the no-secret scan to cover `devnet/local/live-l1-bridge-e2e`.

## Required Follow-Up

Owner/operator inputs required before PASS can be attempted:

- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS=12`

For the tx-specific diagnostic, also provide either
`FLOWCHAIN_BASE8453_TX_HASH` or `FLOWCHAIN_BASE8453_OPERATOR_TX_HASH`.

After those inputs exist, rerun:

```powershell
npm run flowchain:bridge:live:check
npm run flowchain:live-l1-bridge:e2e
```

PASS requires the new gate to show all of these in the main running node state,
not only in proof artifacts: `bridgeCredits`, `bridgeCreditReceipts`,
`bridgeReplayKeys`, credited balance, a one-unit transfer from the credited
account, matching export/import roots, and measured latency under 60 seconds
from confirmation eligibility to spendable credit.

Release/broadcast back to Base remains separate and absent unless explicitly
authorized.

