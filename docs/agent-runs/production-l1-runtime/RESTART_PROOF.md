# Restart Proof

## Behavior

The runtime restarts from disk through the same state file and node directory:

```powershell
npm run flowchain:node:restart
```

or:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- node-restart --max-blocks 1
```

Persisted recovery covers:

- Latest height.
- Latest hash.
- Finalized height.
- State root.
- Account balances.
- Pending mempool transactions.
- Transactions and receipts.
- Events.
- Bridge observations, credits, and replay keys.
- Withdrawal intents.

## Smoke Evidence

`npm run flowchain:node:smoke` stopped and restarted the node, then queried the signed transaction receipt after restart.

State root before and after the restart leg stayed:

```text
0x3e362fa09ddd18626c6213f49863531c7e93cd7c13708894aa19ff9d700201e8
```

The latest hash changed because the restart leg intentionally produced one additional empty persisted block:

```text
beforeRestartLatestHash: 0xe42af946fbe1ebf485333fa683e6ec724dbe7931e66506408808d3bf33cab1a9
afterRestartLatestHash: 0xd16b721acf982ecec33b49f35c4b031d1cac47c6526ae28daa336e6f1b8716cd
```

Export/import then preserved both the final state root and final latest hash:

```text
importedStateRoot: 0x3e362fa09ddd18626c6213f49863531c7e93cd7c13708894aa19ff9d700201e8
importedLatestHash: 0xd16b721acf982ecec33b49f35c4b031d1cac47c6526ae28daa336e6f1b8716cd
preserved: true
```
