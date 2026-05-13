// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVerifierRegistry {
    enum VerifierStatus {
        Unknown,
        Active,
        Inactive
    }

    struct Verifier {
        bytes32 operatorId;
        bytes32 role;
        bytes32 metadataHash;
        VerifierStatus status;
        uint64 registeredAt;
        uint64 updatedAt;
        uint64 updateCount;
        bool active;
    }

    event VerifierRegistered(
        address indexed verifier,
        bytes32 indexed operatorId,
        bytes32 indexed role,
        bytes32 metadataHash,
        string metadataURI
    );
    event VerifierMetadataUpdated(
        address indexed verifier,
        bytes32 indexed operatorId,
        bytes32 metadataHash,
        uint64 updateCount,
        string metadataURI
    );
    event VerifierDeactivated(
        address indexed verifier, bytes32 indexed operatorId, bytes32 reasonHash, string evidenceURI
    );

    function registerVerifier(bytes32 operatorId, bytes32 role, bytes32 metadataHash, string calldata metadataURI)
        external;
    function updateVerifierMetadata(bytes32 metadataHash, string calldata metadataURI) external;
    function deactivateVerifier(bytes32 reasonHash, string calldata evidenceURI) external;
    function getVerifier(address verifier) external view returns (Verifier memory);
}
