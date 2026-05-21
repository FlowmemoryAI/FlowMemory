// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentLaunchTypes} from "./AgentLaunchTypes.sol";

library AgentLaunchHashing {
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant LAUNCH_INTENT_TYPEHASH = keccak256(
        "LaunchIntent(address owner,address operator,bytes32 classId,bytes32 rootfieldId,bytes32 kernelClass,bytes32 rootsHash,bytes32 configHash,bytes32 lineageHash,bytes32 fundingHash,uint64 nonce,bytes32 salt)"
    );

    function domainSeparator(string memory name, string memory version, uint256 chainId, address verifyingContract)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract
            )
        );
    }

    function launchIntentStructHash(AgentLaunchTypes.LaunchIntent memory intent) internal pure returns (bytes32) {
        bytes32 rootsHash = keccak256(
            abi.encode(
                intent.policyRoot,
                intent.toolAllowlistRoot,
                intent.initialMemoryRoot,
                intent.activeGoalRoot,
                intent.launchSpecRoot
            )
        );
        bytes32 configHash = keccak256(
            abi.encode(
                intent.profileDigest,
                intent.autonomyLevel,
                intent.riskLevel,
                intent.discoverable,
                intent.validAfter,
                intent.validUntil
            )
        );
        bytes32 lineageHash = keccak256(abi.encode(intent.parentAgentId, intent.parentSwarmId));
        bytes32 fundingHash = keccak256(
            abi.encode(
                intent.bondToken,
                intent.bondAmount,
                intent.fuelToken,
                intent.initialFuelAmount
            )
        );
        return keccak256(
            abi.encode(
                LAUNCH_INTENT_TYPEHASH,
                intent.owner,
                intent.operator,
                intent.classId,
                intent.rootfieldId,
                intent.kernelClass,
                rootsHash,
                configHash,
                lineageHash,
                fundingHash,
                intent.nonce,
                intent.salt
            )
        );
    }

    function launchIntentDigest(
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract,
        AgentLaunchTypes.LaunchIntent memory intent
    ) internal pure returns (bytes32) {
        bytes32 separator = domainSeparator(name, version, chainId, verifyingContract);
        bytes32 structHash = launchIntentStructHash(intent);
        return keccak256(abi.encodePacked("\x19\x01", separator, structHash));
    }

    function launchId(uint256 chainId, address verifyingContract, AgentLaunchTypes.LaunchIntent memory intent)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                chainId,
                verifyingContract,
                intent.owner,
                intent.classId,
                intent.policyRoot,
                intent.toolAllowlistRoot,
                intent.initialMemoryRoot,
                intent.activeGoalRoot,
                intent.profileDigest,
                intent.nonce,
                intent.salt
            )
        );
    }

    function splitSignature(bytes memory signature) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (signature.length != 65) revert("invalid signature length");
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        if (v < 27) v += 27;
    }
}
