# Crash Recovery Proof

## Recovery Model

Every durable JSON write uses a temporary file followed by a rename into the target path. The manifest is written after block, header, transaction, receipt, event, object, index, and snapshot records. Startup removes leftover `*.tmp` files, validates the manifest against the snapshot, and rebuilds derived records/indexes from the snapshot when needed.

## Simulated Interruptions

Rust test: `durable_storage_recovers_missing_receipt_temp_file_and_duplicate_index`

- Simulates interruption during block write by leaving `.partial-block.tmp`.
- Simulates interruption during receipt write by deleting a receipt record.
- Simulates interruption during index write by adding a duplicate account tx id.
- Restart removes the temp file, regenerates the receipt/index data, and preserves the same state root.

Rust test: `durable_import_rejects_wrong_chain_and_malformed_roots`

- Simulates interruption during export by writing truncated export JSON.
- Import rejects the truncated export.

Rust test: `durable_storage_rejects_manifest_corruption_and_unclean_import`

- Simulates a mismatched canonical pointer by corrupting the latest snapshot parent hash.
- Simulates wrong finality by corrupting `finalizedHeight`.
- Startup rejects both instead of accepting a bad canonical state.

## Result

Canonical state is either unchanged and validated, rebuilt deterministically from the latest durable snapshot, or rejected. A half-written record does not become canonical without a matching valid manifest.
