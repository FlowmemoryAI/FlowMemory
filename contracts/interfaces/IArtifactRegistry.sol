// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IArtifactRegistry {
    enum ArtifactStatus {
        Unknown,
        Active,
        Deprecated
    }

    struct Artifact {
        address owner;
        address submitter;
        bytes32 rootfieldId;
        bytes32 artifactType;
        bytes32 commitmentHash;
        bytes32 schemaHash;
        bytes32 metadataHash;
        ArtifactStatus status;
        uint64 registeredAt;
        uint64 updatedAt;
        bool exists;
    }

    event ArtifactRegistered(
        bytes32 indexed artifactId,
        address indexed owner,
        bytes32 indexed rootfieldId,
        bytes32 artifactType,
        bytes32 commitmentHash,
        bytes32 schemaHash,
        bytes32 metadataHash,
        string artifactURI
    );
    event ArtifactDeprecated(
        bytes32 indexed artifactId, address indexed owner, bytes32 metadataHash, string evidenceURI
    );

    function registerArtifact(
        bytes32 artifactId,
        bytes32 rootfieldId,
        bytes32 artifactType,
        bytes32 commitmentHash,
        bytes32 schemaHash,
        bytes32 metadataHash,
        string calldata artifactURI
    ) external;

    function deprecateArtifact(bytes32 artifactId, bytes32 metadataHash, string calldata evidenceURI) external;

    function getArtifact(bytes32 artifactId) external view returns (Artifact memory);
}
