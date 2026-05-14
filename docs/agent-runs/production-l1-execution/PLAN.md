# Private/Local L1 Execution Plan

Status: implemented; final verification in progress

Scope:
- Work only in `crates/flowmemory-devnet/`, `devnet/`, `fixtures/`, `docs/LOCAL_DEVNET.md`, `docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md`, `docs/agent-runs/production-l1-execution/`, and `package.json` for execution smoke aliases.
- Keep this as a private/local testnet execution surface. Do not add production deployment, tokenomics, public validator, audited bridge, or mainnet claims.

Phases:
1. Audit current product flow support in the Rust devnet and existing fixtures.
2. Implement native and bridged balance execution with deterministic costs and failure receipts.
3. Implement token launch, token transfer, local mint policy, and token balance query state.
4. Implement pool create, liquidity add/remove, exact-input swap, LP accounting, and deterministic rounding.
5. Add success and failed receipts, event IDs, execution error codes, and deterministic state root coverage.
6. Add product E2E, execution E2E report generation, negative tests, invariant tests, restart proof, and export/import proof.
7. Update local devnet docs, proof notes, and final handoff.

Current result:
- Runtime execution support is implemented in the Rust devnet.
- `execution-e2e` writes a full report under `devnet/local/execution-e2e/`.
- Proof docs and handoff live in this directory.
