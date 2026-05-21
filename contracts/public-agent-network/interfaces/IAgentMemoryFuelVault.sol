// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAgentMemoryFuelVault {
    function registerFuelAccount(bytes32 agentId, address owner, bytes32 classId, address token) external;
    function depositFuel(bytes32 agentId, address payer, address token, uint256 amount) external;
}
