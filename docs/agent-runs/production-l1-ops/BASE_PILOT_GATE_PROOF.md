# Base Pilot Gate Proof

Readiness command:

```powershell
npm run flowchain:bridge:live:check
```

Latest readiness status:

```text
status: blocked
baseChainId: 8453
broadcasts: false
printsEnvValues: false
```

Missing env names:

- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH`

Optional token-mode env names:

- `FLOWCHAIN_BASE8453_TOKEN_MODE`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`

Refusal rules implemented:

- Missing acknowledgement blocks readiness.
- Missing RPC URL blocks readiness.
- Wrong `eth_chainId` fails readiness; expected Base `8453`.
- Missing or malformed lockbox address blocks or fails readiness.
- Token mode requires a supported token address.
- Missing, zero, negative, or oversized caps fail readiness.
- Missing or unsafe confirmation depth blocks or fails readiness.
- Broad block ranges fail readiness.
- The check never prints live env values.

Strict live pilot proof remains incomplete until these commands exist:

- `npm run flowchain:real-value-pilot:contracts`
- `npm run flowchain:real-value-pilot:bridge`
- `npm run flowchain:real-value-pilot:runtime`

