// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentLaunchTypes} from "../lib/AgentLaunchTypes.sol";

interface IToolRegistry {
    function getTool(bytes32 toolId) external view returns (AgentLaunchTypes.Tool memory);
    function getToolSet(bytes32 toolSetRoot) external view returns (AgentLaunchTypes.ToolSet memory);
    function validateToolSetForClass(bytes32 classId, bytes32 toolSetRoot, uint8 autonomyLevel)
        external
        view
        returns (bool);
}
