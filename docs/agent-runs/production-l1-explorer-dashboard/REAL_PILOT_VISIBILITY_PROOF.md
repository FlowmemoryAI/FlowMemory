# Real Pilot Visibility Proof

Visible through control-plane API and deterministic fallback:

- Base pilot readiness state is rendered in the Real-value pilot and Bridge views.
- Source chain ID is `8453`.
- Lockbox address is present when fallback data is used.
- Cap values are present: per-deposit cap and total cap.
- Pause status and emergency status are present.
- Latest observation block range is present.
- Confirmation depth is present.
- Deposit observation is present.
- Local credit is present.
- Duplicate replay rejection is present.
- Withdrawal intent is present.
- Release evidence is present.

Evidence:

- `fixtures/dashboard/flowchain-l1-explorer-fallback.json`.
- `apps/dashboard/public/data/flowchain-l1-explorer-fallback.json`.
- `docs/agent-runs/production-l1-explorer-dashboard/browser-dom-evidence.json`.
- `docs/agent-runs/production-l1-explorer-dashboard/search-proof-queries.json`.

Final gate evidence: after reconciling this branch with `origin/main`, `npm run flowchain:real-value-pilot:e2e` passed. The report at `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json` has empty `missingProofs` and `ownerGoNoGo.go: true`.
