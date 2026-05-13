// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IWorkReceiptRegistry} from "./interfaces/IWorkReceiptRegistry.sol";

/// @title WorkReceiptRegistry
/// @notice Minimal v0 registry for compact work receipt commitments.
/// @dev Uses an owner-controlled worker allowlist. It does not implement
/// staking, rewards, slashing, scheduling, or external verifier calls.
contract WorkReceiptRegistry is IWorkReceiptRegistry {
    uint8 public constant MEMORY_REFRESH = 1;
    uint8 public constant FAILURE_DISCOVERY = 2;
    uint8 public constant FAILURE_REPAIR = 3;
    uint8 public constant MANIFOLD_DISCOVERY = 4;
    uint8 public constant STEERING_VALIDATION = 5;
    uint8 public constant CHECKPOINT_STORAGE = 6;
    uint8 public constant GPU_TRAINING = 7;
    uint8 public constant EVAL_COUNTEREXAMPLE = 8;

    address public immutable owner;

    mapping(address worker => bool authorized) private _authorizedWorkers;
    mapping(bytes32 receiptId => WorkReceipt receipt) private _receipts;

    error NotOwner(address caller);
    error ZeroWorker();
    error WorkerNotAuthorized(address worker);
    error ZeroReceiptId();
    error ZeroRootfieldId();
    error InvalidWorkLane(uint8 lane);
    error ZeroInputRoot();
    error ZeroOutputRoot();
    error ZeroArtifactCommitment();
    error WorkReceiptAlreadySubmitted(bytes32 receiptId);
    error TimestampOverflow(uint256 timestamp);

    constructor() {
        owner = msg.sender;
    }

    function setWorkerAuthorization(address worker, bool authorized) external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (worker == address(0)) revert ZeroWorker();

        _authorizedWorkers[worker] = authorized;
        emit WorkerAuthorizationSet(worker, authorized);
    }

    function submitWorkReceipt(
        bytes32 receiptId,
        bytes32 rootfieldId,
        uint8 lane,
        bytes32 subject,
        bytes32 inputRoot,
        bytes32 outputRoot,
        bytes32 artifactCommitment,
        bytes32 parentReceiptId,
        string calldata evidenceURI
    ) external {
        if (!_authorizedWorkers[msg.sender]) revert WorkerNotAuthorized(msg.sender);
        if (receiptId == bytes32(0)) revert ZeroReceiptId();
        if (rootfieldId == bytes32(0)) revert ZeroRootfieldId();
        if (!_isValidLane(lane)) revert InvalidWorkLane(lane);
        if (inputRoot == bytes32(0)) revert ZeroInputRoot();
        if (outputRoot == bytes32(0)) revert ZeroOutputRoot();
        if (artifactCommitment == bytes32(0)) revert ZeroArtifactCommitment();
        if (_receipts[receiptId].exists) revert WorkReceiptAlreadySubmitted(receiptId);

        _receipts[receiptId] = WorkReceipt({
            worker: msg.sender,
            rootfieldId: rootfieldId,
            lane: lane,
            subject: subject,
            inputRoot: inputRoot,
            outputRoot: outputRoot,
            artifactCommitment: artifactCommitment,
            parentReceiptId: parentReceiptId,
            submittedAt: _blockTimestamp(),
            exists: true
        });

        emit WorkReceiptSubmitted(
            receiptId,
            msg.sender,
            rootfieldId,
            lane,
            subject,
            inputRoot,
            outputRoot,
            artifactCommitment,
            parentReceiptId,
            evidenceURI
        );
    }

    function isAuthorizedWorker(address worker) external view returns (bool) {
        return _authorizedWorkers[worker];
    }

    function getWorkReceipt(bytes32 receiptId) external view returns (WorkReceipt memory) {
        return _receipts[receiptId];
    }

    function _isValidLane(uint8 lane) private pure returns (bool) {
        return lane >= MEMORY_REFRESH && lane <= EVAL_COUNTEREXAMPLE;
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
