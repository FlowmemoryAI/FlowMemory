# Real Funds Command Separation

Mock-safe commands:

```powershell
npm run flowchain:production-l1:e2e
npm run flowchain:bridge:mock:e2e
npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete -SkipBaseline
```

Readiness command, no broadcast:

```powershell
npm run flowchain:bridge:live:check
```

Live owner actions are separated behind explicit acknowledgement and local env:

```powershell
$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
npm run flowchain:real-value-pilot -- --Mode Live --Action Observe
npm run flowchain:real-value-pilot -- --Mode Live --Action Credit
npm run flowchain:real-value-pilot -- --Mode Live --Action Withdraw
npm run flowchain:bridge:emergency-stop
```

Rules:

- Mock commands do not require live RPC or keys.
- Readiness commands may read live env but do not broadcast.
- Broadcast actions require explicit acknowledgement and owner-supplied env.
- Live commands print env names and caps, never env values.
- Only tiny owner pilot funds should be used after strict proof commands pass.

