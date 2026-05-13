// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IWorkerRegistry {
    enum WorkerStatus {
        Unknown,
        Active,
        Inactive
    }

    struct Worker {
        bytes32 operatorId;
        bytes32 role;
        bytes32 metadataHash;
        WorkerStatus status;
        uint64 registeredAt;
        uint64 updatedAt;
        uint64 updateCount;
        bool active;
    }

    event WorkerRegistered(
        address indexed worker,
        bytes32 indexed operatorId,
        bytes32 indexed role,
        bytes32 metadataHash,
        string metadataURI
    );
    event WorkerMetadataUpdated(
        address indexed worker, bytes32 indexed operatorId, bytes32 metadataHash, uint64 updateCount, string metadataURI
    );
    event WorkerDeactivated(address indexed worker, bytes32 indexed operatorId, bytes32 reasonHash, string evidenceURI);

    function registerWorker(bytes32 operatorId, bytes32 role, bytes32 metadataHash, string calldata metadataURI)
        external;
    function updateWorkerMetadata(bytes32 metadataHash, string calldata metadataURI) external;
    function deactivateWorker(bytes32 reasonHash, string calldata evidenceURI) external;
    function getWorker(address worker) external view returns (Worker memory);
}
