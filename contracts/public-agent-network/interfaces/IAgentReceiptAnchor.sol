// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAgentReceiptAnchor {
    function anchorReceipt(
        bytes32 receiptId,
        bytes32 agentId,
        bytes32 eventRoot,
        bytes32 receiptRoot,
        bytes32 previousMemoryRoot,
        bytes32 newMemoryRoot,
        uint64 schemaVersion
    ) external;
}
