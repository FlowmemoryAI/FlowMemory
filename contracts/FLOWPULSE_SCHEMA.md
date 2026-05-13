# FlowPulse Schema v0

FlowPulse is the first shared event stream for FlowMemory protocol activity. It is intentionally small and commitment-oriented: contracts emit roots, commitments, and advisory URI strings while indexers and verifiers reconstruct full context from receipts, logs, and off-chain artifacts. Contract state is compact by design; it is not an artifact store, model store, bridge state machine, or production L1 state surface.

For the private/local FlowChain testnet, FlowPulse contracts are optional anchors and event mirrors. The private L1 runtime is the Rust/local devnet and local service stack, not Solidity.

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
- `pulseType`: Stable numeric type. Current reserved values are `1` for rootfield registration, `2` for root commitment, `3` for rootfield lifecycle/status changes such as deactivation or ownership transfer, and `4` for swap-derived memory signals emitted by the V0 hook adapter.
- `subject`: Type-specific subject. For registration and rootfield lifecycle changes this is the rootfield id. For root commitment this is the committed root. For swap-derived memory signals this is the pool id.
- `commitment`: Type-specific hash commitment to off-chain data or metadata. Heavy AI, model, memory, artifact, and media data stays off-chain.
- `parentPulseId`: Optional prior pulse reference for chains of work or verification.
- `sequence`: Monotonic sequence within the rootfield namespace.
- `occurredAt`: Block timestamp observed by the emitting contract.
- `uri`: Arbitrary advisory string supplied by the caller. In `RootfieldRegistry`, `metadataURI` and `evidenceURI` are not length-limited, content-checked, format-checked, resolvability-checked, or otherwise enforced as short pointers by the contract. Emitted URI bytes are still on-chain log data.

Warning: Do not place sensitive data or heavy raw data in URI fields. The current skeleton relies on caller discipline and verifier policy; it does not enforce the off-chain-data boundary in contract logic.

## Receipt Boundary

FlowPulse does not include `txHash` or `logIndex`. Those values are not available to contracts during execution, including hook execution. Indexers and verifiers must derive them after reading transaction receipts and logs.

## v0 Assumptions

- `pulseId` is unique within the emitting contract's domain but indexers should still key canonical observations by chain id, contract address, transaction hash, and log index.
- `uri` values are advisory by convention only. The skeleton does not enforce that they are short, resolvable, or off-chain pointers, so callers and reviewers must treat the off-chain-data boundary as a design convention rather than an enforcement guarantee.
- `RootfieldRegistry` rejects zero `rootfieldId`, zero `schemaHash`, zero committed root, and zero `artifactCommitment` so local-alpha root transitions keep enough compact state for indexers and verifiers to reconstruct the object model.
- Verifiers must validate any referenced off-chain content against the emitted `commitment`.
- Pulse type expansion should happen by reserving new numeric values and documenting their subject and commitment semantics before contracts depend on them.
- Base settlement-anchor use remains placeholder/research until a separate issue, threat model, and deployment review approve a concrete anchor design. The current event schema does not implement a bridge, appchain finality, or production settlement guarantees.
- `FlowMemoryHookAdapter` is a V0 scaffold. Its direct helper and dependency-light Uniswap v4-shaped `afterSwap` path emit the same `SWAP_MEMORY_SIGNAL` semantics, but neither path is a production hook deployment, dynamic-fee hook, or custody path.
- Current Solidity contracts do not expose challenge resolution or finality state. Verifier statuses such as `REORGED` are compact report values for off-chain reconciliation.

## Current Pulse Types

| Type | Name | Subject | Commitment |
| --- | --- | --- | --- |
| `1` | `ROOTFIELD_REGISTERED` | `rootfieldId` | `keccak256(abi.encode(schemaHash, metadataHash))` |
| `2` | `ROOT_COMMITTED` | committed root | `keccak256(abi.encode(root, artifactCommitment))` |
| `3` | `ROOTFIELD_STATUS_CHANGED` | `rootfieldId` | type-specific status or ownership commitment |
| `4` | `SWAP_MEMORY_SIGNAL` | Uniswap pool id | swap-memory artifact commitment checked by the V0 verifier fixture policy |
