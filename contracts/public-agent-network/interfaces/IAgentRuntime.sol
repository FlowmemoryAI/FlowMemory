// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAgentRuntime {
    struct ToolPolicy {
        address target;
        bytes4 selector;
        uint256 perActionValueCap;
        uint256 epochValueCap;
        uint256 maxTaskReward;
        bool enabled;
    }

    function registerAgent(
        address owner,
        bytes32 rootfieldId,
        bytes32 policyRoot,
        bytes32 toolAllowlistRoot,
        bytes32 initialMemoryRoot,
        bytes32 activeGoal,
        uint64 autonomyLevel,
        bytes32 kernelClass,
        bytes32 salt,
        string calldata uri
    ) external returns (bytes32 agentId);

    function setToolPolicy(bytes32 agentId, bytes32 toolId, ToolPolicy calldata policy, string calldata uri) external;
}
