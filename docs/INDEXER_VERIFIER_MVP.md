# Indexer Verifier MVP

This document describes the runnable FlowMemory Indexer + Verifier V0 local package. It advances issues #13, #14, #43, #44, #45, #46, #47, #54, and #55 by proving the off-chain path with fixtures, pure functions, local JSON persistence, CLIs, and tests. It now also includes a constrained Base Sepolia reader path for explicit FlowPulse contract addresses.

V0 is non-production. It does not include tokenomics, a verifier network, production RPC deployment, a production database, proof infrastructure, or chain/L1 implementation.

## Packages

- `services/shared`: FlowPulse constants, narrow ABI helpers, Keccak-256, canonical JSON, observation/cursor/report identity helpers, fixture parser, and tests.
- `services/indexer`: fixture receipt ingestion, FlowPulse log decoding, observation identity, cursor identity, duplicate/reorg state modeling, JSON persistence, CLI, and tests.
- `services/verifier`: fixture artifact resolver, commitment checks, report schema, deterministic report IDs, JSON persistence, CLI, and tests.

Run from the repository root:

```powershell
npm test
npm run index:fixtures
npm run index:base-sepolia -- --rpc-url <base-sepolia-rpc-url> --address <flowpulse-contract> --from-block <n> --to-block <n>
npm run verify:fixtures
npm run e2e
```

The fixture commands require no secrets and no live RPC. The Base Sepolia command requires an explicit RPC URL, refuses non-Base-Sepolia chain ids, and does not store the RPC URL in output artifacts.

## FlowPulse Input

Contracts emit `FlowPulse` events. V0 reads those events only after receipts/logs exist.

Event signature:

```text
FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)
```

`topic0`:

```text
0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43
```

Indexed topics:

- `pulseId`
- `rootfieldId`
- `actor`

Data fields:

- `pulseType`
- `subject`
- `commitment`
- `parentPulseId`
- `sequence`
- `occurredAt`
- `uri`

Receipt/log metadata:

- `chainId`
- `blockNumber`
- `blockHash`
- `transactionHash` / `txHash`
- `transactionIndex`
- `logIndex`
- `address` / `emittingContract`
- `status`
- provider `removed` flag when present

Contracts do not know `txHash`, `transactionIndex`, `logIndex`, or final block metadata during execution. The indexer derives those values from receipts/logs.

## Indexer Pipeline

1. Load receipt fixtures from `services/indexer/fixtures/flowpulse-receipts.json`.
2. Drop reverted receipts into `rejectedLogs` with `receipt.reverted`.
3. Decode only logs whose `topic0` matches FlowPulse v0.
4. Normalize hex, addresses, hashes, and integer-like values.
5. Derive `observationId` from receipt/log location.
6. Derive `cursorId` from source-set and block/log ordering metadata.
7. Assign lifecycle state from fixture finality and reorg inputs.
8. Detect exact duplicates, conflicting duplicates, pulse duplicates, and reorg replacements.
9. Persist deterministic JSON to `services/indexer/out/indexer-state.json`.

Malformed logs are rejected with deterministic reason codes and do not become verifier inputs.

## Base Sepolia Reader Path

`services/indexer/src/base-sepolia.ts` provides the first live testnet reader path.

It requires:

- `--rpc-url`
- one or more `--address` values
- `--from-block`
- `--to-block`

It enforces:

- `eth_chainId` must be Base Sepolia (`84532`)
- block values must be explicit decimal or `0x` quantities
- emitting addresses must be explicit EVM addresses
- output files must not contain RPC URLs or private keys

It writes:

```text
services/indexer/out/base-sepolia-indexer-state.json
services/indexer/out/base-sepolia-indexer-checkpoint.json
```

This is a testnet reader boundary, not a production mainnet indexer.

## Identity Model

`pulseId` is contract-emitted protocol data. It is not the canonical observed-log identity.

`observationId` is indexer-derived:

```text
keccak256(abi.encode(
  "flowmemory.flowpulse.observation.v0",
  chainId,
  sourceContract,
  txHash,
  logIndex
))
```

`sourceContract` is the normalized emitting contract address. `txHash` and `logIndex` come from the receipt/log. `blockHash`, `blockNumber`, `transactionIndex`, `eventSignature`, and decoded FlowPulse fields are stored with the observation but are not part of the V0 `observationId` preimage.

`cursorId` is indexer-derived scan progress identity:

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

`sourceSetId` is a deterministic hash of the chain id and normalized emitting-contract set:

```text
keccak256("flowmemory.indexer.source_set.v0|<chainId>|<sorted lower-case addresses>")
```

`reportId` is verifier-derived:

```text
keccak256(canonical_json(reportCore))
```

The report digest excludes wall-clock timestamps, local paths, signatures, and operator notes.

## Indexer States

V0 observation lifecycle states:

- `observed`: decoded from a successful receipt/log with no finality policy applied.
- `pending`: decoded but above the configured fixture finality threshold.
- `finalized`: at or below the configured fixture finality threshold.
- `removed`: provider fixture marks the log as removed.
- `superseded`: older observation for the same `pulseId` was replaced by another observation.
- `reorged`: fixture canonical block-hash check says the observation's block is no longer canonical.

