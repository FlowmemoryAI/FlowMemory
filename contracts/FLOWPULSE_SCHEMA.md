# FlowPulse Schema v0

FlowPulse is the first shared event stream for FlowMemory protocol activity. It is intentionally small and commitment-oriented: contracts emit roots, commitments, and short pointers while indexers and verifiers reconstruct full context from receipts, logs, and off-chain artifacts.

## Solidity Event

```solidity
event FlowPulse(
    bytes32 indexed pulseId,
    bytes32 indexed rootfieldId,
    address indexed actor,
    uint8 pulseType,
    bytes32 subject,
    bytes32 commitment,
    bytes32 parentPulseId,
    uint64 sequence,
    uint64 occurredAt,
    string uri
);
```

## Fields

- `pulseId`: Domain-separated identifier created by the emitting contract. It is not a replacement for receipt metadata.
- `rootfieldId`: Namespace for the committed state stream.
- `actor`: Account that caused the pulse.
- `pulseType`: Stable numeric type. Initial reserved values are `1` for rootfield registration, `2` for root commitment, and `3` for rootfield status changes.
- `subject`: Type-specific subject. For registration this is the rootfield id. For root commitment this is the committed root.
- `commitment`: Type-specific hash commitment to off-chain data or metadata. Heavy AI, model, memory, artifact, and media data stays off-chain.
- `parentPulseId`: Optional prior pulse reference for chains of work or verification.
- `sequence`: Monotonic sequence within the rootfield namespace.
- `occurredAt`: Block timestamp observed by the emitting contract.
- `uri`: Optional short pointer to off-chain metadata or evidence. It must not be treated as arbitrary on-chain storage.

## Receipt Boundary

FlowPulse does not include `txHash` or `logIndex`. Those values are not available to contracts during execution, including hook execution. Indexers and verifiers must derive them after reading transaction receipts and logs.

## v0 Assumptions

- `pulseId` is unique within the emitting contract's domain but indexers should still key canonical observations by chain id, contract address, transaction hash, and log index.
- `uri` values are advisory pointers. Verifiers must validate off-chain content against the emitted `commitment`.
- Pulse type expansion should happen by reserving new numeric values and documenting their subject and commitment semantics before contracts depend on them.
