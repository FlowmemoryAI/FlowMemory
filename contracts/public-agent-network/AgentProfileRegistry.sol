// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../shared/TwoStepOwnable.sol";
import {AgentLaunchTypes} from "./lib/AgentLaunchTypes.sol";
import {IAgentProfileRegistry} from "./interfaces/IAgentProfileRegistry.sol";

contract AgentProfileRegistry is TwoStepOwnable, IAgentProfileRegistry {
    mapping(bytes32 agentId => AgentLaunchTypes.AgentProfile profile) private _profiles;
    mapping(bytes32 handleHash => bytes32 agentId) public handleToAgentId;
    mapping(address registrar => bool authorized) public isAuthorizedRegistrar;

    error ZeroAgentId();
    error ZeroOwnerAddress();
    error ZeroProfileDigest();
    error HandleAlreadyClaimed(bytes32 handleHash, bytes32 existingAgentId);
    error ProfileNotFound(bytes32 agentId);
    error UnauthorizedProfileWriter(bytes32 agentId, address caller);
    error ZeroRegistrar();

    event AuthorizedRegistrarSet(address indexed registrar, bool authorized);
    event AgentProfileSet(
        bytes32 indexed agentId,
        address indexed owner,
        bytes32 profileDigest,
        bytes32 publicMetadataRoot,
        bytes32 discoveryTagsRoot,
        bytes32 handleHash,
        bool discoverable
    );
    event AgentProfileVisibilityChanged(bytes32 indexed agentId, bool discoverable);
    event AgentHandleClaimed(bytes32 indexed agentId, bytes32 indexed handleHash);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    function setAuthorizedRegistrar(address registrar, bool authorized) external onlyOwner {
        if (registrar == address(0)) revert ZeroRegistrar();
        isAuthorizedRegistrar[registrar] = authorized;
        emit AuthorizedRegistrarSet(registrar, authorized);
    }

    function setProfile(
        bytes32 agentId,
        address owner_,
        bytes32 profileDigest,
        bytes32 publicMetadataRoot,
        bytes32 discoveryTagsRoot,
        bytes32 avatarDigest,
        bytes32 handleHash,
        bool discoverable
    ) external {
        if (agentId == bytes32(0)) revert ZeroAgentId();
        if (owner_ == address(0)) revert ZeroOwnerAddress();
        if (profileDigest == bytes32(0)) revert ZeroProfileDigest();

        AgentLaunchTypes.AgentProfile storage existing = _profiles[agentId];
        bool initializing = existing.agentId == bytes32(0);
        if (!initializing) {
            if (msg.sender != existing.owner && !isAuthorizedRegistrar[msg.sender]) {
                revert UnauthorizedProfileWriter(agentId, msg.sender);
            }
        } else if (msg.sender != owner_ && !isAuthorizedRegistrar[msg.sender]) {
            revert UnauthorizedProfileWriter(agentId, msg.sender);
        }

        if (handleHash != bytes32(0)) {
            bytes32 currentAgent = handleToAgentId[handleHash];
            if (currentAgent != bytes32(0) && currentAgent != agentId) {
                revert HandleAlreadyClaimed(handleHash, currentAgent);
            }
        }

        bytes32 previousHandle = existing.handleHash;
        if (previousHandle != bytes32(0) && previousHandle != handleHash) {
            delete handleToAgentId[previousHandle];
        }
        if (handleHash != bytes32(0)) {
            handleToAgentId[handleHash] = agentId;
            emit AgentHandleClaimed(agentId, handleHash);
        }

        uint64 nextVersion = initializing ? 1 : existing.version + 1;
        _profiles[agentId] = AgentLaunchTypes.AgentProfile({
            agentId: agentId,
            owner: owner_,
            profileDigest: profileDigest,
            publicMetadataRoot: publicMetadataRoot,
            discoveryTagsRoot: discoveryTagsRoot,
            avatarDigest: avatarDigest,
            handleHash: handleHash,
            discoverable: discoverable,
            version: nextVersion,
            updatedAt: uint64(block.timestamp)
        });

        emit AgentProfileSet(agentId, owner_, profileDigest, publicMetadataRoot, discoveryTagsRoot, handleHash, discoverable);
    }

    function setDiscoverable(bytes32 agentId, bool discoverable) external {
        AgentLaunchTypes.AgentProfile storage profile = _profiles[agentId];
        if (profile.agentId == bytes32(0)) revert ProfileNotFound(agentId);
        if (msg.sender != profile.owner && !isAuthorizedRegistrar[msg.sender]) {
            revert UnauthorizedProfileWriter(agentId, msg.sender);
        }
        profile.discoverable = discoverable;
        profile.updatedAt = uint64(block.timestamp);
        profile.version += 1;
        emit AgentProfileVisibilityChanged(agentId, discoverable);
    }

    function getProfile(bytes32 agentId) external view returns (AgentLaunchTypes.AgentProfile memory) {
        AgentLaunchTypes.AgentProfile memory profile = _profiles[agentId];
        if (profile.agentId == bytes32(0)) revert ProfileNotFound(agentId);
        return profile;
    }
}
