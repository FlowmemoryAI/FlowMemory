// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseOnchainAgentMemory} from "../contracts/BaseOnchainAgentMemory.sol";
import {BaseAgentMemoryTaskTargetMock} from "../contracts/BaseAgentMemoryTaskTargetMock.sol";

interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// @title RunBaseAgentMemoryLocalE2E
/// @notice Local-chain broadcast script for actual deployed-log Base agent-memory e2e.
contract RunBaseAgentMemoryLocalE2E {
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant LOCAL_CHAIN_ID = 31337;

    error UnexpectedChain(uint256 expected, uint256 actual);

    struct Summary {
        address baseOnchainAgentMemory;
        address taskTarget;
        bytes32 agentId;
        bytes32 taskId;
        bytes32 actionReceiptId;
        bytes32 memoryRoot;
        bytes32 correctionId;
        bytes32 correctedMemoryRoot;
    }

    event BaseAgentMemoryLocalE2ERan(
        address indexed baseOnchainAgentMemory,
        address indexed taskTarget,
        bytes32 indexed agentId,
        bytes32 taskId,
        bytes32 actionReceiptId,
        bytes32 memoryRoot,
        bytes32 correctionId,
        bytes32 correctedMemoryRoot
    );

    function run() external returns (Summary memory summary) {
        if (block.chainid != LOCAL_CHAIN_ID) {
            revert UnexpectedChain(LOCAL_CHAIN_ID, block.chainid);
        }

        VM.startBroadcast();

        BaseOnchainAgentMemory agentMemory = new BaseOnchainAgentMemory();
        BaseAgentMemoryTaskTargetMock taskTarget = new BaseAgentMemoryTaskTargetMock();

        bytes32 rootfieldId = keccak256("rootfield.base-agent-memory.local-e2e");
        bytes32 policyRoot = keccak256("policy.base-agent-memory.local-e2e");
        bytes32 toolAllowlistRoot = keccak256("allowlist.base-agent-memory.local-e2e");
        bytes32 initialMemoryRoot = keccak256("memory.base-agent-memory.local-e2e.initial");
        bytes32 activeGoal = keccak256("goal.base-agent-memory.local-e2e.accept-low-risk-docs-review");
        bytes32 salt = keccak256("agent.base-agent-memory.local-e2e");

        bytes32 agentId = agentMemory.registerAgent(
            msg.sender,
            rootfieldId,
            policyRoot,
            toolAllowlistRoot,
            initialMemoryRoot,
            activeGoal,
            2,
            agentMemory.TASK_SCOUT_KERNEL_CLASS(),
            salt,
            "anvil://agent-memory/register"
        );

        agentMemory.setToolPolicy(
            agentId,
            agentMemory.ACCEPT_TASK_TOOL_ID(),
            BaseOnchainAgentMemory.ToolPolicy({
                target: address(taskTarget),
                selector: agentMemory.ACCEPT_TASK_SELECTOR(),
                perActionValueCap: 0,
                epochValueCap: 0,
                maxTaskReward: 5 ether,
                enabled: true
            }),
            "anvil://agent-memory/policy"
        );

        bytes32 taskId = keccak256("task.base-agent-memory.local-e2e.docs-review");
        BaseOnchainAgentMemory.TaskObservation memory observation = BaseOnchainAgentMemory.TaskObservation({
            taskId: taskId,
            taskKind: agentMemory.DOCS_REVIEW_TASK_KIND(),
            evidenceRequirement: agentMemory.PUBLIC_EVIDENCE_REQUIREMENT(),
            rewardAmount: 1 ether,
            deadline: 1_800_000,
            taskStatus: 1,
            recentFailureCount: 0,
            humanReviewRequired: false
        });

        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);
        (bytes32 actionReceiptId, bytes32 memoryRoot) = agentMemory.step(agentId, observation, preview, "anvil://agent-memory/step");

        agentMemory.setAgentPaused(agentId, true, "anvil://agent-memory/pause");
        (bytes32 correctionId, bytes32 correctedMemoryRoot) = agentMemory.correctMemory(
            agentId,
            1,
            keccak256("correction.base-agent-memory.local-e2e.delta"),
            keccak256("correction.base-agent-memory.local-e2e.evidence"),
            "anvil://agent-memory/correct"
        );

        VM.stopBroadcast();

        summary = Summary({
            baseOnchainAgentMemory: address(agentMemory),
            taskTarget: address(taskTarget),
            agentId: agentId,
            taskId: taskId,
            actionReceiptId: actionReceiptId,
            memoryRoot: memoryRoot,
            correctionId: correctionId,
            correctedMemoryRoot: correctedMemoryRoot
        });

        emit BaseAgentMemoryLocalE2ERan(
            summary.baseOnchainAgentMemory,
            summary.taskTarget,
            summary.agentId,
            summary.taskId,
            summary.actionReceiptId,
            summary.memoryRoot,
            summary.correctionId,
            summary.correctedMemoryRoot
        );
    }
}
