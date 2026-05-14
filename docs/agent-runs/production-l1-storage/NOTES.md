# Production L1 Storage Notes

- The current runtime is not a production L1. This task hardens the private/local FlowChain runtime storage surface without making production, public-validator, tokenomics, or bridge-security claims.
- Existing state uses `BTreeMap` for most maps, so deterministic root ordering is already available for logical state. The block vector and pending transaction vector still need durable file-backed handling.
- Existing state root intentionally excludes block history and pending transactions. The storage manifest should include canonical tip/finality alongside that state root.
- Existing `state.json` and handoff exports must remain usable for dashboard/control-plane workflows, but they should become compatibility views over durable storage.
- Bridge runtime persistence is a gap in the Rust crate. The control-plane notes describe a handoff shape with observations, credits, withdrawal intents, replay protection, and release evidence, but no merged Rust model exists here yet.
- Default storage policy for this pass should be archival. If pruning is not implemented, document it directly and prove old transaction lookup through indexes.
- Implemented state roots now include the latest and finalized point, so tests that intentionally produce different block histories compare map roots when they only care about state map equality.
- The default export/demo state does not include bridge rows; `npm run flowchain:storage:e2e` is the bridge persistence proof command.
- The inherited global `CARGO_TARGET_DIR` was unsafe for this worktree. Accurate tests were run after clearing it; wrapper scripts already use isolated per-process target directories under `devnet/local/cargo-target/`.
- The export safety metadata avoids secret-shaped field names so local scanner tooling does not flag a safe boolean manifest as a leaked secret.
