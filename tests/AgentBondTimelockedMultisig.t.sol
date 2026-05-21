// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentBondTimelockedMultisig} from "../contracts/AgentBondTimelockedMultisig.sol";
import {TaskPolicyRegistry} from "../contracts/TaskPolicyRegistry.sol";

interface TimelockVm {
    function warp(uint256 newTimestamp) external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
}

contract MultisigOwnerActor {
    function queue(
        AgentBondTimelockedMultisig multisig,
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 salt,
        string calldata description
    ) external returns (bytes32) {
        return multisig.queueOperation(target, value, data, salt, description);
    }

    function approve(AgentBondTimelockedMultisig multisig, bytes32 operationId) external {
        multisig.approveOperation(operationId);
    }

    function execute(
        AgentBondTimelockedMultisig multisig,
        bytes32 operationId,
        address target,
        uint256 value,
        bytes calldata data
    ) external {
        multisig.executeOperation(operationId, target, value, data);
    }
}

contract AgentBondTimelockedMultisigTest {
    TimelockVm private constant vm = TimelockVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint64 private constant DELAY = 1 hours;

    AgentBondTimelockedMultisig private multisig;
    TaskPolicyRegistry private policyRegistry;
    MultisigOwnerActor private ownerOne;
    MultisigOwnerActor private ownerTwo;
    MultisigOwnerActor private ownerThree;
    bytes32 private policyId;

    error AssertionFailed();

    function setUp() public {
        ownerOne = new MultisigOwnerActor();
        ownerTwo = new MultisigOwnerActor();
        ownerThree = new MultisigOwnerActor();
        address[] memory owners = new address[](3);
        owners[0] = address(ownerOne);
        owners[1] = address(ownerTwo);
        owners[2] = address(ownerThree);
        multisig = new AgentBondTimelockedMultisig(owners, 2, DELAY);
        policyRegistry = new TaskPolicyRegistry(address(this));
        policyId = keccak256("agent-bonds.policy.timelock");
        policyRegistry.createPolicy(policyId, _policy());
    }

    function testMultisigAcceptsOwnershipAndExecutesTimelockedPolicyChange() public {
        policyRegistry.transferOwnership(address(multisig));
        bytes memory acceptOwnershipCall = abi.encodeWithSignature("acceptOwnership()");
        bytes32 acceptOperationId = ownerOne.queue(
            multisig,
            address(policyRegistry),
            0,
            acceptOwnershipCall,
            keccak256("accept-ownership"),
            "accept ownership"
        );
        ownerOne.approve(multisig, acceptOperationId);
        ownerTwo.approve(multisig, acceptOperationId);
        vm.warp(block.timestamp + DELAY + 1);
        ownerOne.execute(multisig, acceptOperationId, address(policyRegistry), 0, acceptOwnershipCall);
        _assertTrue(policyRegistry.owner() == address(multisig));

        bytes memory deactivateCall = abi.encodeWithSignature("setPolicyActive(bytes32,bool)", policyId, false);
        bytes32 deactivateOperationId = ownerOne.queue(
            multisig,
            address(policyRegistry),
            0,
            deactivateCall,
            keccak256("deactivate-policy"),
            "deactivate policy"
        );
        ownerOne.approve(multisig, deactivateOperationId);
        ownerThree.approve(multisig, deactivateOperationId);
        vm.warp(block.timestamp + DELAY + 1);
        ownerTwo.execute(multisig, deactivateOperationId, address(policyRegistry), 0, deactivateCall);
        _assertTrue(policyRegistry.isActive(policyId) == false);
    }

    function testCannotExecuteBeforeDelayOrWithoutThreshold() public {
        policyRegistry.transferOwnership(address(multisig));
        bytes memory call = abi.encodeWithSignature("acceptOwnership()");
        bytes32 operationId = ownerOne.queue(
            multisig,
            address(policyRegistry),
            0,
            call,
            keccak256("accept-too-early"),
            "accept ownership"
        );
        ownerOne.approve(multisig, operationId);

        vm.expectRevert(
            abi.encodeWithSelector(
                AgentBondTimelockedMultisig.InsufficientApprovals.selector,
                operationId,
                uint32(1),
                uint256(2)
            )
        );
        ownerOne.execute(multisig, operationId, address(policyRegistry), 0, call);

        ownerTwo.approve(multisig, operationId);
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentBondTimelockedMultisig.OperationNotReady.selector,
                operationId,
                uint64(block.timestamp + DELAY),
                uint64(block.timestamp)
            )
        );
        ownerOne.execute(multisig, operationId, address(policyRegistry), 0, call);
    }

    function _policy() private pure returns (TaskPolicyRegistry.TaskPolicy memory) {
        return TaskPolicyRegistry.TaskPolicy({
            agentBondBps: 1_000,
            verifierFeeBps: 200,
            requesterCancelBondBps: 500,
            disputeBondBps: 2_500,
            requiredConfirmations: 1,
            submissionWindow: 1 days,
            disputeWindow: 1 days,
            graceWindow: 1 hours,
            minAvailabilityWindow: 1 days,
            minAgentBond: 25 ether,
            minVerifierFee: 10 ether,
            minRequesterCancelBond: 25 ether,
            minDisputeBond: 50 ether,
            evidenceSchema: keccak256("flowmemory.task_bond_evidence.v1"),
            riskTier: 1,
            objectiveOnly: true,
            active: true
        });
    }

    function _assertTrue(bool condition) private pure {
        if (!condition) revert AssertionFailed();
    }
}
