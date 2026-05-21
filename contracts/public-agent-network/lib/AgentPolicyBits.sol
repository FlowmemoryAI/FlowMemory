// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AgentPolicyBits {
    uint256 internal constant FLAG_DISCOVERABLE = 1 << 0;
    uint256 internal constant FLAG_SWARM_MEMBERSHIP_ALLOWED = 1 << 1;
    uint256 internal constant FLAG_SHELL_GRADUATION_ALLOWED = 1 << 2;
    uint256 internal constant FLAG_REQUIRES_EXTRA_BOND = 1 << 3;
    uint256 internal constant FLAG_REQUIRES_HUMAN_CONFIRM = 1 << 4;
    uint256 internal constant FLAG_MUTATING_TOOLSET = 1 << 5;

    function hasFlag(uint256 value, uint256 flag) internal pure returns (bool) {
        return (value & flag) != 0;
    }

    function setFlag(uint256 value, uint256 flag, bool enabled) internal pure returns (uint256) {
        return enabled ? value | flag : value & ~flag;
    }
}
