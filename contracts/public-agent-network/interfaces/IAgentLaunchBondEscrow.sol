// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAgentLaunchBondEscrow {
    function lockLaunchBond(
        bytes32 agentId,
        address payer,
        address beneficiary,
        bytes32 classId,
        address token,
        uint256 amount,
        bytes32 policyRoot
    ) external returns (bool);
}
