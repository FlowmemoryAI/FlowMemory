# Real-Value Pilot Ops Experiments

## Dry-Run Pilot Ops Proof

- Command: `npm run flowchain:real-value-pilot:ops`
- Result: passed; writes
  `devnet/local/real-value-pilot/ops-e2e/flowchain-real-value-pilot-ops-e2e-report.json`.

## Final Pilot Gate, Report-Only

- Command: `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete`
- Result: passed in incomplete mode; after this branch the remaining missing
  proof commands are contracts, bridge, and runtime.

## Parser Checks

- Command: PowerShell parser check over all `flowchain-real-value-pilot*.ps1` scripts.
- Result: passed.

## Unsafe Claims Scan

- Command: `node infra/scripts/check-unsafe-claims.mjs`
- Result: passed.

## Product E2E

- Command: `npm run flowchain:product-e2e`
- Result: passed on current branch; generated tracked fixture/output files from
  the test run were restored because they are outside this task's intended
  diff.

## Diff Check

- Command: `git diff --check`
- Result: passed.
