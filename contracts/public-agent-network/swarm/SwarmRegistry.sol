// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../../shared/TwoStepOwnable.sol";
import {SwarmTypes} from "../lib/SwarmTypes.sol";

contract SwarmRegistry is TwoStepOwnable {
    mapping(bytes32 swarmId => SwarmTypes.Swarm swarm) private _swarms;
    mapping(bytes32 swarmId => mapping(bytes32 memberKey => SwarmTypes.SwarmMember member)) private _members;
    mapping(bytes32 swarmId => bytes32[] memberKeys) private _memberKeys;
    mapping(address registrar => bool authorized) public isAuthorizedRegistrar;

    error ZeroSwarmId();
    error ZeroCreator();
    error ZeroSwarmClass();
    error ZeroMissionRoot();
    error ZeroPolicyRoot();
    error ZeroRoleRoot();
    error SwarmAlreadyExists(bytes32 swarmId);
    error SwarmNotFound(bytes32 swarmId);
    error UnauthorizedRegistrar(address caller);
    error UnauthorizedSwarmOperator(bytes32 swarmId, address caller);
    error MemberAlreadyExists(bytes32 swarmId, bytes32 memberKey);
    error MemberNotFound(bytes32 swarmId, bytes32 memberKey);
    error InvalidSwarmStatus(bytes32 swarmId, SwarmTypes.SwarmStatus status);

    event AuthorizedRegistrarSet(address indexed registrar, bool authorized);
    event SwarmCreated(
        bytes32 indexed swarmId,
        address indexed creator,
        bytes32 swarmClass,
        bytes32 missionRoot,
        bytes32 sharedMemoryRoot,
        bytes32 policyRoot,
        bytes32 roleRoot
    );
    event SwarmMissionUpdated(bytes32 indexed swarmId, bytes32 previousMissionRoot, bytes32 newMissionRoot, bytes32 reasonCode);
    event SwarmSharedMemoryUpdated(bytes32 indexed swarmId, bytes32 previousSharedMemoryRoot, bytes32 newSharedMemoryRoot, bytes32 receiptRoot);
    event SwarmMemberJoined(bytes32 indexed swarmId, bytes32 indexed memberKey, SwarmTypes.MemberType memberType, bytes32 role, bytes32 permissionsRoot);
    event SwarmMemberLeft(bytes32 indexed swarmId, bytes32 indexed memberKey, bytes32 reasonCode);
    event SwarmMemberRoleChanged(bytes32 indexed swarmId, bytes32 indexed memberKey, bytes32 oldRole, bytes32 newRole, bytes32 permissionsRoot);
    event SwarmPaused(bytes32 indexed swarmId, bytes32 reasonCode);
    event SwarmDissolved(bytes32 indexed swarmId, bytes32 finalMemoryRoot, bytes32 dissolutionReceiptRoot);
    event SwarmGraduated(bytes32 indexed swarmId, address indexed shell, bytes32 graduationRoot);
    event SwarmForked(bytes32 indexed parentSwarmId, bytes32 indexed childSwarmId, bytes32 forkRoot);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    modifier onlyAuthorizedRegistrar() {
        if (!isAuthorizedRegistrar[msg.sender]) revert UnauthorizedRegistrar(msg.sender);
        _;
    }

    function setAuthorizedRegistrar(address registrar, bool authorized) external onlyOwner {
        if (registrar == address(0)) revert ZeroCreator();
        isAuthorizedRegistrar[registrar] = authorized;
        emit AuthorizedRegistrarSet(registrar, authorized);
    }

    function createSwarm(SwarmTypes.Swarm calldata swarm, SwarmTypes.SwarmMember[] calldata initialMembers)
        external
        onlyAuthorizedRegistrar
        returns (bytes32 swarmId)
    {
        _validateCreate(swarm);
        swarmId = swarm.swarmId;
        if (_swarms[swarmId].swarmId != bytes32(0)) revert SwarmAlreadyExists(swarmId);
        _swarms[swarmId] = swarm;
        emit SwarmCreated(swarmId, swarm.creator, swarm.swarmClass, swarm.missionRoot, swarm.sharedMemoryRoot, swarm.policyRoot, swarm.roleRoot);

        for (uint256 i = 0; i < initialMembers.length; i += 1) {
            _addMember(swarmId, initialMembers[i]);
        }
    }

    function joinSwarm(bytes32 swarmId, SwarmTypes.SwarmMember calldata member, bytes calldata)
        external
        onlyAuthorizedRegistrar
    {
        if (_swarms[swarmId].swarmId == bytes32(0)) revert SwarmNotFound(swarmId);
        _addMember(swarmId, member);
    }

    function leaveSwarm(bytes32 swarmId, bytes32 memberKey, bytes32 reasonCode) external {
        SwarmTypes.Swarm storage swarm = _requireOperator(swarmId);
        if (_members[swarmId][memberKey].joinedAt == 0) revert MemberNotFound(swarmId, memberKey);
        delete _members[swarmId][memberKey];
        swarm.updatedAt = uint64(block.timestamp);
        emit SwarmMemberLeft(swarmId, memberKey, reasonCode);
    }

    function updateMemberRole(bytes32 swarmId, bytes32 memberKey, bytes32 newRole, bytes32 permissionsRoot) external {
        SwarmTypes.Swarm storage swarm = _requireOperator(swarmId);
        SwarmTypes.SwarmMember storage member = _members[swarmId][memberKey];
        if (member.joinedAt == 0) revert MemberNotFound(swarmId, memberKey);
        bytes32 oldRole = member.role;
        member.role = newRole;
        member.permissionsRoot = permissionsRoot;
        member.updatedAt = uint64(block.timestamp);
        swarm.updatedAt = uint64(block.timestamp);
        emit SwarmMemberRoleChanged(swarmId, memberKey, oldRole, newRole, permissionsRoot);
    }

    function updateMissionRoot(bytes32 swarmId, bytes32 newMissionRoot, bytes32 reasonCode) external {
        SwarmTypes.Swarm storage swarm = _requireOperator(swarmId);
        bytes32 previous = swarm.missionRoot;
        swarm.missionRoot = newMissionRoot;
        swarm.updatedAt = uint64(block.timestamp);
        emit SwarmMissionUpdated(swarmId, previous, newMissionRoot, reasonCode);
    }

    function updateSharedMemoryRoot(bytes32 swarmId, bytes32 newSharedMemoryRoot, bytes32 receiptRoot) external {
        SwarmTypes.Swarm storage swarm = _requireOperator(swarmId);
        bytes32 previous = swarm.sharedMemoryRoot;
        swarm.sharedMemoryRoot = newSharedMemoryRoot;
        swarm.updatedAt = uint64(block.timestamp);
        emit SwarmSharedMemoryUpdated(swarmId, previous, newSharedMemoryRoot, receiptRoot);
    }

    function pauseSwarm(bytes32 swarmId, bytes32 reasonCode) external {
        SwarmTypes.Swarm storage swarm = _requireOperator(swarmId);
        swarm.status = SwarmTypes.SwarmStatus.Paused;
        swarm.updatedAt = uint64(block.timestamp);
        emit SwarmPaused(swarmId, reasonCode);
    }

    function dissolveSwarm(bytes32 swarmId, bytes32 finalMemoryRoot, bytes32 receiptRoot) external {
        SwarmTypes.Swarm storage swarm = _requireOperator(swarmId);
        swarm.status = SwarmTypes.SwarmStatus.Dissolved;
        swarm.sharedMemoryRoot = finalMemoryRoot;
        swarm.updatedAt = uint64(block.timestamp);
        emit SwarmDissolved(swarmId, finalMemoryRoot, receiptRoot);
    }

    function forkSwarm(bytes32 parentSwarmId, SwarmTypes.Swarm calldata childSwarm, bytes32 forkRoot)
        external
        onlyAuthorizedRegistrar
        returns (bytes32 childSwarmId)
    {
        if (_swarms[parentSwarmId].swarmId == bytes32(0)) revert SwarmNotFound(parentSwarmId);
        _validateCreate(childSwarm);
        childSwarmId = childSwarm.swarmId;
        if (_swarms[childSwarmId].swarmId != bytes32(0)) revert SwarmAlreadyExists(childSwarmId);
        _swarms[childSwarmId] = childSwarm;
        emit SwarmForked(parentSwarmId, childSwarmId, forkRoot);
    }

    function graduateSwarm(bytes32 swarmId, address shell, bytes32 graduationRoot) external {
        SwarmTypes.Swarm storage swarm = _requireOperator(swarmId);
        swarm.status = SwarmTypes.SwarmStatus.Graduated;
        swarm.updatedAt = uint64(block.timestamp);
        emit SwarmGraduated(swarmId, shell, graduationRoot);
    }

    function getSwarm(bytes32 swarmId) external view returns (SwarmTypes.Swarm memory) {
        SwarmTypes.Swarm memory swarm = _swarms[swarmId];
        if (swarm.swarmId == bytes32(0)) revert SwarmNotFound(swarmId);
        return swarm;
    }

    function getMember(bytes32 swarmId, bytes32 memberKey) external view returns (SwarmTypes.SwarmMember memory) {
        SwarmTypes.SwarmMember memory member = _members[swarmId][memberKey];
        if (member.joinedAt == 0) revert MemberNotFound(swarmId, memberKey);
        return member;
    }

    function getMemberKeys(bytes32 swarmId) external view returns (bytes32[] memory) {
        return _memberKeys[swarmId];
    }

    function _validateCreate(SwarmTypes.Swarm calldata swarm) private pure {
        if (swarm.swarmId == bytes32(0)) revert ZeroSwarmId();
        if (swarm.creator == address(0)) revert ZeroCreator();
        if (swarm.swarmClass == bytes32(0)) revert ZeroSwarmClass();
        if (swarm.missionRoot == bytes32(0)) revert ZeroMissionRoot();
        if (swarm.policyRoot == bytes32(0)) revert ZeroPolicyRoot();
        if (swarm.roleRoot == bytes32(0)) revert ZeroRoleRoot();
    }

    function _addMember(bytes32 swarmId, SwarmTypes.SwarmMember calldata member) private {
        bytes32 memberKey = keccak256(abi.encode(member.memberType, member.wallet, member.agentId, member.childSwarmId, member.shell));
        if (_members[swarmId][memberKey].joinedAt != 0) revert MemberAlreadyExists(swarmId, memberKey);
        SwarmTypes.SwarmMember memory initialized = member;
        initialized.joinedAt = uint64(block.timestamp);
        initialized.updatedAt = uint64(block.timestamp);
        initialized.active = true;
        _members[swarmId][memberKey] = initialized;
        _memberKeys[swarmId].push(memberKey);
        emit SwarmMemberJoined(swarmId, memberKey, member.memberType, member.role, member.permissionsRoot);
    }

    function _requireOperator(bytes32 swarmId) private view returns (SwarmTypes.Swarm storage swarm) {
        swarm = _swarms[swarmId];
        if (swarm.swarmId == bytes32(0)) revert SwarmNotFound(swarmId);
        if (msg.sender != owner && msg.sender != swarm.creator && !isAuthorizedRegistrar[msg.sender]) {
            revert UnauthorizedSwarmOperator(swarmId, msg.sender);
        }
        if (swarm.status == SwarmTypes.SwarmStatus.Dissolved || swarm.status == SwarmTypes.SwarmStatus.Graduated) {
            revert InvalidSwarmStatus(swarmId, swarm.status);
        }
    }
}
