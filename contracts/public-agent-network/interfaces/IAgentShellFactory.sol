// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAgentShellFactory {
    function graduateAgentToShell(bytes32 agentId, address shellOwner, bytes32 graduationRoot) external returns (address shell);
}
