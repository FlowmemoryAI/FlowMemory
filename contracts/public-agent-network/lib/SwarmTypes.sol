// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library SwarmTypes {
    enum SwarmStatus {
        None,
        Active,
        Paused,
        Dissolving,
        Dissolved,
        Graduated
    }

    enum MemberType {
        Wallet,
        Agent,
        Swarm,
        Shell
    }

    struct Swarm {
        bytes32 swarmId;
        address creator;
        bytes32 swarmClass;
        bytes32 missionRoot;
        bytes32 sharedMemoryRoot;
        bytes32 policyRoot;
        bytes32 roleRoot;
        bytes32 profileDigest;
        SwarmStatus status;
        address budgetVault;
        uint64 createdAt;
        uint64 updatedAt;
        uint64 generation;
        bytes32 parentSwarmId;
    }

    struct SwarmMember {
        MemberType memberType;
        address wallet;
        bytes32 agentId;
        bytes32 childSwarmId;
        address shell;
        bytes32 role;
        bytes32 permissionsRoot;
        uint16 weight;
        bool active;
        uint64 joinedAt;
        uint64 updatedAt;
    }

    struct SwarmPolicy {
        bytes32 policyId;
        bytes32 swarmClass;
        bytes32 admissionPolicyRoot;
        bytes32 budgetPolicyRoot;
        bytes32 rolePolicyRoot;
        uint8 maxMemberRiskTier;
        uint16 maxMembers;
        bool active;
    }

    struct SwarmIntent {
        address creator;
        bytes32 swarmClass;
        bytes32 missionRoot;
        bytes32 sharedMemoryRoot;
        bytes32 policyRoot;
        bytes32 roleRoot;
        bytes32 profileDigest;
        address budgetAsset;
        uint256 initialBudget;
        uint64 validAfter;
        uint64 validUntil;
        uint64 nonce;
        bytes32 parentSwarmId;
        bytes32 salt;
    }
}
