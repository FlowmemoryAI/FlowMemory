# FlowChain Private/Local Protocol Handoff

## Summary

This pass adds a runnable private/local protocol contract for downstream FlowChain agents. It includes 14 JSON schemas, deterministic fixtures, a genesis builder/hash validator, semantic fixture validation, and negative cases with stable `FC_PROTO_*` error codes.

## Validation Commands

```powershell
npm run validate:production-l1-protocol
npm run validate:production-l1-fixtures
node fixtures/production-l1/production-l1-tools.mjs build-genesis
node fixtures/production-l1/production-l1-tools.mjs validate-genesis
node fixtures/production-l1/production-l1-tools.mjs genesis-hash
```

## Schema Names

- `schemas/flowmemory/production-network-profile.schema.json`
- `schemas/flowmemory/production-genesis.schema.json`
- `schemas/flowmemory/production-validator-authority.schema.json`
- `schemas/flowmemory/production-account-public-metadata.schema.json`
- `schemas/flowmemory/production-transaction-envelope.schema.json`
- `schemas/flowmemory/production-transaction-payload.schema.json`
- `schemas/flowmemory/production-block-header.schema.json`
- `schemas/flowmemory/production-block-body.schema.json`
- `schemas/flowmemory/production-receipt.schema.json`
- `schemas/flowmemory/production-event.schema.json`
- `schemas/flowmemory/production-state-root-manifest.schema.json`
- `schemas/flowmemory/production-bridge-evidence.schema.json`
- `schemas/flowmemory/production-finality-receipt.schema.json`
- `schemas/flowmemory/production-export-snapshot.schema.json`

## Fixture Paths

- `fixtures/production-l1/profiles.json`
- `fixtures/production-l1/genesis.input.json`
- `fixtures/production-l1/genesis.json`
- `fixtures/production-l1/transactions.valid.json`
- `fixtures/production-l1/receipts.valid.json`
- `fixtures/production-l1/events.valid.json`
- `fixtures/production-l1/bridge-evidence.valid.json`
- `fixtures/production-l1/state-root-manifest.valid.json`
- `fixtures/production-l1/block.valid.json`
- `fixtures/production-l1/finality-receipt.valid.json`
- `fixtures/production-l1/export-snapshot.valid.json`
- `fixtures/production-l1/negative-fixtures.json`

## Implementation Contract

| schema | fixture | producer agent | consumer agent | command that validates it | open risk |
| --- | --- | --- | --- | --- | --- |
| `production-network-profile.schema.json` | `profiles.json` | protocol/HQ | runtime, wallet, bridge, RPC, dashboard | `npm run validate:production-l1-protocol` | Runtime must reject legacy aliases in signing domains. |
| `production-genesis.schema.json` | `genesis.input.json`, `genesis.json` | runtime | wallet, consensus, bridge, dashboard | `npm run validate:production-l1-fixtures` | Runtime must map this genesis to existing devnet config without losing old local fields. |
| `production-validator-authority.schema.json` | `genesis.json` | consensus | runtime, RPC, dashboard | `npm run validate:production-l1-fixtures` | Consensus agent must decide whether sequencer and validator stay separate later. |
| `production-account-public-metadata.schema.json` | `genesis.json` | wallet | runtime, bridge, RPC, dashboard | `npm run validate:production-l1-fixtures` | Wallet agent must implement real public-key/address derivation for non-fixture keys. |
| `production-transaction-envelope.schema.json` | `transactions.valid.json`, `negative-fixtures.json` | wallet/crypto | runtime, RPC, dashboard | `npm run validate:production-l1-fixtures` | Crypto agent must replace fixture digest signatures with the accepted signing helper. |
| `production-transaction-payload.schema.json` | `transactions.valid.json`, `negative-fixtures.json` | wallet/runtime/bridge/consensus | runtime, indexer, dashboard | `npm run validate:production-l1-fixtures` | Runtime must replace fixture precondition strings with typed state checks. |
| `production-block-header.schema.json` | `block.valid.json` | runtime | consensus, RPC, dashboard | `npm run validate:production-l1-fixtures` | Runtime must choose the exact mapping from existing `blockNumber` to `height`. |
| `production-block-body.schema.json` | `block.valid.json` | runtime | RPC, indexer, dashboard | `npm run validate:production-l1-fixtures` | Block body currently carries all valid transaction types in one fixture block. |
| `production-receipt.schema.json` | `receipts.valid.json` | runtime | RPC, indexer, dashboard | `npm run validate:production-l1-fixtures` | Runtime must emit failed receipts with structured `failureReason`. |
| `production-event.schema.json` | `events.valid.json` | runtime/indexer | RPC, dashboard | `npm run validate:production-l1-fixtures` | Indexer may need typed event-attribute schemas after dashboard usage settles. |
| `production-state-root-manifest.schema.json` | `state-root-manifest.valid.json` | runtime/crypto | consensus, RPC, dashboard | `npm run validate:production-l1-fixtures` | Runtime must implement component-root generation over real state maps. |
| `production-bridge-evidence.schema.json` | `bridge-evidence.valid.json`, `negative-fixtures.json` | bridge relayer | runtime, RPC, dashboard | `npm run validate:production-l1-fixtures` | Relayer must source Base `8453` evidence from bounded readers and preserve duplicate keys. |
| `production-finality-receipt.schema.json` | `finality-receipt.valid.json` | consensus | runtime, RPC, dashboard | `npm run validate:production-l1-fixtures` | Consensus agent must implement downgrade and superseded status semantics. |
| `production-export-snapshot.schema.json` | `export-snapshot.valid.json` | runtime/RPC | dashboard, operators, review | `npm run validate:production-l1-fixtures` | Export command must scan for secret material before publishing bundles. |

## Open Runtime/RPC Contract

- Accept only canonical profile IDs in envelopes.
- Validate `chainId`, `networkProfile`, and `genesisHash` before payload handling.
- Reject stale nonces before state transition.
- Recompute `payloadHash`, `txId`, receipt IDs, event IDs, component roots, state root, and block hash.
- Return stable `FC_PROTO_*` error codes for semantic rejection.
- Treat Base `8453` bridge source evidence as source-chain evidence only; destination state remains local/private.
