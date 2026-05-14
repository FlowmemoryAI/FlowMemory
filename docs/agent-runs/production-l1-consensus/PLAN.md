# Production L1 Consensus Plan

## Scope

- Work inside `crates/flowmemory-devnet/`, `devnet/`, `docs/DECISIONS/`, `docs/LOCAL_DEVNET.md`, `docs/agent-runs/production-l1-consensus/`, and `package.json` only if a consensus smoke alias is needed.
- Implement private/local authority-set consensus behavior in the existing Rust devnet.
- Preserve no-value, local/private semantics and avoid public-validator, tokenomics, production bridge, or audited-crypto claims.

## Context Read

- `AGENTS.md`
- `docs/START_HERE.md`
- `docs/FLOWMEMORY_HQ_CONTEXT.md`
- `docs/CURRENT_STATE.md`
- `docs/LOCAL_DEVNET.md`
- `docs/ROOTFLOW_V0.md`
- `docs/FLOW_MEMORY_V0.md`
- `docs/V0_LAUNCH_ACCEPTANCE.md`
- Relevant FlowChain and decision records for local/private boundaries
- Production runtime tracking notes, read-only, from the sibling runtime worktree

## Phases

1. Map current block, state, root, transaction, and export/import behavior.
2. Add local/private validator identity and authority-set metadata.
3. Validate proposed blocks by chain id, genesis hash, parent, height, timestamp, proposer, transaction ordering, roots, and duplicate/replay boundaries.
4. Add deterministic fork choice, rejected/orphan branch evidence, and misbehavior records.
5. Add local finality state, certificate/receipt output, finalized height/hash/root queries, and restart/export/import preservation.
6. Add CLI commands and root smoke alias for consensus validation, validator set, finality status, fork-choice proof, and finality proof output.
7. Add tests, generated smoke report, proof documents, and handoff.

