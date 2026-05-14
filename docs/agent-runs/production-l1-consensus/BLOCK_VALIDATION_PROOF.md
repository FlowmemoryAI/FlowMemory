# Block Validation Proof

## Validation Rules

Accepted blocks must validate:

- chain id
- genesis hash
- authority-set id
- expected height
- parent hash
- timestamp bounds
- scheduled proposer identity
- proposer role membership
- no duplicate transaction ids
- transaction root
- receipt root
- event root
- state root for full block proposals
- local authority proof digest/signature
- block hash
- finalized-height conflicts

## Evidence

Rust tests cover:

- valid block proposal accepted and finalized
- invalid proposer rejected without consuming pending transactions
- wrong parent rejected with fork and misbehavior evidence
- wrong chain id rejected
- wrong genesis hash rejected
- wrong state root rejected at proposal validation

Runnable validation command:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- consensus-validate
```

