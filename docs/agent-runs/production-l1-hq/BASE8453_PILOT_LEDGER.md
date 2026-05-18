# Base 8453 Pilot Ledger

Date: 2026-05-14

## Decision

Status: `CODE_NOT_READY`.

A live capped Base 8453 owner pilot must not run from this branch. The gap loop
failed required code-controlled gates, so this is not merely an owner-input
blocker.

## Broadcast Ledger

| Item | Value |
| --- | --- |
| Base transaction broadcast by this follow-up | No |
| Funds sent by this follow-up | No |
| Live RPC value printed by this follow-up | No |
| Private key, seed, or signed transaction printed by this follow-up | No |
| Final loop classification | `CODE_NOT_READY` |

## Required Before Funds

- The branch must be reclassified as `READY_FOR_OPERATOR_LIVE_PILOT`.
- `npm run flowchain:production-l1:e2e` must pass in the final evidence loop.
- `npm run flowchain:real-value-pilot:e2e` must pass in the final evidence loop.
- `npm run flowchain:real-value-pilot:control-dashboard` must pass in the final
  evidence loop.
- `npm run flowchain:no-secret:scan` must pass in the final evidence loop.
- The owner must independently verify the lockbox address before sending funds.

## Guardrails That Still Apply Later

- Chain ID must be `8453`.
- Block scans must be bounded and narrow.
- Per-deposit and total caps must be present and within script limits.
- Confirmation depth must be at least the configured minimum.
- Owner-only env values must stay local and out of reports.
