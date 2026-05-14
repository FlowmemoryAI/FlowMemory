# Real-Value Pilot Ops Checklist

## Acceptance

- [x] `npm run flowchain:real-value-pilot:ops` exists.
- [x] Merged HQ `npm run flowchain:real-value-pilot:e2e` remains the final
  all-proof pilot gate.
- [x] Dry-run mode passes without live RPC or keys.
- [x] Live mode refuses missing required env vars and missing operator acknowledgement.
- [x] Base chain id `8453` is verified before live observer/deploy actions.
- [x] Cap env values are checked as tiny and nonzero.
- [x] Exact next commands print after deploy, observe, credit, withdraw, pause, resume, export evidence, and restart.
- [x] Emergency stop script exists.
- [x] Evidence export excludes `.git`, `node_modules`, build targets, local vaults, private keys, and env files.
- [x] Second-computer docs include a step-by-step owner pilot path.
- [x] Troubleshooting covers wrong chain, wrong contract, replay, stalled relayer, locked Cargo target, port conflict, and missing credentials.
- [x] `node infra/scripts/check-unsafe-claims.mjs` passes.
- [x] `git diff --check` passes.
- [x] `npm run flowchain:product-e2e` still passes.
- [x] `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` reports
  only contracts, bridge, and runtime missing after this branch.

## Commands To Run

- [x] PowerShell parser checks for changed scripts.
- [x] `npm run flowchain:real-value-pilot:ops`
- [x] `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete`
- [x] `node infra/scripts/check-unsafe-claims.mjs`
- [x] `git diff --check`
- [x] `npm run flowchain:product-e2e`
