# Live Observation Gate Proof

Status: implemented.

Command:

```powershell
npm run flowchain:bridge:live:check
```

Self-test artifact:

- `services/bridge-relayer/out/base8453-live-readiness-check.json`
- `devnet/local/bridge-live-readiness/bridge-live-readiness-report.json`

Checks proved by the self-test:

- Missing env names are listed without printing values.
- Missing operator acknowledgement is rejected.
- Missing confirmation depth is rejected.
- Missing supported token is rejected.
- Broad block scan is rejected.
- Unapproved lockbox is rejected.
- Wrong chain ID is rejected before log scan.

Live observation behavior:

- `eth_chainId` must return `0x2105`.
- `eth_blockNumber` is read to enforce confirmation depth.
- `eth_getLogs` is called only after chain, acknowledgement, lockbox, block range, and cap guardrails pass.
- Deposits above `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI` are rejected.
- Total observed pilot amount above `FLOWCHAIN_PILOT_TOTAL_CAP_WEI` is rejected.
- Evidence records confirmation count.
- If a log is not returned by the confirmed bounded scan, no observation and no credit are produced.

Required observe env names:

- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_OPERATOR_ACK`

Optional live observe env:

- `FLOWCHAIN_PILOT_MAX_USD`
