// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FlowPulse event schema for FlowMemory protocol activity.
/// @notice FlowPulse intentionally excludes receipt-only metadata such as
/// txHash and logIndex. Indexers derive those fields after reading receipts.
interface IFlowPulse {
    /// @notice Canonical event stream for registry, root, proof, and work-state
    /// activity.
    /// @param pulseId Domain-separated identifier emitted by the source contract.
    /// @param rootfieldId Rootfield namespace this pulse belongs to.
    /// @param actor Account that caused the pulse.
    /// @param pulseType Stable numeric type from FlowPulseTypes.
    /// @param subject Type-specific subject, such as a rootfield id or root.
    /// @param commitment Type-specific hash commitment to off-chain data.
    /// @param parentPulseId Optional prior pulse being extended or referenced.
    /// @param sequence Monotonic sequence within the rootfield namespace.
    /// @param occurredAt Block timestamp observed by the emitting contract.
    /// @param uri Arbitrary advisory string emitted as on-chain log data.
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
}

/// @notice Stable FlowPulse type identifiers reserved by the contracts layer.
library FlowPulseTypes {
    bytes32 internal constant SCHEMA_ID = keccak256("flowmemory.flowpulse.v0");

    uint8 internal constant ROOTFIELD_REGISTERED = 1;
    uint8 internal constant ROOT_COMMITTED = 2;
    uint8 internal constant ROOTFIELD_STATUS_CHANGED = 3;
    uint8 internal constant SWAP_MEMORY_SIGNAL = 4;
}
