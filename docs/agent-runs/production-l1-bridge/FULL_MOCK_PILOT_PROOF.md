# Full Mock Pilot Proof

Status: passed.

Bridge command:

```powershell
npm run bridge:pilot:mock:e2e
```

Full owner pilot gate:

```powershell
npm run flowchain:real-value-pilot:e2e
```

Full gate report:

- `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`

Full gate checks passed:

- `npm run flowchain:product-e2e`
- `npm run flowchain:l1-e2e`
- `npm run flowchain:real-value-pilot:contracts`
- `npm run flowchain:real-value-pilot:bridge`
- `npm run flowchain:real-value-pilot:runtime`
- `npm run flowchain:real-value-pilot:wallet`
- `npm run flowchain:real-value-pilot:control-dashboard`
- `npm run flowchain:real-value-pilot:ops`

Bridge-specific mock path:

- Uses `fixtures/bridge/base8453-pilot-mock-deposit.json`.
- Produces evidence without RPC or keys.
- Applies local credit once.
- Prepares local transfer handoff to a second wallet.
- Links product/DEX coverage to the existing product E2E command.
- Produces withdrawal intent and release evidence.
- Proves duplicate credit rejection.

Boundaries:

- No live Base transaction was sent.
- No owner key or RPC URL was committed.
- This remains a capped owner pilot path, not a public deposit system.
