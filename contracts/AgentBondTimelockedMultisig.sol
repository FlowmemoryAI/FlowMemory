// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AgentBondTimelockedMultisig
/// @notice Threshold-controlled timelocked executor for production-shaped Agent Bonds administration.
contract AgentBondTimelockedMultisig {
    struct Operation {
        address target;
        uint256 value;
        bytes32 dataHash;
        uint64 readyAt;
        uint32 approvalCount;
        bool executed;
        bool canceled;
    }

    address[] private _owners;
    mapping(address owner => bool authorized) public isOwner;
    uint256 public immutable threshold;
    uint64 public immutable minDelay;

    mapping(bytes32 operationId => Operation operation) private _operations;
    mapping(bytes32 operationId => mapping(address owner => bool approved)) private _approvedBy;

    bool private _entered;

    error NotOwner(address caller);
    error InvalidOwner();
    error DuplicateOwner(address owner);
    error InvalidThreshold(uint256 threshold, uint256 ownerCount);
    error ZeroDelay();
    error ZeroTarget();
    error ReentrantCall();
    error OperationExists(bytes32 operationId);
    error OperationNotFound(bytes32 operationId);
    error OperationAlreadyApproved(bytes32 operationId, address owner);
    error OperationNotReady(bytes32 operationId, uint64 readyAt, uint64 currentTime);
    error InsufficientApprovals(bytes32 operationId, uint32 approvals, uint256 threshold);
    error OperationAlreadyFinalized(bytes32 operationId);
    error OperationAlreadyCanceled(bytes32 operationId);
    error HashMismatch(bytes32 expected, bytes32 actual);
    error ExecutionFailed();

    event OperationQueued(bytes32 indexed operationId, address indexed proposer, address indexed target, uint64 readyAt, string description);
    event OperationApproved(bytes32 indexed operationId, address indexed owner, uint32 approvalCount);
    event OperationCanceled(bytes32 indexed operationId, address indexed owner);
    event OperationExecuted(bytes32 indexed operationId, address indexed executor);

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner(msg.sender);
        _;
    }

    modifier nonReentrant() {
        if (_entered) revert ReentrantCall();
        _entered = true;
        _;
        _entered = false;
    }

    constructor(address[] memory owners_, uint256 threshold_, uint64 minDelay_) {
        if (owners_.length == 0) revert InvalidOwner();
        if (threshold_ == 0 || threshold_ > owners_.length) revert InvalidThreshold(threshold_, owners_.length);
        if (minDelay_ == 0) revert ZeroDelay();

        for (uint256 index = 0; index < owners_.length; index += 1) {
            address owner = owners_[index];
            if (owner == address(0)) revert InvalidOwner();
            if (isOwner[owner]) revert DuplicateOwner(owner);
            isOwner[owner] = true;
            _owners.push(owner);
        }

        threshold = threshold_;
        minDelay = minDelay_;
    }

    function queueOperation(address target, uint256 value, bytes calldata data, bytes32 salt, string calldata description)
        external
        onlyOwner
        returns (bytes32 operationId)
    {
        if (target == address(0)) revert ZeroTarget();
        bytes32 dataHash = keccak256(data);
        operationId = keccak256(abi.encode(block.chainid, address(this), target, value, dataHash, salt));
        if (_operations[operationId].readyAt != 0) revert OperationExists(operationId);

        uint64 readyAt = _blockTimestamp() + minDelay;
        _operations[operationId] = Operation({
            target: target,
            value: value,
            dataHash: dataHash,
            readyAt: readyAt,
            approvalCount: 0,
            executed: false,
            canceled: false
        });

        emit OperationQueued(operationId, msg.sender, target, readyAt, description);
    }

    function approveOperation(bytes32 operationId) external onlyOwner {
        Operation storage operation = _requireOperation(operationId);
        if (operation.executed) revert OperationAlreadyFinalized(operationId);
        if (operation.canceled) revert OperationAlreadyCanceled(operationId);
        if (_approvedBy[operationId][msg.sender]) revert OperationAlreadyApproved(operationId, msg.sender);

        _approvedBy[operationId][msg.sender] = true;
        operation.approvalCount += 1;
        emit OperationApproved(operationId, msg.sender, operation.approvalCount);
    }

    function cancelOperation(bytes32 operationId) external onlyOwner {
        Operation storage operation = _requireOperation(operationId);
        if (operation.executed) revert OperationAlreadyFinalized(operationId);
        if (operation.canceled) revert OperationAlreadyCanceled(operationId);
        operation.canceled = true;
        emit OperationCanceled(operationId, msg.sender);
    }

    function executeOperation(bytes32 operationId, address target, uint256 value, bytes calldata data)
        external
        payable
        onlyOwner
        nonReentrant
    {
        Operation storage operation = _requireOperation(operationId);
        if (operation.executed) revert OperationAlreadyFinalized(operationId);
        if (operation.canceled) revert OperationAlreadyCanceled(operationId);
        if (operation.approvalCount < threshold) {
            revert InsufficientApprovals(operationId, operation.approvalCount, threshold);
        }
        uint64 now64 = _blockTimestamp();
        if (now64 < operation.readyAt) revert OperationNotReady(operationId, operation.readyAt, now64);
        if (target != operation.target) revert HashMismatch(bytes32(uint256(uint160(operation.target))), bytes32(uint256(uint160(target))));
        if (value != operation.value) revert HashMismatch(bytes32(operation.value), bytes32(value));
        if (keccak256(data) != operation.dataHash) revert HashMismatch(operation.dataHash, keccak256(data));

        operation.executed = true;
        emit OperationExecuted(operationId, msg.sender);
        // slither-disable-next-line low-level-calls
        (bool success,) = target.call{ value: value }(data);
        if (!success) revert ExecutionFailed();
    }

    function getOperation(bytes32 operationId) external view returns (Operation memory) {
        return _requireOperation(operationId);
    }

    function owners() external view returns (address[] memory) {
        return _owners;
    }

    function hasApproved(bytes32 operationId, address owner) external view returns (bool) {
        return _approvedBy[operationId][owner];
    }

    function _requireOperation(bytes32 operationId) private view returns (Operation storage operation) {
        operation = _operations[operationId];
        if (operation.readyAt == 0) revert OperationNotFound(operationId);
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert OperationNotReady(bytes32(0), type(uint64).max, type(uint64).max);
        return uint64(block.timestamp);
    }
}
