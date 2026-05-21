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
    uint8 internal constant TASK_OPENED = 5;
    uint8 internal constant TASK_ACCEPTED = 6;
    uint8 internal constant TASK_STARTED = 7;
    uint8 internal constant TASK_EVIDENCE_COMMITTED = 8;
    uint8 internal constant TASK_VERIFIED = 9;
    uint8 internal constant TASK_FAILED = 10;
    uint8 internal constant TASK_CHALLENGED = 11;
    uint8 internal constant TASK_SETTLED = 12;
    uint8 internal constant TASK_SLASHED = 13;
    uint8 internal constant AGENT_REGISTERED = 14;
    uint8 internal constant AGENT_POLICY_UPDATED = 15;
    uint8 internal constant AGENT_STEP_COMMITTED = 16;
    uint8 internal constant AGENT_ACTION_EXECUTED = 17;
    uint8 internal constant AGENT_MEMORY_COMMITTED = 18;
    uint8 internal constant AGENT_PAUSED = 19;
    uint8 internal constant AGENT_BOND_PASSPORT_CREATED = 20;
    uint8 internal constant AGENT_BOND_PASSPORT_UPDATED = 21;
    uint8 internal constant AGENT_BOND_ENVELOPE_QUOTED = 22;
    uint8 internal constant AGENT_BOND_ENVELOPE_SIGNED = 23;
    uint8 internal constant AGENT_BOND_RECEIPT_EMITTED = 24;
    uint8 internal constant AGENT_BOND_CREDIT_SCORE_UPDATED = 25;
    uint8 internal constant AGENT_BOND_UNDERWRITER_CAPACITY_ALLOCATED = 26;
    uint8 internal constant AGENT_BOND_UNDERWRITER_CAPACITY_LOCKED = 27;
    uint8 internal constant AGENT_BOND_UNDERWRITER_LOSS_EVENT = 28;
    uint8 internal constant AGENT_BOND_A2A_TASK_LINKED = 29;
    uint8 internal constant AGENT_BOND_MCP_TOOL_LINKED = 30;
    uint8 internal constant AGENT_BOND_X402_PAYMENT_LINKED = 31;
    uint8 internal constant AGENT_BOND_PUBLIC_CLAIM_GENERATED = 32;
    uint8 internal constant AGENT_BOND_PUBLIC_CLAIM_BLOCKED = 33;
    uint8 internal constant AGENT_MEMORY_CORRECTED = 34;
}
