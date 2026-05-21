// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../shared/TwoStepOwnable.sol";
import {AgentLaunchTypes} from "./lib/AgentLaunchTypes.sol";
import {IAgentLineageRegistry} from "./interfaces/IAgentLineageRegistry.sol";

contract AgentLineageRegistry is TwoStepOwnable, IAgentLineageRegistry {
    struct Lineage {
        bytes32 agentId;
        AgentLaunchTypes.ParentType parentType;
        bytes32 parentAgentId;
        bytes32 parentSwarmId;
        address parentShell;
        bytes32 lineageRoot;
        uint64 generation;
        uint64 createdAt;
    }

    mapping(bytes32 agentId => Lineage lineage) private _lineageOf;
    mapping(bytes32 parentAgentId => bytes32[] childAgentIds) private _agentChildren;
    mapping(bytes32 parentSwarmId => bytes32[] childAgentIds) private _swarmChildren;
    mapping(address registrar => bool authorized) public isAuthorizedRegistrar;

    error ZeroAgentId();
    error ZeroRegistrar();
    error UnauthorizedRegistrar(address caller);
    error LineageAlreadyExists(bytes32 agentId);
    error InvalidParentType();
    error MissingParentAgent();
    error MissingParentSwarm();
    error MissingLineageRoot();

    event AuthorizedRegistrarSet(address indexed registrar, bool authorized);
    event AgentLineageAttached(
        bytes32 indexed agentId,
        AgentLaunchTypes.ParentType parentType,
        bytes32 indexed parentAgentId,
        bytes32 indexed parentSwarmId,
        bytes32 lineageRoot,
        uint64 generation
    );
    event AgentDescendantRegistered(bytes32 indexed parentAgentId, bytes32 indexed childAgentId, bytes32 lineageRoot);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    function setAuthorizedRegistrar(address registrar, bool authorized) external onlyOwner {
        if (registrar == address(0)) revert ZeroRegistrar();
        isAuthorizedRegistrar[registrar] = authorized;
        emit AuthorizedRegistrarSet(registrar, authorized);
    }

    function attachLineage(
        bytes32 agentId,
        AgentLaunchTypes.ParentType parentType,
        bytes32 parentAgentId,
        bytes32 parentSwarmId,
        address parentShell,
        bytes32 lineageRoot,
        uint64 generation
    ) external {
        if (!isAuthorizedRegistrar[msg.sender]) revert UnauthorizedRegistrar(msg.sender);
        if (agentId == bytes32(0)) revert ZeroAgentId();
        if (lineageRoot == bytes32(0)) revert MissingLineageRoot();
        if (_lineageOf[agentId].agentId != bytes32(0)) revert LineageAlreadyExists(agentId);
        if (parentType == AgentLaunchTypes.ParentType.Agent && parentAgentId == bytes32(0)) revert MissingParentAgent();
        if (parentType == AgentLaunchTypes.ParentType.Swarm && parentSwarmId == bytes32(0)) revert MissingParentSwarm();
        if (parentType == AgentLaunchTypes.ParentType.None && (parentAgentId != bytes32(0) || parentSwarmId != bytes32(0) || parentShell != address(0))) {
            revert InvalidParentType();
        }

        _lineageOf[agentId] = Lineage({
            agentId: agentId,
            parentType: parentType,
            parentAgentId: parentAgentId,
            parentSwarmId: parentSwarmId,
            parentShell: parentShell,
            lineageRoot: lineageRoot,
            generation: generation,
            createdAt: uint64(block.timestamp)
        });

        if (parentAgentId != bytes32(0)) {
            _agentChildren[parentAgentId].push(agentId);
            emit AgentDescendantRegistered(parentAgentId, agentId, lineageRoot);
        }
        if (parentSwarmId != bytes32(0)) {
            _swarmChildren[parentSwarmId].push(agentId);
        }

        emit AgentLineageAttached(agentId, parentType, parentAgentId, parentSwarmId, lineageRoot, generation);
    }

    function getLineage(bytes32 agentId) external view returns (Lineage memory) {
        return _lineageOf[agentId];
    }

    function getAgentChildren(bytes32 parentAgentId) external view returns (bytes32[] memory) {
        return _agentChildren[parentAgentId];
    }

    function getSwarmChildren(bytes32 parentSwarmId) external view returns (bytes32[] memory) {
        return _swarmChildren[parentSwarmId];
    }
}
