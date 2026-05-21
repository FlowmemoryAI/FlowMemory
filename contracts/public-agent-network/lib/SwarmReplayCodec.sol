// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library SwarmReplayCodec {
    function swarmReplayRoot(
        bytes32 swarmId,
        bytes32 missionRoot,
        bytes32 sharedMemoryRoot,
        bytes32 policyRoot,
        bytes32 roleRoot,
        bytes32 profileDigest
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(swarmId, missionRoot, sharedMemoryRoot, policyRoot, roleRoot, profileDigest));
    }

    function swarmBudgetReplayRoot(
        bytes32 swarmId,
        bytes32 budgetLineId,
        address asset,
        uint256 amount,
        bytes32 receiptRoot
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(swarmId, budgetLineId, asset, amount, receiptRoot));
    }
}
