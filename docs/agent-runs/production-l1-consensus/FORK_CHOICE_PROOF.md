# Fork Choice Proof

## Rule

Fork choice is deterministic:

1. Choose the highest valid height.
2. For equal-height valid branches, choose the lexicographically lowest block
   hash.
3. Reject invalid branches and record fork evidence.
4. Record duplicate proposal misbehavior when the same proposer produces
   competing blocks at the same height.
5. Reject branches that conflict with finalized height.

## Command

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- fork-choice-test --out devnet/local/fork-choice-proof.json
```

The consensus smoke writes `devnet/local/consensus-smoke/fork-choice-proof.json`.

