# Merkle Roots And Artifact Commitments

Status: draft v0.

FlowMemory keeps raw artifacts off-chain and commits to them through explicit root schemes.

## Artifact Root V0

Type string:

```solidity
FlowMemoryArtifactRootV0(bytes32 schemeId,bytes32 manifestHash,bytes32 contentMerkleRoot,uint64 byteLength,uint32 chunkSize,bytes32 mediaTypeHash,bytes32 metadataHash)
```

Hash:

```text
artifactRoot = keccak256(abi.encode(
  ARTIFACT_ROOT_TYPEHASH,
  schemeId,
  manifestHash,
  contentMerkleRoot,
  byteLength,
  chunkSize,
  mediaTypeHash,
  metadataHash
))
```

Default scheme:

```text
FM-MERKLE-KECCAK256-BINARY-V0
schemeId = keccak256(bytes("FM-MERKLE-KECCAK256-BINARY-V0"))
```

## Merkle Format

For `FM-MERKLE-KECCAK256-BINARY-V0`:

```text
chunkHash = keccak256(chunkBytes)
leafHash = keccak256(abi.encode(MERKLE_LEAF_TYPEHASH, index, offset, length, chunkHash))
nodeHash = keccak256(abi.encode(MERKLE_INTERNAL_NODE_TYPEHASH, leftHash, rightHash))
emptyRoot = keccak256(bytes("FM-MERKLE-KECCAK256-BINARY-V0:EMPTY"))
```

Leaf type string:

```solidity
FlowMemoryMerkleLeafV0(uint64 index,uint64 offset,uint32 length,bytes32 chunkHash)
```

Internal node type string:

```solidity
FlowMemoryMerkleInternalNodeV0(bytes32 leftHash,bytes32 rightHash)
```

Rules:

- Leaves are ordered by `index`.
- `offset` is the byte offset in the reconstructed artifact.
- `length` is the exact chunk byte length.
- Adjacent pairs form node hashes.
- An odd unpaired hash is promoted unchanged to the next level.
- A one-chunk artifact uses the leaf hash as `contentMerkleRoot`.
- Empty artifacts use `emptyRoot` and `byteLength = 0`.

## Manifest And Metadata

`manifestHash` commits to canonical JSON describing:

- scheme
- version
- byte length
- chunk size
- chunk indexes, offsets, lengths, and chunk hashes

`metadataHash` commits to canonical JSON for non-sensitive metadata. Sensitive metadata should be encrypted, salted, or omitted. Hashing low-entropy private metadata without salt is not private.

## CID And URI Policy

FlowMemory roots should be hash-first. CIDs and URIs can be useful locators, but they are advisory unless their bytes are committed and later opened.

Comparison:

- CID/hash-only roots are better for contracts and deterministic verification.
- Advisory URI fields are better for operator ergonomics but leak bytes into logs and can be unavailable, mutable, or misleading.
- A URI should never be the only proof that content matches a commitment.

MVP recommendation:

- Use `artifactRoot` and `storageReceiptCommitment` as cryptographic commitments.
- Keep `uri` as advisory log data.
- Hash URI bytes in receipts as `uriHash` when a report needs to bind the exact emitted string.
- Prefer locator commitments for sensitive or mutable storage paths.

## Merkle Inclusion Vs Receipt Chains

Merkle inclusion proofs answer: "Does this chunk or leaf belong to this artifact root?"

Receipt hash chains answer: "Did this receipt extend a prior ordered receipt stream?"

Use Merkle proofs for artifact openings. Use receipt chains or Rootflow for ordered progression. Do not use a linear receipt chain as a substitute for efficient artifact inclusion proofs.

## Rootflow And Rootfield

Rootfield is the namespace and state-commitment side. It scopes roots, owners, counters, and status.

Rootflow should be the ordered receipt/report progression side. It can chain receipt hashes or report ids into checkpoints.

Open boundary:

- Rootfield answers "what state/root is currently committed for this namespace?"
- Rootflow answers "what ordered work/report history led here?"

Contracts should not depend on that split until a decision record accepts it.

## Rootfield Namespace And Root Commitment IDs

Rootfield namespaces can be identified without reading mutable registry state by hashing:

```solidity
FlowMemoryRootfieldNamespaceV0(uint256 chainId,address registry,bytes32 rootfieldId,bytes32 schemaHash)
```

Root commitments bind a rootfield, current root, artifact commitment, parent pulse, and sequence:

```solidity
FlowMemoryRootCommitmentV0(bytes32 rootfieldId,bytes32 root,bytes32 artifactCommitment,bytes32 parentPulseId,uint64 sequence)
```

These helpers are exported as `rootfieldNamespaceId` and `rootCommitment`. They are schema tools for services and future adapters; they are not a production RootfieldRegistry migration.
