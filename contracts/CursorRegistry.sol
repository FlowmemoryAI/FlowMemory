// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICursorRegistry} from "./interfaces/ICursorRegistry.sol";

/// @title CursorRegistry
/// @notice Minimal v0 registry for off-chain indexer cursor commitments.
/// @dev This skeleton stores compact commitments only. It does not define
/// canonical indexer identity, receipt identity, or chain reorg policy.
contract CursorRegistry is ICursorRegistry {
    mapping(bytes32 cursorId => Cursor cursor) private _cursors;

    error ZeroCursorId();
    error ZeroStreamId();
    error ZeroPositionCommitment();
    error CursorAlreadyRegistered(bytes32 cursorId);
    error CursorNotRegistered(bytes32 cursorId);
    error NotCursorOwner(bytes32 cursorId, address caller);
    error TimestampOverflow(uint256 timestamp);

    function registerCursor(
        bytes32 cursorId,
        bytes32 streamId,
        bytes32 positionCommitment,
        bytes32 metadataHash,
        string calldata metadataURI
    ) external {
        if (cursorId == bytes32(0)) revert ZeroCursorId();
        if (streamId == bytes32(0)) revert ZeroStreamId();
        if (positionCommitment == bytes32(0)) revert ZeroPositionCommitment();
        if (_cursors[cursorId].owner != address(0)) revert CursorAlreadyRegistered(cursorId);

        uint64 now64 = _blockTimestamp();
        _cursors[cursorId] = Cursor({
            owner: msg.sender,
            streamId: streamId,
            positionCommitment: positionCommitment,
            metadataHash: metadataHash,
            updateCount: 1,
            updatedAt: now64,
            active: true
        });

        emit CursorRegistered(cursorId, msg.sender, streamId, positionCommitment, metadataHash, metadataURI);
    }

    function advanceCursor(
        bytes32 cursorId,
        bytes32 positionCommitment,
        bytes32 metadataHash,
        string calldata evidenceURI
    ) external {
        if (positionCommitment == bytes32(0)) revert ZeroPositionCommitment();

        Cursor storage cursor = _requireCursorOwner(cursorId);
        cursor.positionCommitment = positionCommitment;
        cursor.metadataHash = metadataHash;
        cursor.updateCount += 1;
        cursor.updatedAt = _blockTimestamp();

        emit CursorAdvanced(
            cursorId, msg.sender, cursor.streamId, positionCommitment, metadataHash, cursor.updateCount, evidenceURI
        );
    }

    function getCursor(bytes32 cursorId) external view returns (Cursor memory) {
        return _cursors[cursorId];
    }

    function _requireCursorOwner(bytes32 cursorId) private view returns (Cursor storage cursor) {
        cursor = _cursors[cursorId];
        if (cursor.owner == address(0)) revert CursorNotRegistered(cursorId);
        if (cursor.owner != msg.sender) revert NotCursorOwner(cursorId, msg.sender);
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
