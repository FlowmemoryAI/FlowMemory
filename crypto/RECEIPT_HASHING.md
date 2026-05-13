# FlowMemory Receipt Hashing

Status: draft v0.

Receipts bind an observation to event args, off-chain artifact commitments, storage commitments, and evidence roots. They do not store raw artifacts or make verifier claims trustless.

## Event Args Hash

Type string:

```solidity
FlowPulseEventArgsV0(bytes32 pulseId,bytes32 rootfieldId,address actor,uint8 pulseType,bytes32 subject,bytes32 commitment,bytes32 parentPulseId,uint64 sequence,uint64 occurredAt,bytes32 uriHash)
```

Hash:

```text
eventArgsHash = keccak256(abi.encode(
  FLOWPULSE_EVENT_ARGS_TYPEHASH,
  pulseId,
  rootfieldId,
  actor,
  pulseType,
  subject,
  commitment,
  parentPulseId,
  sequence,
  occurredAt,
  uriHash
))
```

`uriHash = keccak256(bytes(uri))` over exact UTF-8 bytes. URI strings remain advisory log data.

## FlowPulse Receipt V0

Type string:

```solidity
FlowPulseReceiptV0(bytes32 observationId,bytes32 eventArgsHash,bytes32 artifactRoot,bytes32 storageReceiptCommitment,bytes32 evidenceRoot,uint16 receiptVersion)
```

Hash:

```text
receiptHash = keccak256(abi.encode(
  FLOWPULSE_RECEIPT_TYPEHASH,
  observationId,
  eventArgsHash,
  artifactRoot,
  storageReceiptCommitment,
  evidenceRoot,
  receiptVersion
))
```

Field notes:

- `observationId` binds receipt metadata that only exists after execution.
- `eventArgsHash` binds the FlowPulse event args.
- `artifactRoot` is zero when no artifact is attached.
- `storageReceiptCommitment` is zero when no storage claim exists.
- `evidenceRoot` commits to verifier evidence, openings, or report inputs. It is zero if no evidence set exists.
- `receiptVersion` starts at `0`.

## Storage Receipt Commitment

Type string:

```solidity
FlowMemoryStorageReceiptCommitmentV0(bytes32 artifactRoot,bytes32 providerId,bytes32 locationCommitment,bytes32 retentionPolicyHash,bytes32 encryptionCommitment,bytes32 availabilitySampleRoot,uint64 issuedAtUnixMs,uint64 expiresAtUnixMs,bytes32 nonce)
```

Hash:

```text
storageReceiptCommitment = keccak256(abi.encode(
  STORAGE_RECEIPT_TYPEHASH,
  artifactRoot,
  providerId,
  locationCommitment,
  retentionPolicyHash,
  encryptionCommitment,
  availabilitySampleRoot,
  issuedAtUnixMs,
  expiresAtUnixMs,
  nonce
))
```

This is a commitment to a storage claim. It is not a guarantee that the artifact will always be retrievable.

## Replay Protection

Receipt replay protection comes from:

- `observationId`, which binds chain id, contract, block, tx, log position, event signature, pulse id, and rootfield id
- `eventArgsHash`, which binds emitted event contents
- `receiptVersion`, which prevents silent schema mutation
- signature envelopes, which bind chain id, deployment id, key id, expiry, sequence or nonce, and verifier set root

Verifiers must reject:

- receipts whose `observationId` cannot be recomputed from the receipt and log
- event args that do not match the log payload
- receipts from reorged observations unless the report status is explicitly historical or reorged
- unknown receipt versions
- storage receipt commitments outside their retention window for current availability claims

## Hash Chain Use

Receipt hash chains can model order:

```text
nextChainHead = keccak256(abi.encode(chainHeadTypeHash, previousReceiptHash, receiptHash, sequence))
```

Hash chains do not replace Merkle inclusion proofs for artifacts. Use hash chains for ordered receipt progression and Merkle roots for efficient artifact inclusion/opening.

## Work Receipt ID

Workers can produce replay-resistant work receipt identifiers over a receipt and worker sequence.

Type string:

```solidity
FlowMemoryWorkReceiptV0(bytes32 observationId,bytes32 receiptHash,bytes32 workerId,uint64 workerSequence,bytes32 nonce)
```

Hash:

```text
workReceiptId = keccak256(abi.encode(
  WORK_RECEIPT_TYPEHASH,
  observationId,
  receiptHash,
  workerId,
  workerSequence,
  nonce
))
```

`workReceiptId` is an off-chain coordination identifier. It does not prove that the worker's output is correct unless a verifier policy checks the underlying work and signature.
