# FlowChain Real-Value Pilot Chain Runtime Experiments

## Commands

| Command | Status | Notes |
| --- | --- | --- |
| `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` | pass | 35 integration tests passed on the integration branch. |
| `cargo fmt --manifest-path crates/flowmemory-devnet/Cargo.toml --check` | pass | Rust formatting check passed. |
| `[scriptblock]::Create((Get-Content -Raw infra/scripts/flowchain-real-value-pilot-runtime.ps1)) \| Out-Null` | pass | PowerShell parser accepted the runtime wrapper. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-real-value-pilot-runtime.ps1 -RunDir .` | expected fail | Wrapper refused to clear the repository root before any run-directory deletion. |
| `npm run flowchain:real-value-pilot:runtime` | pass | Runtime proof passed after the run-directory guard, consumed the bridge proof output handoff with source chain `8453`, and wrote `devnet/local/real-value-pilot-e2e/flowchain-real-value-pilot-e2e-report.json`. |
| `npm run flowchain:real-value-pilot:e2e` | pass | Strict final gate passed after the run-directory guard and bridge-output handoff wiring; final report had `missingProofs: 0` and wrote `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`. |
| `npm run flowchain:product-e2e` | pass | Covered by the strict final pilot gate run on this branch. |
| `npm run flowchain:l1-e2e` | pass | Covered by the strict final pilot gate run on this branch. |
| `node infra/scripts/check-unsafe-claims.mjs` | pass | Checked launch claims in README.md, docs, and contracts. |
| `git diff --check` | pass | Passed with Git line-ending warnings only. |

## Runtime Proof Coverage

- Product-smoke setup creates the local token and DEX baseline.
- Bridge handoff queues the pilot credit from
  `fixtures/bridge/local-runtime-bridge-handoff.json`.
- First block applies the credit once and records local bridge balance, bridge
  credit, receipt, replay key, and event index state.
- Duplicate handoff queues a replay transaction that is rejected with replay
  evidence and no second applied credit.
- Receipt lookup succeeds by receipt id and by Base source chain, contract,
  transaction hash, and log index.
- Wrong receipt id and wrong Base event reference return not found.
- Restart preserves token, DEX, bridge credit, bridge receipt, and replay state.
- Exported dashboard, indexer, verifier, and control-plane handoffs preserve
  bridge maps and roots.
- Export/import preserves state root plus bridge asset mapping, account mapping,
  credit, receipt, replay index, and event receipt index roots.
