// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../shared/TwoStepOwnable.sol";

contract AgentReceiptAnchor is TwoStepOwnable {
    struct ReceiptAnchor {
        bytes32 agentId;
        bytes32 eventRoot;
        bytes32 receiptRoot;
        bytes32 previousMemoryRoot;
        bytes32 newMemoryRoot;
        address attestor;
        uint64 anchoredAt;
        uint64 schemaVersion;
    }

    mapping(bytes32 receiptId => ReceiptAnchor anchor) private _receipts;
    mapping(bytes32 agentId => bytes32[] anchoredReceiptIds) private _agentReceiptIds;
    mapping(address attestor => bool authorized) public isAuthorizedAttestor;

    error ZeroAttestor();
    error ZeroReceiptId();
    error ZeroAgentId();
    error ZeroReceiptRoot();
    error UnauthorizedAttestor(address attestor);
    error ReceiptAlreadyAnchored(bytes32 receiptId);
    error ReceiptNotAnchored(bytes32 receiptId);

    event AuthorizedAttestorSet(address indexed attestor, bool authorized);
    event AgentReceiptAnchored(
        bytes32 indexed receiptId,
        bytes32 indexed agentId,
        bytes32 eventRoot,
        bytes32 receiptRoot,
        bytes32 previousMemoryRoot,
        bytes32 newMemoryRoot,
        address attestor,
        uint64 schemaVersion
    );
    event AgentReceiptSuperseded(bytes32 indexed oldReceiptId, bytes32 indexed newReceiptId, bytes32 reasonCode);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    function setAuthorizedAttestor(address attestor, bool authorized) external onlyOwner {
        if (attestor == address(0)) revert ZeroAttestor();
        isAuthorizedAttestor[attestor] = authorized;
        emit AuthorizedAttestorSet(attestor, authorized);
    }

    function anchorReceipt(
        bytes32 receiptId,
        bytes32 agentId,
        bytes32 eventRoot,
        bytes32 receiptRoot,
        bytes32 previousMemoryRoot,
        bytes32 newMemoryRoot,
        uint64 schemaVersion
    ) external {
        if (!isAuthorizedAttestor[msg.sender]) revert UnauthorizedAttestor(msg.sender);
        if (receiptId == bytes32(0)) revert ZeroReceiptId();
        if (agentId == bytes32(0)) revert ZeroAgentId();
        if (receiptRoot == bytes32(0)) revert ZeroReceiptRoot();
        if (_receipts[receiptId].receiptRoot != bytes32(0)) revert ReceiptAlreadyAnchored(receiptId);

        _receipts[receiptId] = ReceiptAnchor({
            agentId: agentId,
            eventRoot: eventRoot,
            receiptRoot: receiptRoot,
            previousMemoryRoot: previousMemoryRoot,
            newMemoryRoot: newMemoryRoot,
            attestor: msg.sender,
            anchoredAt: uint64(block.timestamp),
            schemaVersion: schemaVersion
        });
        _agentReceiptIds[agentId].push(receiptId);
        emit AgentReceiptAnchored(receiptId, agentId, eventRoot, receiptRoot, previousMemoryRoot, newMemoryRoot, msg.sender, schemaVersion);
    }

    function supersedeReceipt(bytes32 oldReceiptId, bytes32 newReceiptId, bytes32 reasonCode) external {
        if (!isAuthorizedAttestor[msg.sender]) revert UnauthorizedAttestor(msg.sender);
        if (_receipts[oldReceiptId].receiptRoot == bytes32(0)) revert ReceiptNotAnchored(oldReceiptId);
        if (_receipts[newReceiptId].receiptRoot == bytes32(0)) revert ReceiptNotAnchored(newReceiptId);
        emit AgentReceiptSuperseded(oldReceiptId, newReceiptId, reasonCode);
    }

    function getReceipt(bytes32 receiptId) external view returns (ReceiptAnchor memory) {
        ReceiptAnchor memory anchor = _receipts[receiptId];
        if (anchor.receiptRoot == bytes32(0)) revert ReceiptNotAnchored(receiptId);
        return anchor;
    }

    function getAgentReceiptIds(bytes32 agentId) external view returns (bytes32[] memory) {
        return _agentReceiptIds[agentId];
    }
}
