// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVerifierReportRegistry {
    struct VerifierReport {
        address verifier;
        bytes32 rootfieldId;
        bytes32 receiptId;
        uint8 status;
        bytes32 reportDigest;
        bytes32 evidenceCommitment;
        uint64 submittedAt;
        bool exists;
    }

    event VerifierAuthorizationSet(address indexed verifier, bool authorized);
    event VerifierReportSubmitted(
        bytes32 indexed reportId,
        address indexed verifier,
        bytes32 indexed receiptId,
        bytes32 rootfieldId,
        uint8 status,
        bytes32 reportDigest,
        bytes32 evidenceCommitment,
        string evidenceURI
    );

    function setVerifierAuthorization(address verifier, bool authorized) external;

    function submitVerifierReport(
        bytes32 reportId,
        bytes32 rootfieldId,
        bytes32 receiptId,
        uint8 status,
        bytes32 reportDigest,
        bytes32 evidenceCommitment,
        string calldata evidenceURI
    ) external;

    function isAuthorizedVerifier(address verifier) external view returns (bool);
    function getVerifierReport(bytes32 reportId) external view returns (VerifierReport memory);
}
