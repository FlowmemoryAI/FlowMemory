# Sync Proof

## Sync Behavior

Nodes perform header/block-summary style validation from the peer state before adopting a higher peer head. The sync path rejects incompatible or invalid peers and records exact blocker evidence in `peers[]` and `rejectedBlocks[]`.

## Restart Proof

The E2E flow:

1. Starts node A and node B.
2. Reconciles node B from node A.
3. Stops node B.
4. Advances node A.
5. Restarts node B.
6. Reconciles both nodes to the same height and state root.

Latest successful evidence:

- Final height: `9`
- Final state root: `0x662b581b0723af4e6d707a150883df42c705051f3a1f7e1bfb8e6e6ab8aaf75f`
- `restartEvidence.caughtUp`: `true`

## Negative Sync Cases

The report includes:

- `wrongChain`
- `wrongGenesis`
- `unsupportedProtocol`
- `staleBlock`
- `invalidParentBlock`

Report path:

```text
devnet/local/network-e2e/network-e2e-report.json
```
