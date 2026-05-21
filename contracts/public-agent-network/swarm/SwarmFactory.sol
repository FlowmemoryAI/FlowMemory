// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../../shared/TwoStepOwnable.sol";
import {ReentrancyGuard} from "../../shared/ReentrancyGuard.sol";
import {SwarmTypes} from "../lib/SwarmTypes.sol";
import {SwarmPolicyRegistry} from "./SwarmPolicyRegistry.sol";
import {SwarmRegistry} from "./SwarmRegistry.sol";
import {SwarmBudgetVault} from "./SwarmBudgetVault.sol";

contract SwarmFactory is TwoStepOwnable, ReentrancyGuard {
    SwarmPolicyRegistry public immutable policyRegistry;
    SwarmRegistry public immutable swarmRegistry;
    SwarmBudgetVault public immutable budgetVault;

    mapping(address creator => uint64 nonce) public nonces;
    mapping(bytes32 swarmIntentHash => bool consumed) public consumedSwarmIntent;

    error FactoryPaused();
    error InvalidIntentWindow(uint64 validAfter, uint64 validUntil);
    error SwarmIntentAlreadyConsumed(bytes32 swarmIntentHash);
    error SwarmClassNotApproved(bytes32 swarmClass);
    error SwarmPolicyNotActive(bytes32 policyId);
    error InvalidNonce(address creator, uint64 expected, uint64 provided);

    bool public paused;

    event PausedSet(bool paused);
    event SwarmIntentConsumed(bytes32 indexed swarmIntentHash, address indexed creator, bytes32 indexed swarmClass);
    event SwarmLaunched(
        bytes32 indexed swarmId,
        address indexed creator,
        bytes32 missionRoot,
        bytes32 sharedMemoryRoot,
        bytes32 policyRoot,
        bytes32 roleRoot,
        bytes32 profileDigest
    );

    constructor(address policyRegistry_, address swarmRegistry_, address budgetVault_, address initialOwner)
        TwoStepOwnable(initialOwner)
    {
        policyRegistry = SwarmPolicyRegistry(policyRegistry_);
        swarmRegistry = SwarmRegistry(swarmRegistry_);
        budgetVault = SwarmBudgetVault(budgetVault_);
    }

    modifier whenNotPaused() {
        if (paused) revert FactoryPaused();
        _;
    }

    function setPaused(bool value) external onlyOwner {
        paused = value;
        emit PausedSet(value);
    }

    function createSwarm(
        bytes32 policyId,
        SwarmTypes.SwarmIntent calldata intent,
        SwarmTypes.SwarmMember[] calldata initialMembers
    ) external nonReentrant whenNotPaused returns (bytes32 swarmId) {
        if (intent.validUntil <= intent.validAfter || uint64(block.timestamp) < intent.validAfter || uint64(block.timestamp) > intent.validUntil) {
            revert InvalidIntentWindow(intent.validAfter, intent.validUntil);
        }
        uint64 currentNonce = nonces[intent.creator];
        if (intent.nonce != currentNonce) revert InvalidNonce(intent.creator, currentNonce, intent.nonce);
        bytes32 swarmIntentHash = keccak256(abi.encode(intent));
        if (consumedSwarmIntent[swarmIntentHash]) revert SwarmIntentAlreadyConsumed(swarmIntentHash);

        SwarmTypes.SwarmPolicy memory policy = policyRegistry.getPolicy(policyId);
        if (!policy.active) revert SwarmPolicyNotActive(policyId);
        if (!policyRegistry.approvedSwarmClass(intent.swarmClass)) revert SwarmClassNotApproved(intent.swarmClass);

        consumedSwarmIntent[swarmIntentHash] = true;
        nonces[intent.creator] = currentNonce + 1;

        swarmId = keccak256(abi.encode(block.chainid, address(this), intent.creator, intent.swarmClass, intent.missionRoot, intent.sharedMemoryRoot, intent.nonce, intent.salt));
        SwarmTypes.Swarm memory swarm = SwarmTypes.Swarm({
            swarmId: swarmId,
            creator: intent.creator,
            swarmClass: intent.swarmClass,
            missionRoot: intent.missionRoot,
            sharedMemoryRoot: intent.sharedMemoryRoot,
            policyRoot: intent.policyRoot,
            roleRoot: intent.roleRoot,
            profileDigest: intent.profileDigest,
            status: SwarmTypes.SwarmStatus.Active,
            budgetVault: address(budgetVault),
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp),
            generation: 0,
            parentSwarmId: intent.parentSwarmId
        });
        swarmRegistry.createSwarm(swarm, initialMembers);
        if (intent.initialBudget != 0) {
            budgetVault.deposit(swarmId, intent.creator, intent.budgetAsset, intent.initialBudget);
        }

        emit SwarmIntentConsumed(swarmIntentHash, intent.creator, intent.swarmClass);
        emit SwarmLaunched(swarmId, intent.creator, intent.missionRoot, intent.sharedMemoryRoot, intent.policyRoot, intent.roleRoot, intent.profileDigest);
    }
}
