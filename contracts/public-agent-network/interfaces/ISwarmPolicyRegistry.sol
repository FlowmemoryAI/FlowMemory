// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SwarmTypes} from "../lib/SwarmTypes.sol";

interface ISwarmPolicyRegistry {
    function getPolicy(bytes32 policyId) external view returns (SwarmTypes.SwarmPolicy memory);
}
