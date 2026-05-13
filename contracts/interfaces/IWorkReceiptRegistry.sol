// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IWorkReceiptRegistry {
    struct WorkReceipt {
        address worker;
        bytes32 rootfieldId;
        uint8 lane;
        bytes32 subject;
        bytes32 inputRoot;
        bytes32 outputRoot;
        bytes32 artifactCommitment;
        bytes32 parentReceiptId;
        uint64 submittedAt;
        bool exists;
    }

    event WorkerAuthorizationSet(address indexed worker, bool authorized);
    event WorkReceiptSubmitted(
        bytes32 indexed receiptId,
        address indexed worker,
        bytes32 indexed rootfieldId,
        uint8 lane,
        bytes32 subject,
        bytes32 inputRoot,
        bytes32 outputRoot,
        bytes32 artifactCommitment,
        bytes32 parentReceiptId,
        string evidenceURI
    );

    function setWorkerAuthorization(address worker, bool authorized) external;

    function submitWorkReceipt(
        bytes32 receiptId,
        bytes32 rootfieldId,
        uint8 lane,
        bytes32 subject,
        bytes32 inputRoot,
        bytes32 outputRoot,
        bytes32 artifactCommitment,
        bytes32 parentReceiptId,
        string calldata evidenceURI
    ) external;

    function isAuthorizedWorker(address worker) external view returns (bool);
    function getWorkReceipt(bytes32 receiptId) external view returns (WorkReceipt memory);
}
