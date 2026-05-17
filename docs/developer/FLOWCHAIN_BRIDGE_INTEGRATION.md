# FlowChain Bridge Integration

Status: bridge developer/operator guide for local and owner-configured pilot
flows. Do not bridge live value when readiness is blocked.

## Readiness First

```powershell
npm run flowchain:devkit -- bridge-readiness --json
npm run flowchain:devkit -- bridge-status --json
npm run flowchain:bridge:live:check -- -AllowBlocked
npm run flowchain:bridge:infra:check -- -AllowBlocked
```

Blocked is the correct result until owner Base 8453 and pilot env names are
configured.

## Required Owner Inputs

Live bridge pilot checks require:

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

The devkit and readiness reports print missing names only, not values.

## Lifecycle Reads

```powershell
npm run flowchain:devkit -- bridge-deposits --json --limit 20
npm run flowchain:devkit -- bridge-credits --json --limit 20
npm run flowchain:devkit -- withdrawals --json --limit 20
npm run flowchain:devkit -- bridge-credit-status --json --credit <credit-id>
```

Lookup keys may be `creditId`, `depositId`, `accountId`, `flowchainRecipient`,
`txHash`, `baseTxHash`, or wallet address depending on the evidence packet.

## Safety Rules

- Base mainnet pilot mode requires confirmations greater than zero.
- Removed logs, missing block hashes, and non-canonical log block hashes are
  rejected before credit application.
- Credits use exact decimal-string accounting.
- Replay keys are consumed once.
- Pilot per-deposit and total caps must pass before runtime credit application.
- Emergency stop and pause commands must be tested before inviting external
  testers.

## Local Versus Live

Local/mock bridge paths prove accounting and runtime handoff without live value.
Owner-configured live paths require fresh Base 8453 RPC, lockbox, token,
confirmation, cap, and operator acknowledgement inputs.
