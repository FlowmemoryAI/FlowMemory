# Production L1 Consensus Experiments

| Experiment | Command | Result | Notes |
| --- | --- | --- | --- |
| Baseline Rust tests | `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` | Pass | Initial baseline passed before edits. |
| Final Rust tests | `cargo clean --manifest-path crates/flowmemory-devnet/Cargo.toml -p flowmemory-devnet; cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` | Pass | Cleaned the shared `CARGO_TARGET_DIR` package artifact so tests used this worktree's `flowmemory-devnet` binary; 35 integration tests passed. |
| Consensus smoke | `npm run flowchain:consensus:smoke` | Pass | Writes `devnet/local/consensus-smoke/consensus-report.json` with finalized height 4 and validation `true`. |
| Multi-node smoke | `npm run flowchain:multi-node:smoke` | Pass | Existing local-file peer smoke passed and wrote `devnet/local/multi-node-smoke/multi-node-smoke-report.json`. |
| Diff whitespace | `git diff --check` | Pass | No whitespace errors; Git reported only LF-to-CRLF working-copy warnings. |
