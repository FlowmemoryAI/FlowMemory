# Production L1 Networking Notes

## Boundaries

- This work is private/local L1 networking only.
- It does not introduce public validators, production consensus, tokenomics, production bridge security, or mainnet deployment claims.
- Bridge observation from Base remains an operator or relayer function. When represented inside the local L1, bridge credits must be normal local signed or authorized transactions and duplicate credits must not double apply.

## Initial Context

- The existing devnet is a deterministic Rust CLI with persisted local state and no multi-node networking yet.
- `docs/CURRENT_STATE.md` identifies long-running multi-process node behavior and LAN peer mode as missing.
- The mission allows a deterministic local multi-process or file-relay sync equivalent if sockets would be too large for this increment.

## Implementation Notes

- Implemented the first networking increment as deterministic local-file private sync, not LAN sockets.
- Static peers now carry chain ID, genesis hash, protocol version, listen/bind address strings, role, state path, and node directory.
- The runtime validates peer block continuity before adoption and records exact rejection evidence.
- Multi-transaction inbox submission is batched to preserve order for dependent transaction groups.
- Duplicate transaction IDs are skipped after first inclusion so relay loops do not double-include the same tx.
- `origin/main` advanced with bridge/contracts package aliases while this branch was running; `package.json` preserves those upstream aliases plus the new network alias.
