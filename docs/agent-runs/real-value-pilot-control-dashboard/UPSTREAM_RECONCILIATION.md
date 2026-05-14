# Upstream Reconciliation Note

This branch has been rebased onto `origin/main` commit `f384236` (`Refresh real-value pilot HQ status`).

## Resolved Package Script Conflict

Upstream owns the final HQ gate command:

```json
"flowchain:real-value-pilot:e2e": "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-real-value-pilot-e2e.ps1"
```

This branch adds the control-plane/dashboard owner proof command expected by `docs/FLOWCHAIN_REAL_VALUE_PILOT.md`:

```json
"flowchain:real-value-pilot:control-dashboard": "npm run real-value-pilot:e2e --prefix services/control-plane"
```

## Current Verification

Run:

```powershell
npm run flowchain:real-value-pilot:control-dashboard
npm run flowchain:product-e2e
npm run flowchain:real-value-pilot:e2e
```

The first command passes from this branch's implementation. The second command now passes after the upstream optional Slither policy is present. The third command remains incomplete until the non-control-dashboard proof commands land from their owning branches.
