// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IArtifactRegistry} from "./interfaces/IArtifactRegistry.sol";

/// @title ArtifactRegistry
/// @notice Minimal v0 registry for artifact commitments.
/// @dev URI values are advisory log data only. Raw artifacts remain off-chain.
contract ArtifactRegistry is IArtifactRegistry {
    mapping(bytes32 artifactId => Artifact artifact) private _artifacts;

    error ZeroArtifactId();
    error ZeroRootfieldId();
    error ZeroArtifactType();
    error ZeroCommitmentHash();
    error ZeroSchemaHash();
    error ArtifactAlreadyRegistered(bytes32 artifactId);
    error ArtifactNotRegistered(bytes32 artifactId);
    error ArtifactNotActive(bytes32 artifactId);
    error NotArtifactOwner(bytes32 artifactId, address caller);
    error TimestampOverflow(uint256 timestamp);

    function registerArtifact(
        bytes32 artifactId,
        bytes32 rootfieldId,
        bytes32 artifactType,
        bytes32 commitmentHash,
        bytes32 schemaHash,
        bytes32 metadataHash,
        string calldata artifactURI
    ) external {
        if (artifactId == bytes32(0)) revert ZeroArtifactId();
        if (rootfieldId == bytes32(0)) revert ZeroRootfieldId();
        if (artifactType == bytes32(0)) revert ZeroArtifactType();
        if (commitmentHash == bytes32(0)) revert ZeroCommitmentHash();
        if (schemaHash == bytes32(0)) revert ZeroSchemaHash();
        if (_artifacts[artifactId].exists) revert ArtifactAlreadyRegistered(artifactId);

        uint64 now64 = _blockTimestamp();
        _artifacts[artifactId] = Artifact({
            owner: msg.sender,
            submitter: msg.sender,
            rootfieldId: rootfieldId,
            artifactType: artifactType,
            commitmentHash: commitmentHash,
            schemaHash: schemaHash,
            metadataHash: metadataHash,
            status: ArtifactStatus.Active,
            registeredAt: now64,
            updatedAt: now64,
            exists: true
        });

        emit ArtifactRegistered(
            artifactId, msg.sender, rootfieldId, artifactType, commitmentHash, schemaHash, metadataHash, artifactURI
        );
    }

    function deprecateArtifact(bytes32 artifactId, bytes32 metadataHash, string calldata evidenceURI) external {
        Artifact storage artifact = _artifacts[artifactId];
        if (!artifact.exists) revert ArtifactNotRegistered(artifactId);
        if (artifact.owner != msg.sender) revert NotArtifactOwner(artifactId, msg.sender);
        if (artifact.status != ArtifactStatus.Active) revert ArtifactNotActive(artifactId);

        artifact.metadataHash = metadataHash;
        artifact.status = ArtifactStatus.Deprecated;
        artifact.updatedAt = _blockTimestamp();

        emit ArtifactDeprecated(artifactId, msg.sender, metadataHash, evidenceURI);
    }

    function getArtifact(bytes32 artifactId) external view returns (Artifact memory) {
        return _artifacts[artifactId];
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
