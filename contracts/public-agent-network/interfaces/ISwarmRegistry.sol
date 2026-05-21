// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SwarmTypes} from "../lib/SwarmTypes.sol";

interface ISwarmRegistry {
    function createSwarm(SwarmTypes.Swarm calldata swarm, SwarmTypes.SwarmMember[] calldata initialMembers)
        external
        returns (bytes32 swarmId);
}
