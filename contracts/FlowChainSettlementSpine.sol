// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FlowChainSettlementSpine
/// @notice Compact local/test settlement event spine for FlowChain object commitments.
/// @dev This records commitment metadata only. Raw objects, verifier logic, and
/// runtime state transitions remain off-chain or in the private/local runtime.
contract FlowChainSettlementSpine {
    struct ObjectCommitment {
        address submitter;
        bytes32 objectType;
        bytes32 rootfieldId;
        bytes32 commitment;
        bytes32 parentObjectId;
        uint64 sequence;
        uint64 committedAt;
        bool exists;
    }

    bytes32 public constant BRIDGE_DEPOSIT_OBJECT = keccak256("flowchain.object.bridge-deposit.v0");
    bytes32 public constant BRIDGE_CREDIT_OBJECT = keccak256("flowchain.object.bridge-credit.v0");
    bytes32 public constant BRIDGE_WITHDRAWAL_INTENT_OBJECT = keccak256("flowchain.object.bridge-withdrawal-intent.v0");
    bytes32 public constant MEMORY_OBJECT = keccak256("flowchain.object.memory.v0");
    bytes32 public constant FINALITY_OBJECT = keccak256("flowchain.object.finality.v0");

    address public owner;
    uint64 public nextSequence = 1;

    mapping(address submitter => bool authorized) public authorizedSubmitters;
    mapping(bytes32 objectId => ObjectCommitment commitment) private _commitments;

    error NotOwner(address caller);
    error SubmitterNotAuthorized(address submitter);
    error ZeroOwner();
    error ZeroSubmitter();
    error ZeroObjectType();
    error ZeroObjectId();
    error ZeroRootfieldId();
    error ZeroCommitment();
    error ObjectAlreadyCommitted(bytes32 objectId);
    error ObjectNotCommitted(bytes32 objectId);
    error TimestampOverflow(uint256 timestamp);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SubmitterAuthorizationSet(address indexed submitter, bool authorized);
    event FlowChainObjectCommitted(
        bytes32 indexed objectId,
        bytes32 indexed rootfieldId,
        bytes32 indexed objectType,
        address submitter,
        bytes32 commitment,
        bytes32 parentObjectId,
        uint64 sequence,
        uint64 committedAt,
        string evidenceURI
    );

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    modifier onlyAuthorizedSubmitter() {
        if (!authorizedSubmitters[msg.sender]) {
            revert SubmitterNotAuthorized(msg.sender);
        }
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert ZeroOwner();
        }
        owner = initialOwner;
        authorizedSubmitters[initialOwner] = true;
        emit OwnershipTransferred(address(0), initialOwner);
        emit SubmitterAuthorizationSet(initialOwner, true);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert ZeroOwner();
        }
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function setSubmitterAuthorization(address submitter, bool authorized) external onlyOwner {
        if (submitter == address(0)) {
            revert ZeroSubmitter();
        }
        authorizedSubmitters[submitter] = authorized;
        emit SubmitterAuthorizationSet(submitter, authorized);
    }

    function commitObject(
        bytes32 objectType,
        bytes32 objectId,
        bytes32 rootfieldId,
        bytes32 commitment,
        bytes32 parentObjectId,
        string calldata evidenceURI
    ) external onlyAuthorizedSubmitter returns (uint64 sequence) {
        if (objectType == bytes32(0)) {
            revert ZeroObjectType();
        }
        if (objectId == bytes32(0)) {
            revert ZeroObjectId();
        }
        if (rootfieldId == bytes32(0)) {
            revert ZeroRootfieldId();
        }
        if (commitment == bytes32(0)) {
            revert ZeroCommitment();
        }
        if (_commitments[objectId].exists) {
            revert ObjectAlreadyCommitted(objectId);
        }

        sequence = nextSequence++;
        uint64 committedAt = _blockTimestamp();
        _commitments[objectId] = ObjectCommitment({
            submitter: msg.sender,
            objectType: objectType,
            rootfieldId: rootfieldId,
            commitment: commitment,
            parentObjectId: parentObjectId,
            sequence: sequence,
            committedAt: committedAt,
            exists: true
        });

        emit FlowChainObjectCommitted({
            objectId: objectId,
            rootfieldId: rootfieldId,
            objectType: objectType,
            submitter: msg.sender,
            commitment: commitment,
            parentObjectId: parentObjectId,
            sequence: sequence,
            committedAt: committedAt,
            evidenceURI: evidenceURI
        });
    }

    function getObjectCommitment(bytes32 objectId) external view returns (ObjectCommitment memory commitment) {
        commitment = _commitments[objectId];
        if (!commitment.exists) {
            revert ObjectNotCommitted(objectId);
        }
    }

    function isObjectCommitted(bytes32 objectId) external view returns (bool) {
        return _commitments[objectId].exists;
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) {
            revert TimestampOverflow(block.timestamp);
        }
        return uint64(block.timestamp);
    }
}
