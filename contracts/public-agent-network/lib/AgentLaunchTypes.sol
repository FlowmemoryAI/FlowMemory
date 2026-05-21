// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library AgentLaunchTypes {
    enum ParentType {
        None,
        Agent,
        Swarm,
        Shell
    }

    enum BondStatus {
        None,
        Locked,
        ReleaseRequested,
        Released,
        Slashed
    }

    struct AgentClass {
        bytes32 classId;
        uint64 version;
        bool active;
        bool deprecated;
        bytes32 kernelClass;
        bytes32 schemaRoot;
        bytes32 defaultPolicyRoot;
        bytes32 allowedToolPolicyRoot;
        bytes32 pricingRoot;
        bytes32 metadataDigest;
        uint8 minAutonomyLevel;
        uint8 maxAutonomyLevel;
        uint8 maxToolRiskTier;
        uint16 maxTools;
        uint256 minLaunchBond;
        uint256 minMemoryFuel;
        bool allowPublicLaunch;
        bool allowSwarmMembership;
        bool allowShellGraduation;
    }

    struct Tool {
        bytes32 toolId;
        uint64 version;
        bool active;
        bool deprecated;
        bytes32 category;
        bytes32 adapterDigest;
        bytes32 schemaRoot;
        bytes32 policyRoot;
        bytes32 metadataDigest;
        uint8 riskTier;
        bool mutating;
        bool requiresDryRun;
        bool requiresHumanConfirm;
        bool requiresExtraBond;
        bytes32 compatibleKernelRoot;
    }

    struct ToolSet {
        bytes32 toolSetRoot;
        uint64 version;
        bool active;
        uint8 maxRiskTier;
        uint8 maxAutonomyLevel;
        bytes32 metadataDigest;
    }

    struct AgentProfile {
        bytes32 agentId;
        address owner;
        bytes32 profileDigest;
        bytes32 publicMetadataRoot;
        bytes32 discoveryTagsRoot;
        bytes32 avatarDigest;
        bytes32 handleHash;
        bool discoverable;
        uint64 version;
        uint64 updatedAt;
    }

    struct BondPolicy {
        address token;
        uint256 minAmount;
        uint256 maxAmount;
        uint64 minLockSeconds;
        uint64 releaseDelaySeconds;
        uint16 slashCapBps;
        bool active;
    }

    struct LaunchIntent {
        address owner;
        address operator;
        bytes32 classId;
        bytes32 rootfieldId;
        bytes32 kernelClass;
        bytes32 policyRoot;
        bytes32 toolAllowlistRoot;
        bytes32 initialMemoryRoot;
        bytes32 activeGoalRoot;
        bytes32 profileDigest;
        bytes32 launchSpecRoot;
        uint8 autonomyLevel;
        uint8 riskLevel;
        bytes32 parentAgentId;
        bytes32 parentSwarmId;
        address bondToken;
        uint256 bondAmount;
        address fuelToken;
        uint256 initialFuelAmount;
        bool discoverable;
        uint64 validAfter;
        uint64 validUntil;
        uint64 nonce;
        bytes32 salt;
    }

    struct LaunchPayment {
        bool sponsorMode;
        address sponsor;
    }
}
