// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../shared/TwoStepOwnable.sol";
import {AgentLaunchTypes} from "./lib/AgentLaunchTypes.sol";
import {IAgentClassRegistry} from "./interfaces/IAgentClassRegistry.sol";

contract AgentClassRegistry is TwoStepOwnable, IAgentClassRegistry {
    mapping(bytes32 classId => AgentLaunchTypes.AgentClass config) private _classes;
    mapping(bytes32 classId => address registrar) public classRegistrar;
    mapping(bytes32 classId => mapping(uint64 version => bytes32 configRoot)) public classVersionRoot;

    error ZeroClassId();
    error ZeroKernelClass();
    error ZeroSchemaRoot();
    error ZeroDefaultPolicyRoot();
    error ZeroAllowedToolPolicyRoot();
    error InvalidAutonomyBounds(uint8 minAutonomyLevel, uint8 maxAutonomyLevel);
    error ZeroMaxTools();
    error ClassAlreadyRegistered(bytes32 classId);
    error ClassNotRegistered(bytes32 classId);
    error NotClassRegistrar(bytes32 classId, address caller);

    event AgentClassRegistered(
        bytes32 indexed classId,
        uint64 version,
        bytes32 kernelClass,
        bytes32 schemaRoot,
        bytes32 defaultPolicyRoot,
        bytes32 metadataDigest
    );
    event AgentClassUpdated(bytes32 indexed classId, uint64 version, bytes32 configRoot);
    event AgentClassDeprecated(bytes32 indexed classId, uint64 version, bytes32 reasonCode);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    function registerClass(AgentLaunchTypes.AgentClass calldata config) external onlyOwner {
        _validate(config);
        if (_classes[config.classId].classId != bytes32(0)) revert ClassAlreadyRegistered(config.classId);

        _classes[config.classId] = config;
        classRegistrar[config.classId] = msg.sender;
        classVersionRoot[config.classId][config.version] = _classConfigRoot(config);

        emit AgentClassRegistered(
            config.classId,
            config.version,
            config.kernelClass,
            config.schemaRoot,
            config.defaultPolicyRoot,
            config.metadataDigest
        );
    }

    function updateClass(bytes32 classId, AgentLaunchTypes.AgentClass calldata config) external {
        if (_classes[classId].classId == bytes32(0)) revert ClassNotRegistered(classId);
        if (msg.sender != owner && msg.sender != classRegistrar[classId]) revert NotClassRegistrar(classId, msg.sender);
        if (config.classId != classId) revert ZeroClassId();
        _validate(config);

        _classes[classId] = config;
        classRegistrar[classId] = msg.sender;
        classVersionRoot[classId][config.version] = _classConfigRoot(config);

        emit AgentClassUpdated(classId, config.version, classVersionRoot[classId][config.version]);
    }

    function deprecateClass(bytes32 classId, bytes32 reasonCode) external {
        AgentLaunchTypes.AgentClass storage config = _classes[classId];
        if (config.classId == bytes32(0)) revert ClassNotRegistered(classId);
        if (msg.sender != owner && msg.sender != classRegistrar[classId]) revert NotClassRegistrar(classId, msg.sender);
        config.active = false;
        config.deprecated = true;
        classVersionRoot[classId][config.version] = _classConfigRoot(config);
        emit AgentClassDeprecated(classId, config.version, reasonCode);
    }

    function getClass(bytes32 classId) external view returns (AgentLaunchTypes.AgentClass memory) {
        AgentLaunchTypes.AgentClass memory config = _classes[classId];
        if (config.classId == bytes32(0)) revert ClassNotRegistered(classId);
        return config;
    }

    function isLaunchable(bytes32 classId) external view returns (bool) {
        AgentLaunchTypes.AgentClass memory config = _classes[classId];
        return config.classId != bytes32(0) && config.active && !config.deprecated && config.allowPublicLaunch;
    }

    function _validate(AgentLaunchTypes.AgentClass calldata config) private pure {
        if (config.classId == bytes32(0)) revert ZeroClassId();
        if (config.kernelClass == bytes32(0)) revert ZeroKernelClass();
        if (config.schemaRoot == bytes32(0)) revert ZeroSchemaRoot();
        if (config.defaultPolicyRoot == bytes32(0)) revert ZeroDefaultPolicyRoot();
        if (config.allowedToolPolicyRoot == bytes32(0)) revert ZeroAllowedToolPolicyRoot();
        if (config.minAutonomyLevel > config.maxAutonomyLevel) {
            revert InvalidAutonomyBounds(config.minAutonomyLevel, config.maxAutonomyLevel);
        }
        if (config.maxTools == 0) revert ZeroMaxTools();
    }

    function _classConfigRoot(AgentLaunchTypes.AgentClass memory config) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                config.classId,
                config.version,
                config.active,
                config.deprecated,
                config.kernelClass,
                config.schemaRoot,
                config.defaultPolicyRoot,
                config.allowedToolPolicyRoot,
                config.pricingRoot,
                config.metadataDigest,
                config.minAutonomyLevel,
                config.maxAutonomyLevel,
                config.maxToolRiskTier,
                config.maxTools,
                config.minLaunchBond,
                config.minMemoryFuel,
                config.allowPublicLaunch,
                config.allowSwarmMembership,
                config.allowShellGraduation
            )
        );
    }
}
