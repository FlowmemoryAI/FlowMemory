# Propagation Proof

## Transaction Propagation

The local node inbox now preserves multi-transaction batch order. When a node ingests locally authorized transactions, it records relay markers and writes compatible peer inbox entries when the static peer includes `nodeDir`.

The E2E submits a signed local faucet transaction to `node:network:a`. Node B becomes able to query the resulting local balance and faucet record after deterministic sync.

## Block Propagation Equivalent

The current transport is deterministic local-file reconciliation rather than LAN sockets. A node validates a peer chain before canonical adoption:

- block numbers must be sequential
- each parent hash must match the previous canonical hash
- each block hash must recompute correctly
- state `parentHash` and `nextBlockNumber` must match the block list

## Duplicate Protection

Duplicate transaction IDs are not included twice. The E2E report records `duplicateReceiptEvidence` for each submitted transaction ID, with one receipt on node A and one receipt after node B sync.

## Evidence

`txPropagationEvidence` and `sharedStateRootEvidence` are recorded in:

```text
devnet/local/network-e2e/network-e2e-report.json
```
