// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "./shared/TwoStepOwnable.sol";

contract AgentCreditAttestationRegistry is TwoStepOwnable {
    struct CreditAttestation {
        uint16 score;
        uint8 riskBand;
        uint64 expiresAt;
        bytes32 scoreHash;
        address attester;
    }

    mapping(address attester => bool authorized) public isAuthorizedAttester;
    mapping(address agent => mapping(bytes32 scope => CreditAttestation)) private _latestAttestations;

    error ZeroAttester();
    error ZeroAgent();
    error ZeroScope();
    error InvalidRiskBand(uint8 riskBand);
    error InvalidExpiry(uint64 expiresAt, uint64 nowTime);
    error UnauthorizedAttester(address attester);

    event AuthorizedAttesterSet(address indexed attester, bool authorized);
    event CreditAttestationPublished(
        address indexed agent,
        bytes32 indexed scope,
        address indexed attester,
        uint16 score,
        uint8 riskBand,
        uint64 expiresAt,
        bytes32 scoreHash
    );

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    function setAuthorizedAttester(address attester, bool authorized) external onlyOwner {
        if (attester == address(0)) revert ZeroAttester();
        isAuthorizedAttester[attester] = authorized;
        emit AuthorizedAttesterSet(attester, authorized);
    }

    function publishAttestation(
        address agent,
        bytes32 scope,
        uint16 score,
        uint8 riskBand,
        uint64 expiresAt,
        bytes32 scoreHash
    ) external {
        if (agent == address(0)) revert ZeroAgent();
        if (scope == bytes32(0)) revert ZeroScope();
        if (riskBand > 5) revert InvalidRiskBand(riskBand);
        if (expiresAt <= _blockTimestamp()) revert InvalidExpiry(expiresAt, _blockTimestamp());
        if (!isAuthorizedAttester[msg.sender]) revert UnauthorizedAttester(msg.sender);

        _latestAttestations[agent][scope] = CreditAttestation({
            score: score,
            riskBand: riskBand,
            expiresAt: expiresAt,
            scoreHash: scoreHash,
            attester: msg.sender
        });

        emit CreditAttestationPublished(agent, scope, msg.sender, score, riskBand, expiresAt, scoreHash);
    }

    function getLatestAttestation(address agent, bytes32 scope) external view returns (CreditAttestation memory) {
        return _latestAttestations[agent][scope];
    }

    function isAttestationValid(address agent, bytes32 scope, uint16 minimumScore, uint8 maximumRiskBand)
        external
        view
        returns (bool)
    {
        CreditAttestation memory attestation = _latestAttestations[agent][scope];
        if (attestation.attester == address(0)) return false;
        if (!isAuthorizedAttester[attestation.attester]) return false;
        if (attestation.expiresAt <= _blockTimestamp()) return false;
        if (attestation.score < minimumScore) return false;
        if (attestation.riskBand > maximumRiskBand) return false;
        return true;
    }

    function _blockTimestamp() private view returns (uint64 now64) {
        now64 = uint64(block.timestamp);
    }
}
