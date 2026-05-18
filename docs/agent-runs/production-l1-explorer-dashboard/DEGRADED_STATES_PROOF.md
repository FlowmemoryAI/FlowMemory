# Degraded States Proof

The dashboard exposes these degraded/error states with recovery references:

- Runtime offline.
- API offline.
- Storage unavailable.
- Bridge relayer offline.
- Live env missing, represented through missing optional sources and explicit fallback provenance.
- Wrong chain ID.
- Lockbox missing or not configured, represented through bridge readiness/error records.
- Broad scan refused, covered by bridge-relayer tests.
- Duplicate event rejected.
- Dashboard build failing, represented as a recovery state in the error/recovery surface when reported.

Evidence:

- `fixtures/dashboard/flowchain-l1-explorer-fallback.json` contains the deterministic error records.
- `Errors / Recovery` view renders those records.
- Browser evidence confirms the `Errors / Recovery` view label is visible on desktop and mobile.
- Bridge-relayer tests in `npm run flowchain:l1-e2e` cover guarded Base reads and broad-range refusal.
