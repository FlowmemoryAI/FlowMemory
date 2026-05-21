// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "./shared/TwoStepOwnable.sol";

/// @title TaskPolicyRegistry
/// @notice Versioned objective task policy parameters for Agent Bonds v1 local/test and capped pilot flows.
contract TaskPolicyRegistry is TwoStepOwnable {
    struct TaskPolicy {
        uint16 agentBondBps;
        uint16 verifierFeeBps;
        uint16 requesterCancelBondBps;
        uint16 disputeBondBps;
        uint8 requiredConfirmations;
        uint64 submissionWindow;
        uint64 disputeWindow;
        uint64 graceWindow;
        uint64 minAvailabilityWindow;
        uint256 minAgentBond;
        uint256 minVerifierFee;
        uint256 minRequesterCancelBond;
        uint256 minDisputeBond;
        bytes32 evidenceSchema;
        uint8 riskTier;
        bool objectiveOnly;
        bool active;
    }

    mapping(bytes32 policyId => TaskPolicy policy) private _policies;

    error ZeroPolicyId();
    error ZeroEvidenceSchema();
    error PolicyAlreadyExists(bytes32 policyId);
    error PolicyNotFound(bytes32 policyId);
    error InvalidBps(uint16 bps);
    error InvalidWindow();
    error NonObjectivePolicy();

    event TaskPolicyConfigured(
        bytes32 indexed policyId,
        uint16 agentBondBps,
        uint16 verifierFeeBps,
        uint16 requesterCancelBondBps,
        uint16 disputeBondBps,
        uint8 requiredConfirmations,
        uint64 submissionWindow,
        uint64 disputeWindow,
        uint64 graceWindow,
        uint64 minAvailabilityWindow,
        bytes32 evidenceSchema,
        uint8 riskTier
    );
    event TaskPolicyActiveSet(bytes32 indexed policyId, bool active);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    function createPolicy(bytes32 policyId, TaskPolicy calldata policy) external onlyOwner {
        if (policyId == bytes32(0)) revert ZeroPolicyId();
        if (_policies[policyId].evidenceSchema != bytes32(0)) revert PolicyAlreadyExists(policyId);
        _validatePolicy(policy);
        _policies[policyId] = policy;
        emit TaskPolicyConfigured(
            policyId,
            policy.agentBondBps,
            policy.verifierFeeBps,
            policy.requesterCancelBondBps,
            policy.disputeBondBps,
            policy.requiredConfirmations,
            policy.submissionWindow,
            policy.disputeWindow,
            policy.graceWindow,
            policy.minAvailabilityWindow,
            policy.evidenceSchema,
            policy.riskTier
        );
        emit TaskPolicyActiveSet(policyId, policy.active);
    }

    function setPolicyActive(bytes32 policyId, bool active) external onlyOwner {
        TaskPolicy storage policy = _policies[policyId];
        if (policy.evidenceSchema == bytes32(0)) revert PolicyNotFound(policyId);
        policy.active = active;
        emit TaskPolicyActiveSet(policyId, active);
    }

    function getPolicy(bytes32 policyId) external view returns (TaskPolicy memory) {
        TaskPolicy memory policy = _policies[policyId];
        if (policy.evidenceSchema == bytes32(0)) revert PolicyNotFound(policyId);
        return policy;
    }

    function isActive(bytes32 policyId) external view returns (bool) {
        return _policies[policyId].active;
    }

    function quote(bytes32 policyId, uint256 payout)
        external
        view
        returns (uint256 agentBond, uint256 verifierFee, uint256 requesterCancelBond, uint256 disputeBond)
    {
        TaskPolicy memory policy = _policies[policyId];
        if (policy.evidenceSchema == bytes32(0)) revert PolicyNotFound(policyId);
        agentBond = _max(policy.minAgentBond, payout * policy.agentBondBps / 10_000);
        verifierFee = _max(policy.minVerifierFee, payout * policy.verifierFeeBps / 10_000);
        requesterCancelBond = _max(policy.minRequesterCancelBond, payout * policy.requesterCancelBondBps / 10_000);
        disputeBond = _max(policy.minDisputeBond, agentBond * policy.disputeBondBps / 10_000);
    }

    function _validatePolicy(TaskPolicy calldata policy) private pure {
        _validateBps(policy.agentBondBps);
        _validateBps(policy.verifierFeeBps);
        _validateBps(policy.requesterCancelBondBps);
        _validateBps(policy.disputeBondBps);
        if (policy.submissionWindow == 0 || policy.disputeWindow == 0 || policy.minAvailabilityWindow == 0) {
            revert InvalidWindow();
        }
        if (policy.evidenceSchema == bytes32(0)) revert ZeroEvidenceSchema();
        if (!policy.objectiveOnly) revert NonObjectivePolicy();
    }

    function _validateBps(uint16 bps) private pure {
        if (bps > 10_000) revert InvalidBps(bps);
    }

    function _max(uint256 left, uint256 right) private pure returns (uint256) {
        return left > right ? left : right;
    }
}
