# FlowMemory Indexer V0

This package is a local, fixture-first FlowPulse indexer. It decodes sample receipts/logs, derives deterministic observation and cursor identities, models basic lifecycle states, and writes canonical JSON. It is not a production indexer.

## Commands

From the repository root:

```powershell
npm run index:fixtures
npm run index:base-sepolia -- --rpc-url <base-sepolia-rpc-url> --address <flowpulse-contract> --from-block <n> --to-block <n>
npm run index:base-canary -- --acknowledge-mainnet-canary --rpc-url <base-mainnet-rpc-url> --address <canary-flowpulse-contract> --from-block <n> --to-block <n>
npm run demo:indexer
npm test --prefix services/indexer
```

`npm run index:fixtures` writes:

```text
services/indexer/out/indexer-state.json
```

Use a custom output path:

```powershell
npm run index:fixtures -- --out out/custom-state.json
```

`npm run index:base-sepolia` writes:

```text
services/indexer/out/base-sepolia-indexer-state.json
services/indexer/out/base-sepolia-indexer-checkpoint.json
```

Use custom output paths:

```powershell
npm run index:base-sepolia -- --rpc-url <base-sepolia-rpc-url> --address <flowpulse-contract> --from-block 123456 --to-block 123999 --finalized-block 123900 --out out/base-sepolia-state.json --checkpoint-out out/base-sepolia-checkpoint.json
```

## Fixtures

Primary receipt fixtures:

```text
services/indexer/fixtures/flowpulse-receipts.json
```

The fixture set covers:

- valid rootfield registration
- valid root commit
- valid swap-derived memory signal
- duplicate observation
- removed/reorg-style log
- invalid commitment input
- unresolved artifact input
- unsupported pulse type
- reverted receipt
- malformed log

Legacy single-log fixture:

```text
services/indexer/fixtures/flowpulse-logs.json
```

## Decoder

The decoder accepts FlowPulse v0 logs with:

```text
FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)
```

`topic0` must equal:

```text
0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43
```

Decoded indexed topics:

- `pulseId`
- `rootfieldId`
- `actor`

Decoded data fields:

- `pulseType`
- `subject`
- `commitment`
- `parentPulseId`
- `sequence`
- `occurredAt`
- `uri`

Malformed logs are rejected into `rejectedLogs` with deterministic reason codes.

## Observation Identity

The contract emits `pulseId`. The indexer derives `observationId` only after receipt/log metadata exists:

```text
keccak256(abi.encode(
  "flowmemory.flowpulse.observation.v0",
  chainId,
  sourceContract,
  txHash,
  logIndex
))
```

`txHash` and `logIndex` are receipt/log-derived. They are not known by contracts or hooks during execution.

## Cursor Identity

The indexer derives `cursorId` for scan progress:

```text
keccak256(abi.encode(
  "flowmemory.indexer.cursor.v0",
  chainId,
  sourceSetId,
  blockNumber,
  blockHash,
  transactionIndex,
  logIndex
))
```

The `sourceSetId` is deterministic over chain id and the normalized emitting-contract set.

## Lifecycle States

V0 state values:

- `observed`
- `pending`
- `finalized`
- `removed`
- `superseded`
- `reorged`

The fixture state model supports a finality threshold and block-hash mismatch checks. It does not claim production reorg handling.

## Duplicate Handling

- `exactDuplicate`: same `observationId` and canonical observation JSON.
- `conflictingDuplicate`: same `observationId` with different canonical content.
- `pulseDuplicate`: same contract `pulseId` at a different observation location.
- `reorgReplacement`: same `pulseId` with changed block/log location.

Exact duplicates are idempotent. Conflicting duplicates are an indexer integrity risk. Pulse duplicates and reorg replacements stay visible for verifier/operator policy.

## Persistence

The persisted file wraps indexer state with:

```text
flowmemory.indexer.persistence.v0
```

The state itself declares:

```text
flowmemory.indexer.state.v0
```

JSON output is deterministic and contains observations, cursors, batches, rootfields, pulses, rejected logs, and duplicate records.

The Base Sepolia reader also writes a durable checkpoint:

```text
flowmemory.indexer.base_sepolia_checkpoint.v0
```

The checkpoint records the network, chain id, emitting addresses, scan range, finality threshold, state path, counts, and latest indexed block. It intentionally does not store RPC URLs or private keys.

The Base mainnet canary reader writes:

```text
flowmemory.indexer.base_canary_checkpoint.v0
```

It is for the documented V0 canary deployment only. It requires `--acknowledge-mainnet-canary`, an explicit RPC URL, explicit emitting addresses, and an explicit block range. It rejects non-Base-mainnet endpoints and refuses scans wider than 5,000 blocks. The checkpoint marks `productionReady: false` and intentionally does not store RPC URLs or private keys.

The JSON schema fixture lives at:

```text
services/indexer/fixtures/indexer-state.schema.json
```

## RPC Boundary

`readLocalRpcFlowPulseLogs` maps explicit JSON-RPC responses into the same raw fixture shape. It has no default RPC URL, no env file, no secrets, and tests use mocked fetch responses. Future live RPC indexing should be handled by a separate scoped issue.

`readBaseSepoliaFlowPulseLogs` is the current live reader boundary. It requires an explicit RPC URL and refuses endpoints unless `eth_chainId` returns Base Sepolia (`84532`). It is not a Base mainnet reader and does not make production-mainnet readiness claims.

`readBaseMainnetCanaryFlowPulseLogs` is the narrow Base mainnet canary boundary. It requires an explicit RPC URL and refuses endpoints unless `eth_chainId` returns Base mainnet (`8453`). It is not a broad production indexer and should only be used against known canary contract addresses and small block ranges.

See [docs/INDEXER_VERIFIER_MVP.md](../../docs/INDEXER_VERIFIER_MVP.md) for the full pipeline.
