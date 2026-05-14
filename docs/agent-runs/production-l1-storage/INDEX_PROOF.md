# Index Proof

Index file: `devnet/local/storage/indexes/storage-indexes.json`

The storage E2E import proves `txById=14`, `receiptByTxId=14`, `eventById=14`, `bridgeObservationById=1`, `bridgeCreditById=1`, and `replayKeyById=1` after export/import.

## Indexes And Query Paths

| Index | Query it enables | Record path |
| --- | --- | --- |
| `txById` | Tx id to block height/hash and receipt | `transactions/{tx_id}.json`, `receipts/{tx_id}.json` |
| `receiptByTxId` | Receipt lookup by tx id | `receipts/{tx_id}.json` |
| `eventById` | Event id to block/tx/event | `events/{event_id}.json` |
| `accountToTxIds` | Account to transaction ids | tx ids, then `txById` |
| `accountBalanceChanges` | Account balance-change history | index entry fields |
| `tokenToEventIds` | Token launch/mint/pool/swap/liquidity events | event ids, then `eventById` |
| `poolToEventIds` | Pool swaps, liquidity, and LP events | event ids, then `eventById` |
| `rootfieldToEventIds` | Rootfield protocol events | event ids, then `eventById` |
| `bridgeEventToObservationId` | Source event key or replay key to bridge observation | observation id, then `bridgeObservationById` |
| `bridgeObservationById` | Observation id to source evidence and credit ids | object map and credit ids |
| `bridgeCreditById` | Credit id to account, amount, source deposit | object map and index entry |
| `withdrawalIntentById` | Withdrawal intent id to local lock/burn and destination | object map and index entry |
| `releaseEvidenceById` | Release evidence id to withdrawal intent and source release | object map and index entry |
| `replayKeyById` | Consumed replay key lookup | index entry |

## Proof Coverage

- `durable_storage_writes_manifest_records_and_indexes` proves the manifest, block/header, object, snapshot, and index files exist and that bridge indexes survive reload.
- `durable_storage_recovers_missing_receipt_temp_file_and_duplicate_index` proves missing receipt files and duplicate account index entries are detected and regenerated.
- `durable_export_import_preserves_root_and_bridge_indexes` proves imported indexes preserve bridge credit and replay-key lookup.
- `npm run flowchain:storage:e2e` proves a future RPC agent can resolve transaction, receipt, event, account/token/pool/rootfield, and bridge identifiers from `storage-indexes.json` without scanning every block file.

## Performance Debt

No required query still needs a full chain scan for the persisted identifiers covered above. Future RPC methods should read the index file and then open the referenced record path.
