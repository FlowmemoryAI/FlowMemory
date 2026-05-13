// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVerifierRegistry} from "./interfaces/IVerifierRegistry.sol";

/// @title VerifierRegistry
/// @notice Minimal v0 self-registry for verifier identities and metadata commitments.
/// @dev Registration does not prove verifier correctness or authorize any rewards.
contract VerifierRegistry is IVerifierRegistry {
    mapping(address verifier => Verifier record) private _verifiers;

    error ZeroVerifier();
    error ZeroOperatorId();
    error ZeroVerifierRole();
    error VerifierAlreadyRegistered(address verifier);
    error VerifierNotRegistered(address verifier);
    error VerifierNotActive(address verifier);
    error TimestampOverflow(uint256 timestamp);

    function registerVerifier(bytes32 operatorId, bytes32 role, bytes32 metadataHash, string calldata metadataURI)
        external
    {
        if (msg.sender == address(0)) revert ZeroVerifier();
        if (operatorId == bytes32(0)) revert ZeroOperatorId();
        if (role == bytes32(0)) revert ZeroVerifierRole();
        if (_verifiers[msg.sender].status != VerifierStatus.Unknown) revert VerifierAlreadyRegistered(msg.sender);

        uint64 now64 = _blockTimestamp();
        _verifiers[msg.sender] = Verifier({
            operatorId: operatorId,
            role: role,
            metadataHash: metadataHash,
            status: VerifierStatus.Active,
            registeredAt: now64,
            updatedAt: now64,
            updateCount: 1,
            active: true
        });

        emit VerifierRegistered(msg.sender, operatorId, role, metadataHash, metadataURI);
    }

    function updateVerifierMetadata(bytes32 metadataHash, string calldata metadataURI) external {
        Verifier storage verifier = _verifiers[msg.sender];
        if (verifier.status == VerifierStatus.Unknown) revert VerifierNotRegistered(msg.sender);
        if (verifier.status != VerifierStatus.Active) revert VerifierNotActive(msg.sender);

        verifier.metadataHash = metadataHash;
        verifier.updatedAt = _blockTimestamp();
        verifier.updateCount += 1;

        emit VerifierMetadataUpdated(msg.sender, verifier.operatorId, metadataHash, verifier.updateCount, metadataURI);
    }

    function deactivateVerifier(bytes32 reasonHash, string calldata evidenceURI) external {
        Verifier storage verifier = _verifiers[msg.sender];
        if (verifier.status == VerifierStatus.Unknown) revert VerifierNotRegistered(msg.sender);
        if (verifier.status != VerifierStatus.Active) revert VerifierNotActive(msg.sender);

        verifier.status = VerifierStatus.Inactive;
        verifier.active = false;
        verifier.updatedAt = _blockTimestamp();
        verifier.updateCount += 1;

        emit VerifierDeactivated(msg.sender, verifier.operatorId, reasonHash, evidenceURI);
    }

    function getVerifier(address verifier) external view returns (Verifier memory) {
        return _verifiers[verifier];
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
