// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IWorkDebtScheduler {
    enum WorkStatus {
        Unknown,
        Scheduled,
        Completed
    }

    struct WorkItem {
        address scheduler;
        address worker;
        bytes32 rootfieldId;
        bytes32 workCommitment;
        bytes32 metadataHash;
        WorkStatus status;
        uint64 scheduledAt;
        uint64 updatedAt;
    }

    event WorkScheduled(
        bytes32 indexed workId,
        address indexed scheduler,
        address indexed worker,
        bytes32 rootfieldId,
        bytes32 workCommitment,
        bytes32 metadataHash,
        string workURI
    );
    event WorkCompleted(
        bytes32 indexed workId,
        address indexed caller,
        bytes32 completionCommitment,
        bytes32 metadataHash,
        string evidenceURI
    );

    function scheduleWork(
        bytes32 workId,
        address worker,
        bytes32 rootfieldId,
        bytes32 workCommitment,
        bytes32 metadataHash,
        string calldata workURI
    ) external;

    function markWorkComplete(
        bytes32 workId,
        bytes32 completionCommitment,
        bytes32 metadataHash,
        string calldata evidenceURI
    ) external;

    function getWorkItem(bytes32 workId) external view returns (WorkItem memory);
}
