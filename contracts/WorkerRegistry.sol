// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IWorkerRegistry} from "./interfaces/IWorkerRegistry.sol";

/// @title WorkerRegistry
/// @notice Minimal v0 self-registry for worker identities and metadata commitments.
/// @dev No staking, rewards, slashing, custody, or token mechanics are implemented.
contract WorkerRegistry is IWorkerRegistry {
    mapping(address worker => Worker record) private _workers;

    error ZeroWorker();
    error ZeroOperatorId();
    error ZeroWorkerRole();
    error WorkerAlreadyRegistered(address worker);
    error WorkerNotRegistered(address worker);
    error WorkerNotActive(address worker);
    error TimestampOverflow(uint256 timestamp);

    function registerWorker(bytes32 operatorId, bytes32 role, bytes32 metadataHash, string calldata metadataURI)
        external
    {
        if (msg.sender == address(0)) revert ZeroWorker();
        if (operatorId == bytes32(0)) revert ZeroOperatorId();
        if (role == bytes32(0)) revert ZeroWorkerRole();
        if (_workers[msg.sender].status != WorkerStatus.Unknown) revert WorkerAlreadyRegistered(msg.sender);

        uint64 now64 = _blockTimestamp();
        _workers[msg.sender] = Worker({
            operatorId: operatorId,
            role: role,
            metadataHash: metadataHash,
            status: WorkerStatus.Active,
            registeredAt: now64,
            updatedAt: now64,
            updateCount: 1,
            active: true
        });

        emit WorkerRegistered(msg.sender, operatorId, role, metadataHash, metadataURI);
    }

    function updateWorkerMetadata(bytes32 metadataHash, string calldata metadataURI) external {
        Worker storage worker = _workers[msg.sender];
        if (worker.status == WorkerStatus.Unknown) revert WorkerNotRegistered(msg.sender);
        if (worker.status != WorkerStatus.Active) revert WorkerNotActive(msg.sender);

        worker.metadataHash = metadataHash;
        worker.updatedAt = _blockTimestamp();
        worker.updateCount += 1;

        emit WorkerMetadataUpdated(msg.sender, worker.operatorId, metadataHash, worker.updateCount, metadataURI);
    }

    function deactivateWorker(bytes32 reasonHash, string calldata evidenceURI) external {
        Worker storage worker = _workers[msg.sender];
        if (worker.status == WorkerStatus.Unknown) revert WorkerNotRegistered(msg.sender);
        if (worker.status != WorkerStatus.Active) revert WorkerNotActive(msg.sender);

        worker.status = WorkerStatus.Inactive;
        worker.active = false;
        worker.updatedAt = _blockTimestamp();
        worker.updateCount += 1;

        emit WorkerDeactivated(msg.sender, worker.operatorId, reasonHash, evidenceURI);
    }

    function getWorker(address worker) external view returns (Worker memory) {
        return _workers[worker];
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