This is a fixture state model, not production reorg handling.

## Verifier Pipeline

1. Read persisted indexer state from `services/indexer/out/indexer-state.json`, or build it from fixtures if missing.
2. Load fixture artifacts from `services/verifier/fixtures/artifacts.json`.
3. Use resolver policy `flowmemory.resolver.policy.v0.fixture`.
4. Refuse arbitrary HTTP/IPFS fetching in V0; fixture URIs are lookup hints only.
5. Apply supported commitment rules.
6. Generate canonical report cores and `reportId` digests.
7. Persist deterministic JSON to `services/verifier/out/reports.json`.

## Verifier Statuses

V0 report statuses:

- `valid`: supported checks passed against allowed fixture evidence.
- `invalid`: supported checks ran and at least one required check failed.
- `unresolved`: required fixture evidence is missing or policy-rejected.
- `unsupported`: pulse type or artifact semantics are outside V0 rules.
- `reorged`: observation is removed or reorged and should not be treated as current canonical evidence.

Earlier planning terms map as follows: `verified` becomes `valid`, `failed` becomes `invalid`, and `observed`, `stale`, `disputed`, and `superseded` remain future report or lifecycle concepts outside the V0 report result enum.

## Commitment Checks

For `ROOTFIELD_REGISTERED` (`pulseType = 1`):

- `subject` must equal `rootfieldId`.
- `commitment` must equal `keccak256(abi.encode(schemaHash, metadataHash))`.
- `schemaHash` and `metadataHash` come from allowed fixture evidence.

For `ROOT_COMMITTED` (`pulseType = 2`):

- `subject` must equal `root`.
- `commitment` must equal `keccak256(abi.encode(root, artifactCommitment))`.
- `root` and `artifactCommitment` come from allowed fixture evidence.

Unknown pulse types return `unsupported`, not `valid`.
Missing evidence returns `unresolved`, not `invalid`.
Bad commitments or subject mismatches return `invalid`.
Removed or reorged observations return `reorged`.

## Persistence

Indexer persistence schema:

```text
flowmemory.indexer.persistence.v0
```

Indexer state schema:

```text
flowmemory.indexer.state.v0
```

Verifier persistence schema:

```text
flowmemory.verifier.persistence.v0
```

Verifier report schema:

```text
flowmemory.verifier.report.v0
```

The JSON writer uses canonical key ordering, no wall-clock timestamps, no secrets, and stable fixture ordering.

## Off-Chain Boundary

These stay off-chain in V0:

- Raw artifacts and evidence bundles.
- Resolver caches.
- Full verifier reports unless a later storage policy intentionally persists them elsewhere.
- AI memory, model data, embeddings, media, and heavy artifacts.
- Private keys, RPC keys, API keys, seed phrases, webhook URLs, and local operator notes.

Future on-chain candidates:

- Compact report digests.
- Report-root commitments.
- Verifier attestations or signatures.
- Dispute state.
- Proof results.

Those are future protocol decisions, not part of this local package.

## Handoff Outputs

- Dashboard-friendly indexer state: `services/indexer/out/indexer-state.json`
- Base Sepolia reader state: `services/indexer/out/base-sepolia-indexer-state.json`
- Base Sepolia checkpoint: `services/indexer/out/base-sepolia-indexer-checkpoint.json`
- Chain/devnet-friendly verifier report fixture: `services/verifier/out/reports.json`
- Indexer state JSON schema: `services/indexer/fixtures/indexer-state.schema.json`
- Verifier report JSON schema: `services/verifier/fixtures/verification-report.schema.json`
- Receipt fixtures: `services/indexer/fixtures/flowpulse-receipts.json`
- Artifact fixtures: `services/verifier/fixtures/artifacts.json`

## Open Questions

- What exact artifact canonicalization format should produce `artifactCommitment`?
- What finality depth should a future production Base RPC indexer use?
- Should live RPC indexing persist cursors before or after report generation in hosted service mode?
- Should future attestations use EIP-712, raw digest signatures, or another envelope?
- How should dashboards display pulse duplicates versus exact duplicate observations?

## PR-Ready Summary

What changed:

- Added a runnable fixture-first indexer/verifier package with CLIs, persistence, schemas, and tests.
- Added a constrained Base Sepolia reader with durable local state and checkpoint output.
- Defined contract `pulseId`, indexer `observationId`, indexer `cursorId`, and verifier `reportId`.
- Defined V0 lifecycle states, duplicate behavior, resolver policy boundaries, and report statuses.

Why it changed:

- The service layer needs a deterministic off-chain path and a constrained testnet read path before production storage, verifier networking, or on-chain attestations.

Checks:

- `npm test`
- `npm run index:fixtures`
- `npm run index:base-sepolia -- --rpc-url <base-sepolia-rpc-url> --address <flowpulse-contract> --from-block <n> --to-block <n>`
- `npm run verify:fixtures`
- `npm run e2e`

Risks and follow-ups:

- V0 fixtures are synthetic and do not claim production reorg handling.
- Durable database storage, artifact canonicalization, report signing, attestations, and production live indexing need separate scoped issues.
