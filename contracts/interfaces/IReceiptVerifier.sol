// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IReceiptVerifier {
    enum ReceiptStatus {
        Unknown,
        Submitted
    }

    struct ReceiptReport {
        address reporter;
        bytes32 observationId;
        bytes32 rootfieldId;
        bytes32 receiptCommitment;
        bytes32 reportHash;
        ReceiptStatus status;
        uint64 submittedAt;
    }

    event ReceiptReportSubmitted(
        bytes32 indexed reportId,
        address indexed reporter,
        bytes32 indexed observationId,
        bytes32 rootfieldId,
        bytes32 receiptCommitment,
        bytes32 reportHash,
        string evidenceURI
    );

    function submitReceiptReport(
        bytes32 reportId,
        bytes32 observationId,
        bytes32 rootfieldId,
        bytes32 receiptCommitment,
        bytes32 reportHash,
        string calldata evidenceURI
    ) external;

    function getReceiptReport(bytes32 reportId) external view returns (ReceiptReport memory);
}
