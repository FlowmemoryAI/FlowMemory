// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFlowPulse, FlowPulseTypes} from "./FlowPulse.sol";

/// @title RootfieldRegistry
/// @notice Minimal registry for Rootfield commitment namespaces.
/// @dev This foundation intentionally excludes dynamic fees, tokenomics,
/// upgrade hooks, and receipt-only metadata such as txHash and logIndex.
contract RootfieldRegistry is IFlowPulse {
    struct Rootfield {
        address owner;
        bytes32 schemaHash;
        bytes32 metadataHash;
        bytes32 latestRoot;
        uint64 pulseCount;
        uint64 rootCount;
        bool active;
    }

    mapping(bytes32 rootfieldId => Rootfield rootfield) private _rootfields;

    error ZeroRootfieldId();
    error ZeroRoot();
    error RootfieldAlreadyRegistered(bytes32 rootfieldId);
    error RootfieldNotRegistered(bytes32 rootfieldId);
    error RootfieldInactive(bytes32 rootfieldId);
    error NotRootfieldOwner(bytes32 rootfieldId, address caller);
    error ZeroRootfieldOwner();
    error TimestampOverflow(uint256 timestamp);

    event RootfieldDeactivated(
        bytes32 indexed rootfieldId, address indexed owner, bytes32 indexed parentPulseId, string reasonURI
    );
    event RootfieldOwnershipTransferred(
        bytes32 indexed rootfieldId, address indexed previousOwner, address indexed newOwner, string evidenceURI
    );

    function registerRootfield(
        bytes32 rootfieldId,
        bytes32 schemaHash,
        bytes32 metadataHash,
        string calldata metadataURI
    ) external returns (bytes32 pulseId) {
        if (rootfieldId == bytes32(0)) {
            revert ZeroRootfieldId();
        }
        if (_rootfields[rootfieldId].owner != address(0)) {
            revert RootfieldAlreadyRegistered(rootfieldId);
        }

        _rootfields[rootfieldId] = Rootfield({
            owner: msg.sender,
            schemaHash: schemaHash,
            metadataHash: metadataHash,
            latestRoot: bytes32(0),
            pulseCount: 0,
            rootCount: 0,
            active: true
        });

        pulseId = _emitFlowPulse({
            rootfieldId: rootfieldId,
            actor: msg.sender,
            pulseType: FlowPulseTypes.ROOTFIELD_REGISTERED,
            subject: rootfieldId,
            commitment: keccak256(abi.encode(schemaHash, metadataHash)),
            parentPulseId: bytes32(0),
            uri: metadataURI
        });
    }

    function submitRoot(
        bytes32 rootfieldId,
        bytes32 root,
        bytes32 artifactCommitment,
        bytes32 parentPulseId,
        string calldata evidenceURI
    ) external returns (bytes32 pulseId) {
        Rootfield storage rootfield = _requireRootfieldOwner(rootfieldId);
        if (!rootfield.active) {
            revert RootfieldInactive(rootfieldId);
        }
        if (root == bytes32(0)) {
            revert ZeroRoot();
        }

        rootfield.latestRoot = root;
        rootfield.rootCount += 1;

        pulseId = _emitFlowPulse({
            rootfieldId: rootfieldId,
            actor: msg.sender,
            pulseType: FlowPulseTypes.ROOT_COMMITTED,
            subject: root,
            commitment: keccak256(abi.encode(root, artifactCommitment)),
            parentPulseId: parentPulseId,
            uri: evidenceURI
        });
    }

    function deactivateRootfield(bytes32 rootfieldId, bytes32 parentPulseId, string calldata reasonURI)
        external
        returns (bytes32 pulseId)
    {
        Rootfield storage rootfield = _requireRootfieldOwner(rootfieldId);
        if (!rootfield.active) {
            revert RootfieldInactive(rootfieldId);
        }

        rootfield.active = false;

        pulseId = _emitFlowPulse({
            rootfieldId: rootfieldId,
            actor: msg.sender,
            pulseType: FlowPulseTypes.ROOTFIELD_STATUS_CHANGED,
            subject: rootfieldId,
            commitment: keccak256(abi.encode(rootfieldId, false)),
            parentPulseId: parentPulseId,
            uri: reasonURI
        });

        emit RootfieldDeactivated(rootfieldId, msg.sender, parentPulseId, reasonURI);
    }

    function transferRootfieldOwnership(bytes32 rootfieldId, address newOwner, string calldata evidenceURI)
        external
        returns (bytes32 pulseId)
    {
        if (newOwner == address(0)) {
            revert ZeroRootfieldOwner();
        }

        Rootfield storage rootfield = _requireRootfieldOwner(rootfieldId);
        if (!rootfield.active) {
            revert RootfieldInactive(rootfieldId);
        }

        address previousOwner = rootfield.owner;
        rootfield.owner = newOwner;

        pulseId = _emitFlowPulse({
            rootfieldId: rootfieldId,
            actor: previousOwner,
            pulseType: FlowPulseTypes.ROOTFIELD_STATUS_CHANGED,
            subject: rootfieldId,
            commitment: keccak256(abi.encode(previousOwner, newOwner)),
            parentPulseId: bytes32(0),
            uri: evidenceURI
        });

        emit RootfieldOwnershipTransferred(rootfieldId, previousOwner, newOwner, evidenceURI);
    }

    function getRootfield(bytes32 rootfieldId) external view returns (Rootfield memory) {
        return _rootfields[rootfieldId];
    }

    function isRegistered(bytes32 rootfieldId) external view returns (bool) {
        return _rootfields[rootfieldId].owner != address(0);
    }

    function _requireRootfieldOwner(bytes32 rootfieldId) private view returns (Rootfield storage rootfield) {
        rootfield = _rootfields[rootfieldId];
        if (rootfield.owner == address(0)) {
            revert RootfieldNotRegistered(rootfieldId);
        }
        if (rootfield.owner != msg.sender) {
            revert NotRootfieldOwner(rootfieldId, msg.sender);
        }
    }

    function _emitFlowPulse(
        bytes32 rootfieldId,
        address actor,
        uint8 pulseType,
        bytes32 subject,
        bytes32 commitment,
        bytes32 parentPulseId,
        string calldata uri
    ) private returns (bytes32 pulseId) {
        uint64 sequence = _nextSequence(rootfieldId);
        uint64 occurredAt = _blockTimestamp();

        pulseId = keccak256(
            abi.encode(
                FlowPulseTypes.SCHEMA_ID,
                block.chainid,
                address(this),
                rootfieldId,
                actor,
                pulseType,
                subject,
                commitment,
                parentPulseId,
                sequence
            )
        );

        emit FlowPulse(
            pulseId, rootfieldId, actor, pulseType, subject, commitment, parentPulseId, sequence, occurredAt, uri
        );
    }

    function _nextSequence(bytes32 rootfieldId) private returns (uint64 sequence) {
        Rootfield storage rootfield = _rootfields[rootfieldId];
        sequence = rootfield.pulseCount + 1;
        rootfield.pulseCount = sequence;
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) {
            revert TimestampOverflow(block.timestamp);
        }
        return uint64(block.timestamp);
    }
}
