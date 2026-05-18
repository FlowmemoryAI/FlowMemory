# PR Summary: Real-Value Pilot Runtime Proof

## What Changed

- Added deterministic bridge asset/account mappings, bridge credit records,
  bridge credit receipts, replay index, and Base event receipt index to the
  local devnet runtime.
- Added `bridge-handoff` to consume `flowmemory.bridge_runtime_handoff.v0`
  relayer handoff files into deterministic setup and credit transactions.
- Added `bridge-receipt` lookup by receipt id and Base event reference.
- Added runtime export/import and handoff export coverage for bridge-specific
  state roots.
- Added `infra/scripts/flowchain-real-value-pilot-runtime.ps1`.
- Added the root `flowchain:real-value-pilot:runtime` command.
- Updated local runtime docs and HQ pilot status for issue #134.

## Why

The final real-value pilot HQ gate requires a dedicated chain-runtime proof row
before the owner can consider the capped pilot go/no-go checklist.

## Commands

- `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` - passed.
- `cargo fmt --manifest-path crates/flowmemory-devnet/Cargo.toml --check` - passed.
- `[scriptblock]::Create((Get-Content -Raw infra/scripts/flowchain-real-value-pilot-runtime.ps1)) | Out-Null` - passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-real-value-pilot-runtime.ps1 -RunDir .` - expected failure; refused to clear the repository root.
- `npm run flowchain:real-value-pilot:runtime` - passed; consumed the bridge proof output handoff with source chain `8453` when present.
- `npm run flowchain:real-value-pilot:e2e` - passed with `missingProofs: 0`; this run includes `npm run flowchain:product-e2e` and `npm run flowchain:l1-e2e`.
- `node infra/scripts/check-unsafe-claims.mjs` - passed.
- `git diff --check` - passed with Git line-ending warnings only.

## Scope Boundary

This remains local/testnet runtime work. It does not add custody, withdrawal
release, production bridge security, tokenomics, public validator readiness,
public L1/mainnet readiness, or production deployment behavior.
