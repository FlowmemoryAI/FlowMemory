// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IReceiptVerifier} from "./interfaces/IReceiptVerifier.sol";

/// @title ReceiptVerifier
/// @notice Minimal v0 receipt-report commitment registry.
/// @dev This skeleton does not verify chain receipts cryptographically and does
/// not know txHash or logIndex during contract execution. It stores compact
/// commitments that off-chain verifiers can reconcile against receipts.
contract ReceiptVerifier is IReceiptVerifier {
    mapping(bytes32 reportId => ReceiptReport report) private _reports;

    error ZeroReportId();
    error ZeroObservationId();
    error ZeroReceiptCommitment();
    error ReceiptReportAlreadySubmitted(bytes32 reportId);
    error TimestampOverflow(uint256 timestamp);

    function submitReceiptReport(
        bytes32 reportId,
        bytes32 observationId,
        bytes32 rootfieldId,
        bytes32 receiptCommitment,
        bytes32 reportHash,
        string calldata evidenceURI
    ) external {
        if (reportId == bytes32(0)) revert ZeroReportId();
        if (observationId == bytes32(0)) revert ZeroObservationId();
        if (receiptCommitment == bytes32(0)) revert ZeroReceiptCommitment();
        if (_reports[reportId].status != ReceiptStatus.Unknown) revert ReceiptReportAlreadySubmitted(reportId);

        _reports[reportId] = ReceiptReport({
            reporter: msg.sender,
            observationId: observationId,
            rootfieldId: rootfieldId,
            receiptCommitment: receiptCommitment,
            reportHash: reportHash,
            status: ReceiptStatus.Submitted,
            submittedAt: _blockTimestamp()
        });

        emit ReceiptReportSubmitted(
            reportId, msg.sender, observationId, rootfieldId, receiptCommitment, reportHash, evidenceURI
        );
    }

    function getReceiptReport(bytes32 reportId) external view returns (ReceiptReport memory) {
        return _reports[reportId];
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
