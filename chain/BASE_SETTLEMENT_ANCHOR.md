# Base Settlement Anchor Placeholder

Status: prototype model, not a Base contract

The local devnet includes `AnchorBatchToBasePlaceholder` to model how a future FlowMemory appchain would summarize local state for Base. It does not deploy to Base, bridge assets, or make finality/security claims.

## Placeholder Fields

The local anchor model stores:

- `anchorId`
- `appchainChainId`
- `blockRangeStart`
- `blockRangeEnd`
- `stateRoot`
- `workReceiptRoot`
- `verifierReportRoot`
- `rootfieldStateRoot`
- `artifactCommitmentRoot`
- `previousAnchorId`
- `finalityStatus`

The `anchorId` is deterministically derived from those fields using canonical JSON and Keccak-256.

## Future Base Anchor Intent

A future Base anchor contract would store compact roots/report digests only:

- No raw AI memory.
- No embeddings.
- No model outputs.
- No media.
- No large evidence bundles.
- No secrets.
- No bridge assets by default.

## Required Before Real Base Anchoring

- Accepted work receipt schema.
- Accepted verifier report schema.
- Accepted artifact commitment schema.
- Multi-chain indexer reconciliation.
- Bridge/security review.
- Data availability review.
- Governance and upgrade policy.
- Testnet-only no-value prototype.

## No Claims

This placeholder is not a bridge, not a rollup proof, not a fraud proof, not a validity proof, and not a production settlement layer.
