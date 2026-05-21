// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../../shared/TwoStepOwnable.sol";
import {SwarmTypes} from "../lib/SwarmTypes.sol";

contract SwarmPolicyRegistry is TwoStepOwnable {
    mapping(bytes32 policyId => SwarmTypes.SwarmPolicy policy) private _policies;
    mapping(bytes32 swarmClass => bool approved) public approvedSwarmClass;

    error ZeroPolicyId();
    error ZeroSwarmClass();
    error ZeroAdmissionPolicyRoot();
    error ZeroBudgetPolicyRoot();
    error ZeroRolePolicyRoot();
    error ZeroMaxMembers();
    error PolicyAlreadyRegistered(bytes32 policyId);
    error PolicyNotFound(bytes32 policyId);

    event SwarmPolicyRegistered(
        bytes32 indexed policyId,
        bytes32 indexed swarmClass,
        bytes32 admissionPolicyRoot,
        bytes32 budgetPolicyRoot,
        bytes32 rolePolicyRoot
    );
    event SwarmPolicyUpdated(bytes32 indexed policyId, bytes32 configRoot);
    event SwarmClassApproved(bytes32 indexed swarmClass, bool approved);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    function setSwarmClassApproved(bytes32 swarmClass, bool approved) external onlyOwner {
        if (swarmClass == bytes32(0)) revert ZeroSwarmClass();
        approvedSwarmClass[swarmClass] = approved;
        emit SwarmClassApproved(swarmClass, approved);
    }

    function registerPolicy(SwarmTypes.SwarmPolicy calldata policy) external onlyOwner {
        _validate(policy);
        if (_policies[policy.policyId].policyId != bytes32(0)) revert PolicyAlreadyRegistered(policy.policyId);
        _policies[policy.policyId] = policy;
        approvedSwarmClass[policy.swarmClass] = true;
        emit SwarmPolicyRegistered(policy.policyId, policy.swarmClass, policy.admissionPolicyRoot, policy.budgetPolicyRoot, policy.rolePolicyRoot);
    }

    function updatePolicy(bytes32 policyId, SwarmTypes.SwarmPolicy calldata policy) external onlyOwner {
        if (_policies[policyId].policyId == bytes32(0)) revert PolicyNotFound(policyId);
        if (policy.policyId != policyId) revert ZeroPolicyId();
        _validate(policy);
        _policies[policyId] = policy;
        approvedSwarmClass[policy.swarmClass] = true;
        emit SwarmPolicyUpdated(policyId, keccak256(abi.encode(policy)));
    }

    function getPolicy(bytes32 policyId) external view returns (SwarmTypes.SwarmPolicy memory) {
        SwarmTypes.SwarmPolicy memory policy = _policies[policyId];
        if (policy.policyId == bytes32(0)) revert PolicyNotFound(policyId);
        return policy;
    }

    function _validate(SwarmTypes.SwarmPolicy calldata policy) private pure {
        if (policy.policyId == bytes32(0)) revert ZeroPolicyId();
        if (policy.swarmClass == bytes32(0)) revert ZeroSwarmClass();
        if (policy.admissionPolicyRoot == bytes32(0)) revert ZeroAdmissionPolicyRoot();
        if (policy.budgetPolicyRoot == bytes32(0)) revert ZeroBudgetPolicyRoot();
        if (policy.rolePolicyRoot == bytes32(0)) revert ZeroRolePolicyRoot();
        if (policy.maxMembers == 0) revert ZeroMaxMembers();
    }
}
