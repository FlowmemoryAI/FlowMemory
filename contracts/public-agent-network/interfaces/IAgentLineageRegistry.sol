// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentLaunchTypes} from "../lib/AgentLaunchTypes.sol";

interface IAgentLineageRegistry {
    function attachLineage(
        bytes32 agentId,
        AgentLaunchTypes.ParentType parentType,
        bytes32 parentAgentId,
        bytes32 parentSwarmId,
        address parentShell,
        bytes32 lineageRoot,
        uint64 generation
    ) external;
}
