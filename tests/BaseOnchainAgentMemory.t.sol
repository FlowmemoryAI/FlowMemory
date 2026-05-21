// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseOnchainAgentMemory} from "../contracts/BaseOnchainAgentMemory.sol";

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert() external;
}

contract MockTaskTarget {
    bytes32 public lastTaskId;
    address public lastCaller;
    string public lastUri;
    bool public shouldRevert;

    event Accepted(bytes32 indexed taskId, address indexed caller, string uri);

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function acceptTask(bytes32 taskId, string calldata uri) external payable {
        if (shouldRevert) {
            revert("mock-task-revert");
        }
        lastTaskId = taskId;
        lastCaller = msg.sender;
        lastUri = uri;
        emit Accepted(taskId, msg.sender, uri);
    }
}

contract BaseOnchainAgentMemoryTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FLOWPULSE_SIGNATURE =
        keccak256("FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)");

    BaseOnchainAgentMemory private agentMemory;
    MockTaskTarget private taskTarget;
    bytes32 private rootfieldId;
    bytes32 private policyRoot;
    bytes32 private toolAllowlistRoot;
    bytes32 private initialMemoryRoot;
    bytes32 private activeGoal;
    bytes32 private agentId;

    error AssertionFailed();

    function setUp() public {
        agentMemory = new BaseOnchainAgentMemory();
        taskTarget = new MockTaskTarget();
        rootfieldId = keccak256("rootfield.task-scout");
        policyRoot = keccak256("policy.conservative-v1");
        toolAllowlistRoot = keccak256("tools.accept-task-only");
        initialMemoryRoot = keccak256("memory.initial");
        activeGoal = keccak256("goal.low-risk-docs-review");
        agentId = _registerAgent();
        _setAcceptTaskTool(0, 10 ether, 5 ether, true);
    }

    function testRegisterAgentStoresInitialMemoryAndEmitsFlowPulse() public {
        BaseOnchainAgentMemory.AgentConfig memory agent = agentMemory.getAgent(agentId);
        BaseOnchainAgentMemory.HotMemory memory hot = agentMemory.getHotMemory(agentId);

        _assertTrue(agent.owner == address(this));
        _assertTrue(agent.rootfieldId == rootfieldId);
        _assertTrue(agent.policyRoot == policyRoot);
        _assertTrue(agent.latestMemoryRoot == initialMemoryRoot);
        _assertTrue(agent.sequence == 0);
        _assertTrue(agent.status == BaseOnchainAgentMemory.AgentStatus.Active);
        _assertTrue(hot.latestMemoryRoot == initialMemoryRoot);
        _assertTrue(hot.activeGoal == activeGoal);
        _assertTrue(hot.lastPulseId != bytes32(0));
    }

    function testPreviewAcceptsLowRiskDocsTask() public {
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, _openDocsTask());

        _assertTrue(preview.action == BaseOnchainAgentMemory.AgentAction.AcceptTask);
        _assertTrue(preview.toolId == agentMemory.ACCEPT_TASK_TOOL_ID());
        _assertTrue(preview.target == address(taskTarget));
        _assertTrue(preview.selector == agentMemory.ACCEPT_TASK_SELECTOR());
        _assertTrue(preview.reasonCode == agentMemory.REASON_TASK_KIND_ALLOWED());
        _assertTrue(preview.previewHash != bytes32(0));
        _assertTrue(preview.memoryDeltaRoot != bytes32(0));
    }

    function testStepExecutesAllowedTaskAndCommitsMemory() public {
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);

        vm.recordLogs();
        (bytes32 actionReceiptId, bytes32 newMemoryRoot) = agentMemory.step(agentId, observation, preview, "fixture://task/accept");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        _assertTrue(actionReceiptId != bytes32(0));
        _assertTrue(newMemoryRoot != initialMemoryRoot);
        _assertTrue(taskTarget.lastTaskId() == observation.taskId);
        _assertTrue(taskTarget.lastCaller() == address(agentMemory));

        BaseOnchainAgentMemory.HotMemory memory hot = agentMemory.getHotMemory(agentId);
        BaseOnchainAgentMemory.AgentConfig memory agent = agentMemory.getAgent(agentId);
        BaseOnchainAgentMemory.MemoryCommitment memory commitment = agentMemory.getMemoryCommitment(agentId, 1);
        _assertTrue(hot.latestMemoryRoot == newMemoryRoot);
        _assertTrue(agent.latestMemoryRoot == newMemoryRoot);
        _assertTrue(hot.sequence == 1);
        _assertTrue(agent.sequence == 1);
        _assertTrue(hot.lastActionReceiptId == actionReceiptId);
        _assertTrue(commitment.parentRoot == initialMemoryRoot);
        _assertTrue(commitment.newRoot == newMemoryRoot);
        _assertTrue(commitment.sourceReceiptRoot == actionReceiptId);
        _assertTrue(commitment.actionSucceeded);
        _assertTrue(_flowPulseCount(logs) == 2);
    }

    function testPreviewCommitMismatchReverts() public {
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);
        preview.previewHash = keccak256("wrong-preview");

        vm.expectRevert();
        agentMemory.step(agentId, observation, preview, "fixture://task/accept");
    }

    function testStaleSequenceReverts() public {
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);
        agentMemory.step(agentId, observation, preview, "fixture://task/accept");

        vm.expectRevert();
        agentMemory.step(agentId, observation, preview, "fixture://task/accept-again");
    }

    function testDisabledToolPreviewsNoopAndDoesNotCallTarget() public {
        _setAcceptTaskTool(0, 10 ether, 5 ether, false);
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);

        _assertTrue(preview.action == BaseOnchainAgentMemory.AgentAction.Noop);
        _assertTrue(preview.reasonCode == agentMemory.REASON_TOOL_NOT_ALLOWED());
        agentMemory.step(agentId, observation, preview, "fixture://noop");
        _assertTrue(taskTarget.lastTaskId() == bytes32(0));
    }

    function testNonPublicEvidenceEscalatesWithoutExternalCall() public {
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        observation.evidenceRequirement = keccak256("private-evidence");
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);

        _assertTrue(preview.action == BaseOnchainAgentMemory.AgentAction.Escalate);
        _assertTrue(preview.reasonCode == agentMemory.REASON_EVIDENCE_PUBLIC_REQUIRED());
        agentMemory.step(agentId, observation, preview, "fixture://escalate");
        _assertTrue(taskTarget.lastTaskId() == bytes32(0));
    }

    function testRewardCapEscalates() public {
        _setAcceptTaskTool(0, 10 ether, 100, true);
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        observation.rewardAmount = 101;
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);

        _assertTrue(preview.action == BaseOnchainAgentMemory.AgentAction.Escalate);
        _assertTrue(preview.reasonCode == agentMemory.REASON_CAP_EXCEEDED());
    }

    function testValueCapRejectsUnexpectedPayment() public {
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);

        vm.expectRevert();
        agentMemory.step{value: 1}(agentId, observation, preview, "fixture://value");
    }

    function testPausedAgentCannotMutate() public {
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);
        agentMemory.setAgentPaused(agentId, true, "fixture://pause");

        vm.expectRevert();
        agentMemory.step(agentId, observation, preview, "fixture://paused");
    }

    function testExternalFailureBecomesScarTissueMemory() public {
        taskTarget.setShouldRevert(true);
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);

        (bytes32 actionReceiptId,) = agentMemory.step(agentId, observation, preview, "fixture://task/fail");
        BaseOnchainAgentMemory.HotMemory memory hot = agentMemory.getHotMemory(agentId);
        BaseOnchainAgentMemory.MemoryCommitment memory commitment = agentMemory.getMemoryCommitment(agentId, 1);

        _assertTrue(actionReceiptId != bytes32(0));
        _assertTrue(hot.failureCount == 1);
        _assertTrue(!commitment.actionSucceeded);
        _assertTrue(commitment.memoryType == BaseOnchainAgentMemory.MemoryType.ScarTissue);
    }

    function testCorrectionAppendsNewRootAndReopensAgent() public {
        BaseOnchainAgentMemory.TaskObservation memory observation = _openDocsTask();
        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);
        agentMemory.step(agentId, observation, preview, "fixture://task/accept");
        agentMemory.setAgentPaused(agentId, true, "fixture://pause");

        bytes32 evidenceRoot = keccak256("correction.evidence");
        bytes32 correctedDeltaRoot = keccak256("correction.delta");
        (bytes32 correctionId, bytes32 correctedMemoryRoot) =
            agentMemory.correctMemory(agentId, 1, correctedDeltaRoot, evidenceRoot, "fixture://memory/correct");

        BaseOnchainAgentMemory.HotMemory memory hot = agentMemory.getHotMemory(agentId);
        BaseOnchainAgentMemory.AgentConfig memory agent = agentMemory.getAgent(agentId);
        BaseOnchainAgentMemory.MemoryCommitment memory correctionCommitment = agentMemory.getMemoryCommitment(agentId, 2);
        BaseOnchainAgentMemory.MemoryCorrection memory correction = agentMemory.getMemoryCorrection(correctionId);

        _assertTrue(correctionId != bytes32(0));
        _assertTrue(correction.accepted);
        _assertTrue(correction.targetSequence == 1);
        _assertTrue(correction.correctionSequence == 2);
        _assertTrue(correction.correctedMemoryRoot == correctedMemoryRoot);
        _assertTrue(correction.evidenceRoot == evidenceRoot);
        _assertTrue(hot.sequence == 2);
        _assertTrue(hot.latestMemoryRoot == correctedMemoryRoot);
        _assertTrue(agent.status == BaseOnchainAgentMemory.AgentStatus.Active);
        _assertTrue(correctionCommitment.newRoot == correctedMemoryRoot);
        _assertTrue(correctionCommitment.metadataCommitment == evidenceRoot);
        _assertTrue(correctionCommitment.memoryType == BaseOnchainAgentMemory.MemoryType.ScarTissue);
    }

    function testCorrectionRejectsUnknownTargetSequence() public {
        vm.expectRevert();
        agentMemory.correctMemory(agentId, 1, keccak256("correction.delta"), keccak256("correction.evidence"), "fixture://memory/correct");
    }

    function _registerAgent() private returns (bytes32) {
        return agentMemory.registerAgent({
            owner: address(this),
            rootfieldId: rootfieldId,
            policyRoot: policyRoot,
            toolAllowlistRoot: toolAllowlistRoot,
            initialMemoryRoot: initialMemoryRoot,
            activeGoal: activeGoal,
            autonomyLevel: 2,
            kernelClass: agentMemory.TASK_SCOUT_KERNEL_CLASS(),
            salt: keccak256("agent.task-scout.seed"),
            uri: "fixture://agent/register"
        });
    }

    function _setAcceptTaskTool(uint256 perActionValueCap, uint256 epochValueCap, uint256 maxTaskReward, bool enabled) private {
        agentMemory.setToolPolicy(
            agentId,
            agentMemory.ACCEPT_TASK_TOOL_ID(),
            BaseOnchainAgentMemory.ToolPolicy({
                target: address(taskTarget),
                selector: agentMemory.ACCEPT_TASK_SELECTOR(),
                perActionValueCap: perActionValueCap,
                epochValueCap: epochValueCap,
                maxTaskReward: maxTaskReward,
                enabled: enabled
            }),
            "fixture://tool/accept-task"
        );
    }

    function _openDocsTask() private view returns (BaseOnchainAgentMemory.TaskObservation memory) {
        return BaseOnchainAgentMemory.TaskObservation({
            taskId: keccak256("task.docs-review.1"),
            taskKind: agentMemory.DOCS_REVIEW_TASK_KIND(),
            evidenceRequirement: agentMemory.PUBLIC_EVIDENCE_REQUIREMENT(),
            rewardAmount: 1 ether,
            deadline: 1_800_000,
            taskStatus: 1,
            recentFailureCount: 0,
            humanReviewRequired: false
        });
    }

    function _flowPulseCount(Vm.Log[] memory logs) private pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i += 1) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == FLOWPULSE_SIGNATURE) {
                count += 1;
            }
        }
    }

    function _assertTrue(bool value) private pure {
        if (!value) revert AssertionFailed();
    }
}
