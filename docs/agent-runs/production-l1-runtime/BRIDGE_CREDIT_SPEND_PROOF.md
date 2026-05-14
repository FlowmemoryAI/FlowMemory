# Bridge Credit Spend Proof

## Behavior

The local runtime implements a private/test bridge-credit execution path for Base evidence handoff:

- `ApplyBridgeCredit` requires `sourceChainId` `8453`.
- The source tx hash, log index, source contract, deposit id, observation id, evidence hash, verifier, and replay key are stored.
- The replay key is consumed exactly once.
- The local recipient is credited with local test units or an existing local token asset.
- A `bridge_credit_applied` event and receipt are written.
- The credited account can spend local test units through `TransferLocalTestUnits`.
- `RequestWithdrawal` records a test-mode withdrawal intent without broadcasting a production withdrawal.

This is local/private runtime behavior only. It is not an audited bridge or production withdrawal system.

## Smoke Evidence

`npm run flowchain:node:smoke` applied credit:

```text
creditId: bridge-credit:node-smoke:001
sourceChainId: 8453
recipientAccountId: local-account:bridge:alice
amountUnits: 75
```

Alice then spent 25 local test units to:

```text
local-account:bridge:bob
```

The smoke report recorded:

```text
recipientCanSpend: true
bobBalance: 25
withdrawalIntentRecorded: true
```

Queryable paths:

```powershell
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-bridge-credit --id bridge-credit:node-smoke:001
cargo run --manifest-path crates/flowmemory-devnet/Cargo.toml -- query-account --id local-account:bridge:bob
```
