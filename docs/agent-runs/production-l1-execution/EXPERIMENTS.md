# Private/Local L1 Execution Experiments

This file records commands, observations, and evidence from the execution-layer work.

## Commands

Completed:
- `npm ci`
  - Installed root workspace dependencies from lockfile.
- `npm ci --prefix apps/dashboard`
  - Installed dashboard dependencies from lockfile for the required product wrapper.
- `npm ci --prefix crypto`
  - Installed crypto package dependencies from lockfile for the required product wrapper.
- `cargo clean --manifest-path crates/flowmemory-devnet/Cargo.toml`
- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml`
  - Passed after clean rebuild with 30 tests.
- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml --test devnet_tests cli_execution_e2e_writes_report_and_round_trips_state`
  - Passed after adding CLI report/restart/export-import coverage.
- `cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- --state devnet/local/product-execution-smoke/state.json product-smoke --out-dir devnet/local/product-execution-smoke`
  - Passed.
  - State root: `0x07fd8df4740b407d0d25a5c39a0f652f797eaf2152cfa6475e24aff7a363e67a`.
- `npm run flowchain:execution:e2e`
  - Passed.
  - Report: `devnet/local/execution-e2e/execution-e2e-report.json`.
  - State root: `0xb59214e331c7ee9384a9409acbbe4f61049270005a80f4582fa53df3d186dcb3`.
  - Success receipts: 11.
  - Failed receipts: 11.
- `npm run flowchain:product-e2e`
  - Passed after lockfile dependency install.
  - Report: `devnet/local/product-e2e/flowchain-product-e2e-report.json`.
  - The product E2E wrapper ran private/local full smoke, runtime `product-smoke`, control-plane/dashboard surface checks, and wallet product fixture validation.
- `npm run flowchain:real-value-pilot:runtime`
  - Passed.
  - This aliases to `flowchain:execution:e2e` and proves the runtime-owned bridge credit, transfer, DEX spend, failed replay, restart, and export/import path.
- `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete -SkipBaseline`
  - Completed in coordination/report mode.
  - Runtime proof is present.
  - Remaining missing proofs are owned by contracts and bridge-relayer gates in this checkout.
- `node infra/scripts/check-unsafe-claims.mjs`
  - Passed after renaming agent-run headings to explicit private/local wording.
- `git diff --check`
  - Passed.

## Observations

- Initial branch check: `agent/production-l1-execution` is based on `origin/main` at the start of work.
- The local devnet already had a no-value deterministic Rust runtime with local test-unit balances, faucet records, product token state, and DEX skeletons. It lacked account nonces, bridge credit receipts, token transfer receipts, failed execution receipt state, execution events, deterministic cost receipt fields, and E2E report generation.
- The implemented product flow starts from a bridge credit, transfers credited local units, launches and transfers `FLOWT`, creates a pool, adds liquidity, swaps, removes liquidity, and records queryable receipts.
- A stale Cargo target binary briefly hid the new `execution-e2e` command. Cleaning the external target directory fixed that and ensured checks used edited source.
- The product wrapper generated dashboard public data and service out files while running full smoke; those generated files were restored because they are outside this agent's edit scope.
- The real-value pilot coordinator still reports missing contracts and bridge-relayer proof scripts in this checkout. The runtime proof alias is now present; incoming `origin/main` commits also touch adjacent real-value-pilot aliases.
