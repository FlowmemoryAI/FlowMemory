// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AgentReplayCodec {
    function launchReplayRoot(
        bytes32 launchIntentHash,
        bytes32 launchId,
        bytes32 agentId,
        bytes32 classId,
        bytes32 policyRoot,
        bytes32 toolAllowlistRoot,
        bytes32 initialMemoryRoot,
        bytes32 profileDigest
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                launchIntentHash,
                launchId,
                agentId,
                classId,
                policyRoot,
                toolAllowlistRoot,
                initialMemoryRoot,
                profileDigest
            )
        );
    }

    function bondReplayRoot(
        bytes32 agentId,
        address token,
        uint256 amount,
        bytes32 policyRoot
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(agentId, token, amount, policyRoot));
    }

    function fuelReplayRoot(
        bytes32 agentId,
        address token,
        uint256 amount,
        bytes32 receiptRoot
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(agentId, token, amount, receiptRoot));
    }
}
