// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../shared/TwoStepOwnable.sol";
import {AgentLaunchTypes} from "./lib/AgentLaunchTypes.sol";
import {IToolRegistry} from "./interfaces/IToolRegistry.sol";

contract ToolRegistry is TwoStepOwnable, IToolRegistry {
    mapping(bytes32 toolId => AgentLaunchTypes.Tool tool) private _tools;
    mapping(bytes32 toolSetRoot => AgentLaunchTypes.ToolSet toolSet) private _toolSets;
    mapping(bytes32 toolSetRoot => mapping(bytes32 toolId => bool present)) public toolSetContains;
    mapping(bytes32 classId => mapping(bytes32 toolSetRoot => bool allowed)) public classCanUseToolSet;
    mapping(bytes32 toolSetRoot => uint256 count) public toolSetMemberCount;

    error ZeroToolId();
    error ZeroToolSetRoot();
    error ZeroSchemaRoot();
    error ZeroAdapterDigest();
    error ZeroCategory();
    error ZeroMetadataDigest();
    error ToolAlreadyRegistered(bytes32 toolId);
    error ToolNotRegistered(bytes32 toolId);
    error ToolSetAlreadyRegistered(bytes32 toolSetRoot);
    error ToolSetNotRegistered(bytes32 toolSetRoot);
    error InactiveTool(bytes32 toolId);
    error ZeroClassId();
    error ZeroMaxAutonomyLevel();

    event ToolRegistered(
        bytes32 indexed toolId,
        uint64 version,
        uint8 riskTier,
        bool mutating,
        bytes32 adapterDigest
    );
    event ToolUpdated(bytes32 indexed toolId, uint64 version, bytes32 policyRoot, uint8 riskTier);
    event ToolDeprecated(bytes32 indexed toolId, uint64 version, bytes32 reasonCode);
    event ToolSetRegistered(
        bytes32 indexed toolSetRoot,
        uint64 version,
        uint8 maxRiskTier,
        bytes32 metadataDigest
    );
    event ToolSetMemberSet(bytes32 indexed toolSetRoot, bytes32 indexed toolId, bool enabled);
    event ToolSetAllowedForClass(bytes32 indexed classId, bytes32 indexed toolSetRoot);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    function registerTool(AgentLaunchTypes.Tool calldata tool) external onlyOwner {
        _validateTool(tool);
        if (_tools[tool.toolId].toolId != bytes32(0)) revert ToolAlreadyRegistered(tool.toolId);
        _tools[tool.toolId] = tool;
        emit ToolRegistered(tool.toolId, tool.version, tool.riskTier, tool.mutating, tool.adapterDigest);
    }

    function updateTool(bytes32 toolId, AgentLaunchTypes.Tool calldata tool) external onlyOwner {
        if (_tools[toolId].toolId == bytes32(0)) revert ToolNotRegistered(toolId);
        if (tool.toolId != toolId) revert ZeroToolId();
        _validateTool(tool);
        _tools[toolId] = tool;
        emit ToolUpdated(toolId, tool.version, tool.policyRoot, tool.riskTier);
    }

    function deprecateTool(bytes32 toolId, bytes32 reasonCode) external onlyOwner {
        AgentLaunchTypes.Tool storage tool = _tools[toolId];
        if (tool.toolId == bytes32(0)) revert ToolNotRegistered(toolId);
        tool.active = false;
        tool.deprecated = true;
        emit ToolDeprecated(toolId, tool.version, reasonCode);
    }

    function registerToolSet(AgentLaunchTypes.ToolSet calldata toolSet) external onlyOwner {
        if (toolSet.toolSetRoot == bytes32(0)) revert ZeroToolSetRoot();
        if (toolSet.metadataDigest == bytes32(0)) revert ZeroMetadataDigest();
        if (toolSet.maxAutonomyLevel == 0) revert ZeroMaxAutonomyLevel();
        if (_toolSets[toolSet.toolSetRoot].toolSetRoot != bytes32(0)) revert ToolSetAlreadyRegistered(toolSet.toolSetRoot);
        _toolSets[toolSet.toolSetRoot] = toolSet;
        emit ToolSetRegistered(toolSet.toolSetRoot, toolSet.version, toolSet.maxRiskTier, toolSet.metadataDigest);
    }

    function setToolInToolSet(bytes32 toolSetRoot, bytes32 toolId, bool enabled) external onlyOwner {
        if (_toolSets[toolSetRoot].toolSetRoot == bytes32(0)) revert ToolSetNotRegistered(toolSetRoot);
        AgentLaunchTypes.Tool memory tool = _tools[toolId];
        if (tool.toolId == bytes32(0)) revert ToolNotRegistered(toolId);
        if (!tool.active || tool.deprecated) revert InactiveTool(toolId);
        bool already = toolSetContains[toolSetRoot][toolId];
        if (enabled && !already) toolSetMemberCount[toolSetRoot] += 1;
        if (!enabled && already) toolSetMemberCount[toolSetRoot] -= 1;
        toolSetContains[toolSetRoot][toolId] = enabled;
        emit ToolSetMemberSet(toolSetRoot, toolId, enabled);
    }

    function allowToolSetForClass(bytes32 classId, bytes32 toolSetRoot) external onlyOwner {
        if (classId == bytes32(0)) revert ZeroClassId();
        if (_toolSets[toolSetRoot].toolSetRoot == bytes32(0)) revert ToolSetNotRegistered(toolSetRoot);
        classCanUseToolSet[classId][toolSetRoot] = true;
        emit ToolSetAllowedForClass(classId, toolSetRoot);
    }

    function getTool(bytes32 toolId) external view returns (AgentLaunchTypes.Tool memory) {
        AgentLaunchTypes.Tool memory tool = _tools[toolId];
        if (tool.toolId == bytes32(0)) revert ToolNotRegistered(toolId);
        return tool;
    }

    function getToolSet(bytes32 toolSetRoot) external view returns (AgentLaunchTypes.ToolSet memory) {
        AgentLaunchTypes.ToolSet memory toolSet = _toolSets[toolSetRoot];
        if (toolSet.toolSetRoot == bytes32(0)) revert ToolSetNotRegistered(toolSetRoot);
        return toolSet;
    }

    function validateToolSetForClass(bytes32 classId, bytes32 toolSetRoot, uint8 autonomyLevel)
        external
        view
        returns (bool)
    {
        AgentLaunchTypes.ToolSet memory toolSet = _toolSets[toolSetRoot];
        if (toolSet.toolSetRoot == bytes32(0)) return false;
        return toolSet.active && classCanUseToolSet[classId][toolSetRoot] && autonomyLevel <= toolSet.maxAutonomyLevel;
    }

    function _validateTool(AgentLaunchTypes.Tool calldata tool) private pure {
        if (tool.toolId == bytes32(0)) revert ZeroToolId();
        if (tool.category == bytes32(0)) revert ZeroCategory();
        if (tool.adapterDigest == bytes32(0)) revert ZeroAdapterDigest();
        if (tool.schemaRoot == bytes32(0)) revert ZeroSchemaRoot();
        if (tool.metadataDigest == bytes32(0)) revert ZeroMetadataDigest();
    }
}
