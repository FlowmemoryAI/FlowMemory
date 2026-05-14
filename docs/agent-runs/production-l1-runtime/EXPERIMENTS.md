# Production L1 Runtime Experiments

| Experiment | Command | Result | Notes |
| --- | --- | --- | --- |
| Baseline Rust tests | `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` | Passed | Initial run passed 27 tests before implementation changes. |
| Runtime Rust tests | `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` | Passed | Final run passed 27 tests. |
| Signed envelope direct submit | `flowmemory-devnet submit-tx --tx-file <signed-vector> --direct` | Passed | Accepted fixture tx `0xfba94617ac6fbae608393c67570280d7123b27dabb0c1f31427808ad955a7c46`; second submit rejected as `duplicate-tx-id`. |
| Block/query direct path | `flowmemory-devnet run-block`, `query-tx`, `query-receipt` | Passed | Signed tx became queryable with a stored receipt after block production. |
| Node smoke | `npm run flowchain:node:smoke` | Passed | Final run produced 21 blocks, accepted 26 txs, queried receipts, restarted, rejected replay, and preserved export/import roots. |
| Smoke report | `devnet/local/node-smoke/production-node-smoke-report.json` | Written | State root `0x3e362fa09ddd18626c6213f49863531c7e93cd7c13708894aa19ff9d700201e8`. |
| Diff whitespace | `git diff --check` | Passed | Required final gate. |
