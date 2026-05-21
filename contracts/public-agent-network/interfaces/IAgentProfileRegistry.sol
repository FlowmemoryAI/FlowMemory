// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentLaunchTypes} from "../lib/AgentLaunchTypes.sol";

interface IAgentProfileRegistry {
    function getProfile(bytes32 agentId) external view returns (AgentLaunchTypes.AgentProfile memory);

    function setProfile(
        bytes32 agentId,
        address owner,
        bytes32 profileDigest,
        bytes32 publicMetadataRoot,
        bytes32 discoveryTagsRoot,
        bytes32 avatarDigest,
        bytes32 handleHash,
        bool discoverable
    ) external;
}
