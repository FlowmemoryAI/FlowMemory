// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVerifierReportRegistry} from "./interfaces/IVerifierReportRegistry.sol";

/// @title VerifierReportRegistry
/// @notice Minimal v0 registry for verifier report commitments.
/// @dev Uses an owner-controlled verifier allowlist. It does not implement
/// staking, slashing, rewards, or on-chain receipt verification.
contract VerifierReportRegistry is IVerifierReportRegistry {
    uint8 public constant VALID = 1;
    uint8 public constant INVALID = 2;
    uint8 public constant UNRESOLVED = 3;
    uint8 public constant UNSUPPORTED = 4;
    uint8 public constant REORGED = 5;

    address public immutable owner;

    mapping(address verifier => bool authorized) private _authorizedVerifiers;
    mapping(bytes32 reportId => VerifierReport report) private _reports;

    error NotOwner(address caller);
    error ZeroVerifier();
    error VerifierNotAuthorized(address verifier);
    error ZeroReportId();
    error ZeroReportTarget();
    error InvalidReportStatus(uint8 status);
    error ZeroReportDigest();
    error ZeroEvidenceCommitment();
    error VerifierReportAlreadySubmitted(bytes32 reportId);
    error TimestampOverflow(uint256 timestamp);

    constructor() {
        owner = msg.sender;
    }

    function setVerifierAuthorization(address verifier, bool authorized) external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (verifier == address(0)) revert ZeroVerifier();

        _authorizedVerifiers[verifier] = authorized;
        emit VerifierAuthorizationSet(verifier, authorized);
    }

    function submitVerifierReport(
        bytes32 reportId,
        bytes32 rootfieldId,
        bytes32 receiptId,
        uint8 status,
        bytes32 reportDigest,
        bytes32 evidenceCommitment,
        string calldata evidenceURI
    ) external {
        if (!_authorizedVerifiers[msg.sender]) revert VerifierNotAuthorized(msg.sender);
        if (reportId == bytes32(0)) revert ZeroReportId();
        if (rootfieldId == bytes32(0) && receiptId == bytes32(0)) revert ZeroReportTarget();
        if (!_isValidStatus(status)) revert InvalidReportStatus(status);
        if (reportDigest == bytes32(0)) revert ZeroReportDigest();
        if (evidenceCommitment == bytes32(0)) revert ZeroEvidenceCommitment();
        if (_reports[reportId].exists) revert VerifierReportAlreadySubmitted(reportId);

        _reports[reportId] = VerifierReport({
            verifier: msg.sender,
            rootfieldId: rootfieldId,
            receiptId: receiptId,
            status: status,
            reportDigest: reportDigest,
            evidenceCommitment: evidenceCommitment,
            submittedAt: _blockTimestamp(),
            exists: true
        });

        emit VerifierReportSubmitted(
            reportId, msg.sender, receiptId, rootfieldId, status, reportDigest, evidenceCommitment, evidenceURI
        );
    }

    function isAuthorizedVerifier(address verifier) external view returns (bool) {
        return _authorizedVerifiers[verifier];
    }

    function getVerifierReport(bytes32 reportId) external view returns (VerifierReport memory) {
        return _reports[reportId];
    }

    function _isValidStatus(uint8 status) private pure returns (bool) {
        return status >= VALID && status <= REORGED;
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
