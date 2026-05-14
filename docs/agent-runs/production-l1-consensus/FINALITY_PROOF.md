# Finality Proof

## Local Finality Rule

The private/local single-authority profile finalizes each validated canonical
block immediately after proposal validation and authority proof verification.

Each finalized block writes:

- `consensusState.finalizedHeight`
- `consensusState.finalizedHash`
- `consensusState.finalizedStateRoot`
- `chainFinalityReceipts[receiptId]`
- finality certificate with authority-set id, block hash, state root, signer id,
  quorum weight, and total weight

## Commands

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- finality-status
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- write-finality-proof --out devnet/local/finality-proof.json
```

Export/import preservation is covered by `cli_export_import_state_round_trip_is_deterministic`.

