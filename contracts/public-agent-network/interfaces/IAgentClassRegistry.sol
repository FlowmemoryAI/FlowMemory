// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentLaunchTypes} from "../lib/AgentLaunchTypes.sol";

interface IAgentClassRegistry {
    function getClass(bytes32 classId) external view returns (AgentLaunchTypes.AgentClass memory);
    function isLaunchable(bytes32 classId) external view returns (bool);
}
