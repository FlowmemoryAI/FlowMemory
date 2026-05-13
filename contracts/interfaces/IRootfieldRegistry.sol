// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRootfieldRegistry {
    function registerRootfield(
        bytes32 rootfieldId,
        bytes32 schemaHash,
        bytes32 metadataHash,
        string calldata metadataURI
    ) external returns (bytes32 pulseId);

    function submitRoot(
        bytes32 rootfieldId,
        bytes32 root,
        bytes32 artifactCommitment,
        bytes32 parentPulseId,
        string calldata evidenceURI
    ) external returns (bytes32 pulseId);

    function deactivateRootfield(bytes32 rootfieldId, bytes32 parentPulseId, string calldata reasonURI)
        external
        returns (bytes32 pulseId);

    function transferRootfieldOwnership(bytes32 rootfieldId, address newOwner, string calldata evidenceURI)
        external
        returns (bytes32 pulseId);

    function isRegistered(bytes32 rootfieldId) external view returns (bool);
}
