# Protocol Inventory

| Layer | Protocol object | Fixture | Downstream owner |
| --- | --- | --- | --- |
| Network profiles | `production-network-profile.schema.json` | `profiles.json` | runtime, wallet, bridge |
| Chain ID and genesis hash | `production-genesis.schema.json` | `genesis.input.json`, `genesis.json` | crypto, runtime |
| Genesis state | `production-genesis.schema.json` | `genesis.json` | runtime, RPC, dashboard |
| Account/address model | `production-account-public-metadata.schema.json` | `genesis.json` | wallet, runtime, RPC |
| Transaction envelope | `production-transaction-envelope.schema.json` | `transactions.valid.json` | wallet, crypto, runtime |
| Payload catalog | `production-transaction-payload.schema.json` | `transactions.valid.json`, `negative-fixtures.json` | runtime, bridge, consensus |
| Block header/body | `production-block-header.schema.json`, `production-block-body.schema.json` | `block.valid.json` | runtime, RPC, indexer |
| Receipts/events | `production-receipt.schema.json`, `production-event.schema.json` | `receipts.valid.json`, `events.valid.json` | runtime, indexer, dashboard |
| State roots | `production-state-root-manifest.schema.json` | `state-root-manifest.valid.json` | runtime, crypto, consensus |
| Fork choice/finality | `production-finality-receipt.schema.json` | `finality-receipt.valid.json` | consensus, RPC |
| Positive flow | All required schemas | all `*.valid.json` fixtures | all implementation agents |
| Negative cases | transaction, state root, bridge semantic checks | `negative-fixtures.json` | runtime, RPC, wallet, bridge |

## Runtime Field Alignment

The schema uses camelCase to match existing generated JSON and control-plane responses. It aligns with the Rust devnet concepts for transactions, blocks, receipts, deterministic roots, local balances, token definitions, pools, LP positions, memory objects, challenges, and finality receipts. Where the current Rust model uses local names such as `blockNumber` and `logicalTime`, this contract adds the profile-bound header vocabulary that the runtime agent must map explicitly.

## Control-Plane Field Alignment

The inventory maps to current control-plane method families: `chain_status`, `block_get`, `transaction_get`, `account_get`, `balance_get`, `token_get`, `pool_get`, `bridge_observation_get`, `bridge_credit_get`, `withdrawal_get`, `challenge_get`, `finality_get`, and raw JSON export.
