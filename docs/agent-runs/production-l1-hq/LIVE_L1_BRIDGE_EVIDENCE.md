# Live L1 Bridge Evidence

Date: 2026-05-14

Final status: `EXTERNAL-BLOCKED ONLY`

## Summary

The strict live-funds standard did not pass. The new live L1 bridge gate runs
and verifies the unbounded FlowChain node, but it stops before live observation
because the owner/operator Base 8453 configuration is absent. No Base
transaction was broadcast and no secret/env values were printed.

The current running node state does not contain a live bridge credit:

- `bridgeCredits`: `0`
- latency from confirmation eligibility to spendable credit: unmeasured
- one-unit spend from a live credited account: not run
- export/import root comparison after live spend: not run

## Commands Run

| Command | Result |
| --- | --- |
| `npm run flowchain:production-l1:e2e` | Exit 0; aggregate `passed-with-live-blockers`; local/mock path passed; live bridge readiness blocked on missing owner env |
| `npm run flowchain:real-value-pilot:e2e` | Exit 0; report `passed` |
| `npm run flowchain:bridge:live:check` | Exit 1 by design; report `blocked`; missing live env names only |
| `npm run flowchain:live-l1-bridge:e2e` | Exit 1 by design; report `EXTERNAL-BLOCKED`; issue `external:missing-live-env` |
| `npm run flowchain:no-secret:scan` | Exit 0; report `passed` |
| `git diff --check` | Exit 0; only CRLF normalization warnings |

Additional checks:

- `npm test --prefix services/bridge-relayer`: passed, 21/21.
- `npm test --prefix services/control-plane`: passed, 24/24.
- PowerShell parser checks passed for the new/changed scripts.

## Report Paths

- `devnet/local/live-l1-bridge-e2e/flowchain-live-l1-bridge-e2e-report.json`
- `devnet/local/live-l1-bridge-e2e/flowchain-live-l1-bridge-e2e-summary.md`
- `devnet/local/bridge-live-readiness/bridge-live-readiness-report.json`
- `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`
- `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`
- `devnet/local/production-l1-e2e/no-secret-scan-report.json`

## Safe Blocker

The direct live-readiness gate reports these missing owner/operator env names:

- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`

The new live e2e gate requires the same live configuration and enforces 12
confirmations during the run. It can also diagnose an operator-supplied tx hash
when `FLOWCHAIN_BASE8453_TX_HASH` or `FLOWCHAIN_BASE8453_OPERATOR_TX_HASH` is
provided.

## Follow-Up

Provide the missing owner/operator live Base 8453 inputs, then rerun
`npm run flowchain:bridge:live:check` and
`npm run flowchain:live-l1-bridge:e2e`.

Do not mark PASS until the report proves a new live credit was ingested into
`devnet/local/state.json`, appears in `bridgeCredits`,
`bridgeCreditReceipts`, and `bridgeReplayKeys`, is spendable by transferring
one smallest unit, and has matching export/import roots with latency under 60
seconds after confirmation eligibility.

