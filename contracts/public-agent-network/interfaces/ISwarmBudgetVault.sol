// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISwarmBudgetVault {
    function deposit(bytes32 swarmId, address payer, address asset, uint256 amount) external;
}
