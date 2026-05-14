# Production L1 Runtime Plan

## Scope

- Extend the existing Rust devnet in `crates/flowmemory-devnet/`.
- Keep runtime outputs under `devnet/` and wrapper changes under `infra/scripts/flowchain-*.ps1`.
- Keep crypto fixtures and schemas read-only.
- Do not create a second runtime.

## Phases

1. Map the current CLI, state files, transaction types, block format, and protocol gaps. Done in `NOTES.md`.
2. Add persistent node config, status, logs, and bounded or long-running start behavior. Done in the Rust devnet CLI and node wrappers.
3. Add signed envelope intake, validation, mempool persistence, duplicate/replay rejection, and rejection evidence. Done through `submit-tx`, file inbox ingestion, and runtime validation.
4. Produce deterministic blocks with receipts, events, roots, and query indexes. Done through `node`, `tick`, `run-block`, and stored receipt/event indexes.
5. Add restart, export/import, and node smoke proof covering accepted and rejected transactions. Done through `node-restart`, `export-state`, `import-state`, and `npm run flowchain:node:smoke`.
6. Update wrapper scripts, docs, handoff files, and acceptance evidence. Done in the production runtime run docs and `docs/LOCAL_DEVNET.md`.
