# FlowChain Real-Value Pilot Chain Runtime Checklist

## Acceptance

- [x] Root `npm run flowchain:real-value-pilot:runtime` exists on this branch.
- [x] Runtime consumes `flowmemory.bridge_runtime_handoff.v0` pilot handoff data.
- [x] Runtime applies each bridge credit exactly once.
- [x] Duplicate replay is rejected with evidence and does not apply a second
  credit.
- [x] Receipt lookup works by local receipt id.
- [x] Receipt lookup works by Base event reference.
- [x] Wrong receipt id and wrong Base event reference return not found.
- [x] Restart preserves token, DEX, bridge credit, bridge receipt, and replay
  state.
- [x] Export/import preserves deterministic state root and all bridge-specific
  roots.
- [x] Handoff exports include bridge credit, receipt, event index, and roots for
  dashboard, indexer, verifier, and control-plane consumers.
- [x] Runtime docs record the local/no-value boundary.
- [x] `cargo test --manifest-path crates/flowmemory-devnet/Cargo.toml` passes.
- [x] `npm run flowchain:real-value-pilot:runtime` passes.
- [x] `npm run flowchain:real-value-pilot:e2e` passes without
  `-AllowIncomplete`.

## Remaining Step

- Open and merge the runtime proof PR for issue #134 so the branch-local runtime
  command lands on `main` and the final HQ pilot gate can run every proof row.
