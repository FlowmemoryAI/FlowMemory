# Block Production Proof

## Behavior

The node can produce blocks through:

- Manual tick: `tick`.
- Single block compatibility path: `run-block`.
- Bounded loop: `node --max-blocks <n>`.
- Operator loop: `node --block-ms <ms>`.

Each produced block records:

- Block number.
- Parent hash.
- Logical time.
- Deterministically ordered transaction ids.
- Per-transaction receipts.
- Per-transaction events.
- State root.
- Receipt root.
- Event root.
- Finalized height.
- Block hash.

The same block construction path is used by manual and node-loop block production.

## Smoke Evidence

`npm run flowchain:node:smoke` produced 21 persisted blocks after the restart leg. The final status file recorded:

```text
latestHeight: 21
finalizedHeight: 20
latestHash: 0xd16b721acf982ecec33b49f35c4b031d1cac47c6526ae28daa336e6f1b8716cd
stateRoot: 0x3e362fa09ddd18626c6213f49863531c7e93cd7c13708894aa19ff9d700201e8
receiptRoot: 0xd251f2173f1458704e07290d7af33f7b0b2dc783edd0f74a545d1363f0c3d053
eventRoot: 0x83e9f2740d4d0fa2514e7180636a7f1517335398593cdc2430b104b845ae4635
```

The smoke report is `devnet/local/node-smoke/production-node-smoke-report.json`.
