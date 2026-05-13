// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IWorkDebtScheduler} from "./interfaces/IWorkDebtScheduler.sol";

/// @title WorkDebtScheduler
/// @notice Minimal v0 scheduler for work commitment state.
/// @dev No token debt, rewards, slashing, dynamic fees, or external calls.
contract WorkDebtScheduler is IWorkDebtScheduler {
    mapping(bytes32 workId => WorkItem item) private _workItems;

    error ZeroWorkId();
    error ZeroWorker();
    error ZeroRootfieldId();
    error ZeroWorkCommitment();
    error ZeroCompletionCommitment();
    error WorkAlreadyScheduled(bytes32 workId);
    error WorkNotScheduled(bytes32 workId);
    error WorkNotScheduledStatus(bytes32 workId);
    error NotWorkParticipant(bytes32 workId, address caller);
    error TimestampOverflow(uint256 timestamp);

    function scheduleWork(
        bytes32 workId,
        address worker,
        bytes32 rootfieldId,
        bytes32 workCommitment,
        bytes32 metadataHash,
        string calldata workURI
    ) external {
        if (workId == bytes32(0)) revert ZeroWorkId();
        if (worker == address(0)) revert ZeroWorker();
        if (rootfieldId == bytes32(0)) revert ZeroRootfieldId();
        if (workCommitment == bytes32(0)) revert ZeroWorkCommitment();
        if (_workItems[workId].status != WorkStatus.Unknown) revert WorkAlreadyScheduled(workId);

        uint64 now64 = _blockTimestamp();
        _workItems[workId] = WorkItem({
            scheduler: msg.sender,
            worker: worker,
            rootfieldId: rootfieldId,
            workCommitment: workCommitment,
            metadataHash: metadataHash,
            status: WorkStatus.Scheduled,
            scheduledAt: now64,
            updatedAt: now64
        });

        emit WorkScheduled(workId, msg.sender, worker, rootfieldId, workCommitment, metadataHash, workURI);
    }

    function markWorkComplete(
        bytes32 workId,
        bytes32 completionCommitment,
        bytes32 metadataHash,
        string calldata evidenceURI
    ) external {
        if (completionCommitment == bytes32(0)) revert ZeroCompletionCommitment();

        WorkItem storage item = _workItems[workId];
        if (item.status == WorkStatus.Unknown) revert WorkNotScheduled(workId);
        if (item.status != WorkStatus.Scheduled) revert WorkNotScheduledStatus(workId);
        if (msg.sender != item.scheduler && msg.sender != item.worker) revert NotWorkParticipant(workId, msg.sender);

        item.workCommitment = completionCommitment;
        item.metadataHash = metadataHash;
        item.status = WorkStatus.Completed;
        item.updatedAt = _blockTimestamp();

        emit WorkCompleted(workId, msg.sender, completionCommitment, metadataHash, evidenceURI);
    }

    function getWorkItem(bytes32 workId) external view returns (WorkItem memory) {
        return _workItems[workId];
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
