// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICursorRegistry {
    struct Cursor {
        address owner;
        bytes32 streamId;
        bytes32 positionCommitment;
        bytes32 metadataHash;
        uint64 updateCount;
        uint64 updatedAt;
        bool active;
    }

    event CursorRegistered(
        bytes32 indexed cursorId,
        address indexed owner,
        bytes32 indexed streamId,
        bytes32 positionCommitment,
        bytes32 metadataHash,
        string metadataURI
    );
    event CursorAdvanced(
        bytes32 indexed cursorId,
        address indexed owner,
        bytes32 indexed streamId,
        bytes32 positionCommitment,
        bytes32 metadataHash,
        uint64 updateCount,
        string evidenceURI
    );

    function registerCursor(
        bytes32 cursorId,
        bytes32 streamId,
        bytes32 positionCommitment,
        bytes32 metadataHash,
        string calldata metadataURI
    ) external;

    function advanceCursor(
        bytes32 cursorId,
        bytes32 positionCommitment,
        bytes32 metadataHash,
        string calldata evidenceURI
    ) external;

    function getCursor(bytes32 cursorId) external view returns (Cursor memory);
}
