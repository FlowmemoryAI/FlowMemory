// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFlowPulse, FlowPulseTypes} from "./FlowPulse.sol";

/// @title BaseOnchainAgentMemory
/// @notice Local/test implementation of a bounded Base-native agent memory loop.
/// @dev The contract keeps compact public state only. It emits FlowPulse events
/// without receipt-only metadata; indexers derive txHash and logIndex after execution.
contract BaseOnchainAgentMemory is IFlowPulse {
    bytes32 public constant AGENT_MEMORY_SCHEMA_ID = keccak256("flowmemory.base_onchain_agent_memory.v1");
    bytes32 public constant TASK_SCOUT_KERNEL_CLASS = keccak256("flowmemory.kernel.task_scout.rule_scoring.v1");
    bytes32 public constant ACCEPT_TASK_TOOL_ID = keccak256("flowmemory.tool.accept_task.v1");
    bytes32 public constant PUBLIC_EVIDENCE_REQUIREMENT = keccak256("flowmemory.evidence.public.v1");
    bytes32 public constant DOCS_REVIEW_TASK_KIND = keccak256("flowmemory.task_kind.docs_review.v1");

    bytes4 public constant ACCEPT_TASK_SELECTOR = bytes4(keccak256("acceptTask(bytes32,string)"));

    uint64 public constant REASON_SAFE_NOOP = 1;
    uint64 public constant REASON_TASK_KIND_ALLOWED = 2;
    uint64 public constant REASON_TASK_KIND_UNSUPPORTED = 3;
    uint64 public constant REASON_EVIDENCE_PUBLIC_REQUIRED = 4;
    uint64 public constant REASON_RECENT_FAILURE = 5;
    uint64 public constant REASON_HUMAN_REVIEW_REQUIRED = 6;
    uint64 public constant REASON_CAP_EXCEEDED = 7;
    uint64 public constant REASON_TOOL_NOT_ALLOWED = 8;

    enum AgentStatus {
        Unknown,
        Active,
        Paused,
        Finalized,
        Failed
    }

    enum AgentAction {
        Noop,
        Escalate,
        AcceptTask,
        RejectTask,
        CommitEvidence,
        UpdateMemoryOnly,
        PauseSelf
    }

    enum MemoryType {
        Unknown,
        Episodic,
        Semantic,
        Procedural,
        Goal,
        ScarTissue,
        SelfModel
    }

    struct AgentConfig {
        address owner;
        bytes32 rootfieldId;
        address kernel;
        bytes32 policyRoot;
        bytes32 toolAllowlistRoot;
        bytes32 latestMemoryRoot;
        bytes32 kernelClass;
        uint64 sequence;
        uint64 autonomyLevel;
        AgentStatus status;
    }

    struct HotMemory {
        bytes32 latestMemoryRoot;
        bytes32 activeGoal;
        bytes32 lastActionReceiptId;
        bytes32 lastVerifierReportId;
        bytes32 lastPulseId;
        uint64 sequence;
        uint64 failureCount;
        uint256 spendUsedThisEpoch;
    }

    struct ToolPolicy {
        address target;
        bytes4 selector;
        uint256 perActionValueCap;
        uint256 epochValueCap;
        uint256 maxTaskReward;
        bool enabled;
    }

    struct TaskObservation {
        bytes32 taskId;
        bytes32 taskKind;
        bytes32 evidenceRequirement;
        uint256 rewardAmount;
        uint64 deadline;
        uint8 taskStatus;
        uint64 recentFailureCount;
        bool humanReviewRequired;
    }

    struct StepPreview {
        AgentAction action;
        bytes32 toolId;
        address target;
        bytes4 selector;
        bytes32 callDataHash;
        bytes32 observationRoot;
        bytes32 memoryDeltaRoot;
        bytes32 previewHash;
        uint64 sequence;
        uint64 reasonCode;
        uint256 maxValue;
    }

    struct MemoryCommitment {
        bytes32 parentRoot;
        bytes32 deltaRoot;
        bytes32 newRoot;
        bytes32 sourceReceiptRoot;
        bytes32 metadataCommitment;
        uint64 sequence;
        MemoryType memoryType;
        bool actionSucceeded;
    }

    struct MemoryCorrection {
        bytes32 targetMemoryRoot;
        bytes32 correctedMemoryRoot;
        bytes32 evidenceRoot;
        uint64 targetSequence;
        uint64 correctionSequence;
        bool accepted;
    }

    mapping(bytes32 agentId => AgentConfig agent) private _agents;
    mapping(bytes32 agentId => HotMemory hotMemory) private _hotMemory;
    mapping(bytes32 agentId => mapping(bytes32 toolId => ToolPolicy policy)) private _toolPolicies;
    mapping(bytes32 rootfieldId => uint64 pulseCount) private _pulseCounts;
    mapping(bytes32 agentId => mapping(uint64 sequence => MemoryCommitment commitment)) private _memoryCommitments;
    mapping(bytes32 correctionId => MemoryCorrection correction) private _memoryCorrections;

    error ZeroAgentOwner();
    error ZeroRootfieldId();
    error ZeroPolicyRoot();
    error ZeroToolAllowlistRoot();
    error ZeroMemoryRoot();
    error ZeroKernelClass();
    error ZeroToolId();
    error ZeroToolTarget();
    error ZeroToolSelector();
    error AgentAlreadyRegistered(bytes32 agentId);
    error AgentNotRegistered(bytes32 agentId);
    error NotAgentOwner(bytes32 agentId, address caller);
    error AgentNotActive(bytes32 agentId, AgentStatus status);
    error PreviewMismatch(bytes32 expectedPreviewHash, bytes32 actualPreviewHash);
    error SequenceMismatch(uint64 expected, uint64 actual);
    error ToolNotAllowed(bytes32 agentId, bytes32 toolId);
    error CapExceeded(uint256 attempted, uint256 cap);
    error TimestampOverflow(uint256 timestamp);
    error ZeroEvidenceRoot();
    error InvalidCorrectionTarget(bytes32 agentId, uint64 targetSequence);
    error ZeroCorrectionDeltaRoot();

    event AgentRegistered(
        bytes32 indexed agentId,
        bytes32 indexed rootfieldId,
        address indexed owner,
        bytes32 policyRoot,
        bytes32 toolAllowlistRoot,
        bytes32 initialMemoryRoot,
        bytes32 kernelClass,
        string uri
    );
    event AgentToolPolicySet(
        bytes32 indexed agentId,
        bytes32 indexed toolId,
        address indexed target,
        bytes4 selector,
        uint256 perActionValueCap,
        uint256 epochValueCap,
        uint256 maxTaskReward,
        bool enabled
    );
    event AgentStatusSet(bytes32 indexed agentId, AgentStatus status, string uri);
    event AgentStepCommitted(
        bytes32 indexed agentId,
        bytes32 indexed actionReceiptId,
        bytes32 indexed observationRoot,
        AgentAction action,
        bool actionSucceeded,
        uint64 sequence,
        uint64 reasonCode,
        bytes32 newMemoryRoot
    );
    event AgentMemoryCommitted(
        bytes32 indexed agentId,
        bytes32 indexed newMemoryRoot,
        bytes32 indexed actionReceiptId,
        bytes32 parentRoot,
        bytes32 deltaRoot,
        MemoryType memoryType,
        uint64 sequence
    );
    event AgentMemoryCorrected(
        bytes32 indexed agentId,
        bytes32 indexed correctionId,
        bytes32 indexed previousRoot,
        bytes32 correctedMemoryRoot,
        bytes32 evidenceRoot,
        uint64 targetSequence,
        uint64 correctionSequence,
        string uri
    );

    function registerAgent(
        address owner,
        bytes32 rootfieldId,
        bytes32 policyRoot,
        bytes32 toolAllowlistRoot,
        bytes32 initialMemoryRoot,
        bytes32 activeGoal,
        uint64 autonomyLevel,
        bytes32 kernelClass,
        bytes32 salt,
        string calldata uri
    ) external returns (bytes32 agentId) {
        if (owner == address(0)) revert ZeroAgentOwner();
        if (rootfieldId == bytes32(0)) revert ZeroRootfieldId();
        if (policyRoot == bytes32(0)) revert ZeroPolicyRoot();
        if (toolAllowlistRoot == bytes32(0)) revert ZeroToolAllowlistRoot();
        if (initialMemoryRoot == bytes32(0)) revert ZeroMemoryRoot();
        if (kernelClass == bytes32(0)) revert ZeroKernelClass();

        agentId = keccak256(
            abi.encode(
                AGENT_MEMORY_SCHEMA_ID,
                block.chainid,
                address(this),
                owner,
                rootfieldId,
                policyRoot,
                toolAllowlistRoot,
                initialMemoryRoot,
                kernelClass,
                salt
            )
        );
        if (_agents[agentId].owner != address(0)) revert AgentAlreadyRegistered(agentId);

        _agents[agentId] = AgentConfig({
            owner: owner,
            rootfieldId: rootfieldId,
            kernel: address(this),
            policyRoot: policyRoot,
            toolAllowlistRoot: toolAllowlistRoot,
            latestMemoryRoot: initialMemoryRoot,
            kernelClass: kernelClass,
            sequence: 0,
            autonomyLevel: autonomyLevel,
            status: AgentStatus.Active
        });
        _hotMemory[agentId] = HotMemory({
            latestMemoryRoot: initialMemoryRoot,
            activeGoal: activeGoal,
            lastActionReceiptId: bytes32(0),
            lastVerifierReportId: bytes32(0),
            lastPulseId: bytes32(0),
            sequence: 0,
            failureCount: 0,
            spendUsedThisEpoch: 0
        });

        bytes32 pulseId = _emitAgentPulse({
            rootfieldId: rootfieldId,
            actor: owner,
            pulseType: FlowPulseTypes.AGENT_REGISTERED,
            subject: agentId,
            commitment: keccak256(abi.encode(policyRoot, toolAllowlistRoot, initialMemoryRoot, kernelClass)),
            parentPulseId: bytes32(0),
            uri: uri
        });
        _hotMemory[agentId].lastPulseId = pulseId;

        emit AgentRegistered(agentId, rootfieldId, owner, policyRoot, toolAllowlistRoot, initialMemoryRoot, kernelClass, uri);
    }

    function setToolPolicy(bytes32 agentId, bytes32 toolId, ToolPolicy calldata policy, string calldata uri) external {
        AgentConfig storage agent = _requireAgentOwner(agentId);
        if (toolId == bytes32(0)) revert ZeroToolId();
        if (policy.enabled) {
            if (policy.target == address(0)) revert ZeroToolTarget();
            if (policy.selector == bytes4(0)) revert ZeroToolSelector();
        }

        _toolPolicies[agentId][toolId] = policy;
        agent.toolAllowlistRoot = keccak256(
            abi.encode(agent.toolAllowlistRoot, toolId, policy.target, policy.selector, policy.perActionValueCap, policy.epochValueCap, policy.maxTaskReward, policy.enabled)
        );

        bytes32 pulseId = _emitAgentPulse({
            rootfieldId: agent.rootfieldId,
            actor: msg.sender,
            pulseType: FlowPulseTypes.AGENT_POLICY_UPDATED,
            subject: agentId,
            commitment: agent.toolAllowlistRoot,
            parentPulseId: _hotMemory[agentId].lastPulseId,
            uri: uri
        });
        _hotMemory[agentId].lastPulseId = pulseId;

        emit AgentToolPolicySet(agentId, toolId, policy.target, policy.selector, policy.perActionValueCap, policy.epochValueCap, policy.maxTaskReward, policy.enabled);
    }

    function setAgentPaused(bytes32 agentId, bool paused, string calldata uri) external {
        AgentConfig storage agent = _requireAgentOwner(agentId);
        agent.status = paused ? AgentStatus.Paused : AgentStatus.Active;
        bytes32 pulseId = _emitAgentPulse({
            rootfieldId: agent.rootfieldId,
            actor: msg.sender,
            pulseType: FlowPulseTypes.AGENT_PAUSED,
            subject: agentId,
            commitment: keccak256(abi.encode(agentId, paused)),
            parentPulseId: _hotMemory[agentId].lastPulseId,
            uri: uri
        });
        _hotMemory[agentId].lastPulseId = pulseId;
        emit AgentStatusSet(agentId, agent.status, uri);
    }

    function getAgent(bytes32 agentId) external view returns (AgentConfig memory) {
        return _agents[agentId];
    }

    function getHotMemory(bytes32 agentId) external view returns (HotMemory memory) {
        return _hotMemory[agentId];
    }

    function getToolPolicy(bytes32 agentId, bytes32 toolId) external view returns (ToolPolicy memory) {
        return _toolPolicies[agentId][toolId];
    }

    function getMemoryCommitment(bytes32 agentId, uint64 sequence) external view returns (MemoryCommitment memory) {
        return _memoryCommitments[agentId][sequence];
    }

    function getMemoryCorrection(bytes32 correctionId) external view returns (MemoryCorrection memory) {
        return _memoryCorrections[correctionId];
    }

    function observationRoot(TaskObservation calldata observation) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                AGENT_MEMORY_SCHEMA_ID,
                "task_observation",
                observation.taskId,
                observation.taskKind,
                observation.evidenceRequirement,
                observation.rewardAmount,
                observation.deadline,
                observation.taskStatus,
                observation.recentFailureCount,
                observation.humanReviewRequired
            )
        );
    }

    function previewStep(bytes32 agentId, TaskObservation calldata observation) public view returns (StepPreview memory preview) {
        AgentConfig storage agent = _requireAgent(agentId);
        HotMemory storage hot = _hotMemory[agentId];
        bytes32 obsRoot = observationRoot(observation);
        ToolPolicy storage acceptPolicy = _toolPolicies[agentId][ACCEPT_TASK_TOOL_ID];

        AgentAction action = AgentAction.Noop;
        bytes32 toolId = bytes32(0);
        address target = address(0);
        bytes4 selector = bytes4(0);
        bytes32 callDataHash = bytes32(0);
        uint64 reasonCode = REASON_SAFE_NOOP;
        uint256 maxValue = 0;

        if (agent.status != AgentStatus.Active || observation.taskId == bytes32(0) || observation.taskStatus != 1) {
            reasonCode = REASON_SAFE_NOOP;
        } else if (observation.humanReviewRequired) {
            action = AgentAction.Escalate;
            reasonCode = REASON_HUMAN_REVIEW_REQUIRED;
        } else if (observation.evidenceRequirement != PUBLIC_EVIDENCE_REQUIREMENT) {
            action = AgentAction.Escalate;
            reasonCode = REASON_EVIDENCE_PUBLIC_REQUIRED;
        } else if (hot.failureCount + observation.recentFailureCount >= 3) {
            action = AgentAction.RejectTask;
            reasonCode = REASON_RECENT_FAILURE;
        } else if (!acceptPolicy.enabled || acceptPolicy.target == address(0) || acceptPolicy.selector != ACCEPT_TASK_SELECTOR) {
            action = AgentAction.Noop;
            reasonCode = REASON_TOOL_NOT_ALLOWED;
        } else if (acceptPolicy.maxTaskReward != 0 && observation.rewardAmount > acceptPolicy.maxTaskReward) {
            action = AgentAction.Escalate;
            reasonCode = REASON_CAP_EXCEEDED;
        } else if (observation.taskKind != DOCS_REVIEW_TASK_KIND) {
            action = AgentAction.RejectTask;
            reasonCode = REASON_TASK_KIND_UNSUPPORTED;
        } else {
            action = AgentAction.AcceptTask;
            toolId = ACCEPT_TASK_TOOL_ID;
            target = acceptPolicy.target;
            selector = acceptPolicy.selector;
            callDataHash = keccak256(abi.encodeWithSelector(selector, observation.taskId, ""));
            reasonCode = REASON_TASK_KIND_ALLOWED;
            maxValue = acceptPolicy.perActionValueCap;
        }

        bytes32 deltaRoot = _memoryDeltaRoot({
            agentId: agentId,
            sequence: hot.sequence + 1,
            parentRoot: hot.latestMemoryRoot,
            observationRoot_: obsRoot,
            action: action,
            reasonCode: reasonCode
        });

        preview = StepPreview({
            action: action,
            toolId: toolId,
            target: target,
            selector: selector,
            callDataHash: callDataHash,
            observationRoot: obsRoot,
            memoryDeltaRoot: deltaRoot,
            previewHash: bytes32(0),
            sequence: hot.sequence,
            reasonCode: reasonCode,
            maxValue: maxValue
        });
        preview.previewHash = _previewHash(agentId, preview);
    }

    function step(bytes32 agentId, TaskObservation calldata observation, StepPreview calldata expectedPreview, string calldata uri)
        external
        payable
        returns (bytes32 actionReceiptId, bytes32 newMemoryRoot)
    {
        AgentConfig storage agent = _requireAgent(agentId);
        if (agent.status != AgentStatus.Active) revert AgentNotActive(agentId, agent.status);

        HotMemory storage hot = _hotMemory[agentId];
        StepPreview memory actualPreview = _validatedPreview(agentId, observation, expectedPreview, hot.sequence);
        bool actionSucceeded = _executePreviewedAction(agentId, observation.taskId, actualPreview, hot.spendUsedThisEpoch, uri);

        uint64 nextSequence = hot.sequence + 1;
        bytes32 parentRoot = hot.latestMemoryRoot;
        actionReceiptId = _actionReceiptId(agentId, nextSequence, actualPreview, actionSucceeded);
        newMemoryRoot = _newMemoryRoot(agentId, nextSequence, parentRoot, actualPreview.memoryDeltaRoot, actionReceiptId, actionSucceeded);

        _commitStepMemory({
            agentId: agentId,
            agent: agent,
            hot: hot,
            parentRoot: parentRoot,
            preview: actualPreview,
            actionReceiptId: actionReceiptId,
            newMemoryRoot: newMemoryRoot,
            nextSequence: nextSequence,
            actionSucceeded: actionSucceeded,
            valueSpent: msg.value
        });

        _emitStepOutput({
            agentId: agentId,
            rootfieldId: agent.rootfieldId,
            parentPulseId: hot.lastPulseId,
            actionReceiptId: actionReceiptId,
            preview: actualPreview,
            actionSucceeded: actionSucceeded,
            nextSequence: nextSequence,
            parentRoot: parentRoot,
            newMemoryRoot: newMemoryRoot,
            uri: uri
        });
    }

    function correctMemory(
        bytes32 agentId,
        uint64 targetSequence,
        bytes32 correctedDeltaRoot,
        bytes32 evidenceRoot,
        string calldata uri
    ) external returns (bytes32 correctionId, bytes32 correctedMemoryRoot) {
        AgentConfig storage agent = _requireAgentOwner(agentId);
        if (evidenceRoot == bytes32(0)) revert ZeroEvidenceRoot();
        if (correctedDeltaRoot == bytes32(0)) revert ZeroCorrectionDeltaRoot();

        MemoryCommitment storage targetCommitment = _memoryCommitments[agentId][targetSequence];
        if (targetSequence == 0 || targetCommitment.sequence != targetSequence || targetCommitment.newRoot == bytes32(0)) {
            revert InvalidCorrectionTarget(agentId, targetSequence);
        }

        HotMemory storage hot = _hotMemory[agentId];
        uint64 correctionSequence = hot.sequence + 1;
        bytes32 parentRoot = hot.latestMemoryRoot;
        correctedMemoryRoot = _newMemoryRoot(
            agentId,
            correctionSequence,
            parentRoot,
            correctedDeltaRoot,
            targetCommitment.sourceReceiptRoot,
            true
        );
        correctionId = keccak256(
            abi.encode(
                AGENT_MEMORY_SCHEMA_ID,
                "memory_correction",
                block.chainid,
                address(this),
                agentId,
                targetSequence,
                correctionSequence,
                evidenceRoot,
                correctedMemoryRoot
            )
        );
        _memoryCorrections[correctionId] = MemoryCorrection({
            targetMemoryRoot: targetCommitment.newRoot,
            correctedMemoryRoot: correctedMemoryRoot,
            evidenceRoot: evidenceRoot,
            targetSequence: targetSequence,
            correctionSequence: correctionSequence,
            accepted: true
        });
        _memoryCommitments[agentId][correctionSequence] = MemoryCommitment({
            parentRoot: parentRoot,
            deltaRoot: correctedDeltaRoot,
            newRoot: correctedMemoryRoot,
            sourceReceiptRoot: targetCommitment.sourceReceiptRoot,
            metadataCommitment: evidenceRoot,
            sequence: correctionSequence,
            memoryType: MemoryType.ScarTissue,
            actionSucceeded: true
        });

        bytes32 previousPulseId = hot.lastPulseId;
        hot.latestMemoryRoot = correctedMemoryRoot;
        hot.sequence = correctionSequence;
        agent.latestMemoryRoot = correctedMemoryRoot;
        agent.sequence = correctionSequence;
        agent.status = AgentStatus.Active;

        bytes32 correctionCommitment = keccak256(
            abi.encode(targetCommitment.newRoot, correctedDeltaRoot, correctedMemoryRoot, evidenceRoot, targetSequence)
        );
        bytes32 correctionPulseId = _emitAgentPulse({
            rootfieldId: agent.rootfieldId,
            actor: msg.sender,
            pulseType: FlowPulseTypes.AGENT_MEMORY_CORRECTED,
            subject: correctedMemoryRoot,
            commitment: correctionCommitment,
            parentPulseId: previousPulseId,
            uri: uri
        });
        hot.lastPulseId = correctionPulseId;

        emit AgentMemoryCorrected(
            agentId,
            correctionId,
            parentRoot,
            correctedMemoryRoot,
            evidenceRoot,
            targetSequence,
            correctionSequence,
            uri
        );
    }

    function _requireAgent(bytes32 agentId) private view returns (AgentConfig storage agent) {
        agent = _agents[agentId];
        if (agent.owner == address(0)) revert AgentNotRegistered(agentId);
    }

    function _requireAgentOwner(bytes32 agentId) private view returns (AgentConfig storage agent) {
        agent = _requireAgent(agentId);
        if (agent.owner != msg.sender) revert NotAgentOwner(agentId, msg.sender);
    }

    function _requireAllowedTool(
        bytes32 agentId,
        bytes32 toolId,
        ToolPolicy storage policy,
        uint256 value,
        uint256 spent
    ) private view {
        if (!policy.enabled || policy.target == address(0) || policy.selector != ACCEPT_TASK_SELECTOR) {
            revert ToolNotAllowed(agentId, toolId);
        }
        if (value > policy.perActionValueCap) revert CapExceeded(value, policy.perActionValueCap);
        uint256 attempted = spent + value;
        if (policy.epochValueCap != 0 && attempted > policy.epochValueCap) revert CapExceeded(attempted, policy.epochValueCap);
    }

    function _validatedPreview(
        bytes32 agentId,
        TaskObservation calldata observation,
        StepPreview calldata expectedPreview,
        uint64 currentSequence
    ) private view returns (StepPreview memory actualPreview) {
        actualPreview = previewStep(agentId, observation);
        if (expectedPreview.sequence != currentSequence) revert SequenceMismatch(expectedPreview.sequence, currentSequence);
        if (expectedPreview.previewHash != actualPreview.previewHash) {
            revert PreviewMismatch(expectedPreview.previewHash, actualPreview.previewHash);
        }
        if (msg.value > actualPreview.maxValue) revert CapExceeded(msg.value, actualPreview.maxValue);
    }

    function _executePreviewedAction(
        bytes32 agentId,
        bytes32 taskId,
        StepPreview memory actualPreview,
        uint256 spent,
        string calldata uri
    ) private returns (bool actionSucceeded) {
        actionSucceeded = true;
        if (actualPreview.action == AgentAction.AcceptTask) {
            ToolPolicy storage policy = _toolPolicies[agentId][actualPreview.toolId];
            _requireAllowedTool(agentId, actualPreview.toolId, policy, msg.value, spent);
            (actionSucceeded,) = policy.target.call{value: msg.value}(abi.encodeWithSelector(policy.selector, taskId, uri));
        } else if (msg.value != 0) {
            revert CapExceeded(msg.value, 0);
        }
    }

    function _actionReceiptId(bytes32 agentId, uint64 sequence, StepPreview memory preview, bool actionSucceeded)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                AGENT_MEMORY_SCHEMA_ID,
                "action_receipt",
                block.chainid,
                address(this),
                agentId,
                sequence,
                preview.previewHash,
                preview.action,
                actionSucceeded
            )
        );
    }

    function _newMemoryRoot(
        bytes32 agentId,
        uint64 sequence,
        bytes32 parentRoot,
        bytes32 deltaRoot,
        bytes32 actionReceiptId,
        bool actionSucceeded
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                AGENT_MEMORY_SCHEMA_ID,
                "memory_root",
                block.chainid,
                address(this),
                agentId,
                parentRoot,
                deltaRoot,
                actionReceiptId,
                actionSucceeded,
                sequence
            )
        );
    }

    function _commitStepMemory(
        bytes32 agentId,
        AgentConfig storage agent,
        HotMemory storage hot,
        bytes32 parentRoot,
        StepPreview memory preview,
        bytes32 actionReceiptId,
        bytes32 newMemoryRoot,
        uint64 nextSequence,
        bool actionSucceeded,
        uint256 valueSpent
    ) private {
        MemoryType memoryType = actionSucceeded ? MemoryType.Episodic : MemoryType.ScarTissue;
        _memoryCommitments[agentId][nextSequence] = MemoryCommitment({
            parentRoot: parentRoot,
            deltaRoot: preview.memoryDeltaRoot,
            newRoot: newMemoryRoot,
            sourceReceiptRoot: actionReceiptId,
            metadataCommitment: preview.observationRoot,
            sequence: nextSequence,
            memoryType: memoryType,
            actionSucceeded: actionSucceeded
        });

        hot.latestMemoryRoot = newMemoryRoot;
        hot.lastActionReceiptId = actionReceiptId;
        hot.sequence = nextSequence;
        hot.spendUsedThisEpoch += valueSpent;
        if (!actionSucceeded) {
            hot.failureCount += 1;
        }
        agent.latestMemoryRoot = newMemoryRoot;
        agent.sequence = nextSequence;
    }

    function _emitStepOutput(
        bytes32 agentId,
        bytes32 rootfieldId,
        bytes32 parentPulseId,
        bytes32 actionReceiptId,
        StepPreview memory preview,
        bool actionSucceeded,
        uint64 nextSequence,
        bytes32 parentRoot,
        bytes32 newMemoryRoot,
        string calldata uri
    ) private {
        bytes32 stepPulseId = _emitAgentPulse({
            rootfieldId: rootfieldId,
            actor: msg.sender,
            pulseType: FlowPulseTypes.AGENT_STEP_COMMITTED,
            subject: agentId,
            commitment: actionReceiptId,
            parentPulseId: parentPulseId,
            uri: uri
        });
        string memory memoryUri = string.concat(uri, "#memory");
        bytes32 memoryCommitment =
            keccak256(abi.encode(parentRoot, preview.memoryDeltaRoot, newMemoryRoot, actionReceiptId, actionSucceeded));
        bytes32 memoryPulseId = _emitAgentPulse({
            rootfieldId: rootfieldId,
            actor: msg.sender,
            pulseType: FlowPulseTypes.AGENT_MEMORY_COMMITTED,
            subject: newMemoryRoot,
            commitment: memoryCommitment,
            parentPulseId: stepPulseId,
            uri: memoryUri
        });
        _hotMemory[agentId].lastPulseId = memoryPulseId;

        MemoryType memoryType = actionSucceeded ? MemoryType.Episodic : MemoryType.ScarTissue;
        emit AgentStepCommitted(
            agentId,
            actionReceiptId,
            preview.observationRoot,
            preview.action,
            actionSucceeded,
            nextSequence,
            preview.reasonCode,
            newMemoryRoot
        );
        emit AgentMemoryCommitted(agentId, newMemoryRoot, actionReceiptId, parentRoot, preview.memoryDeltaRoot, memoryType, nextSequence);
    }

    function _memoryDeltaRoot(
        bytes32 agentId,
        uint64 sequence,
        bytes32 parentRoot,
        bytes32 observationRoot_,
        AgentAction action,
        uint64 reasonCode
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                AGENT_MEMORY_SCHEMA_ID,
                "memory_delta",
                agentId,
                sequence,
                parentRoot,
                observationRoot_,
                action,
                reasonCode
            )
        );
    }

    function _previewHash(bytes32 agentId, StepPreview memory preview) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                AGENT_MEMORY_SCHEMA_ID,
                "step_preview",
                agentId,
                preview.action,
                preview.toolId,
                preview.target,
                preview.selector,
                preview.callDataHash,
                preview.observationRoot,
                preview.memoryDeltaRoot,
                preview.sequence,
                preview.reasonCode,
                preview.maxValue
            )
        );
    }

    function _emitAgentPulse(
        bytes32 rootfieldId,
        address actor,
        uint8 pulseType,
        bytes32 subject,
        bytes32 commitment,
        bytes32 parentPulseId,
        string memory uri
    ) private returns (bytes32 pulseId) {
        uint64 sequence = _pulseCounts[rootfieldId] + 1;
        _pulseCounts[rootfieldId] = sequence;
        uint64 occurredAt = _blockTimestamp();
        pulseId = keccak256(
            abi.encode(
                FlowPulseTypes.SCHEMA_ID,
                AGENT_MEMORY_SCHEMA_ID,
                block.chainid,
                address(this),
                rootfieldId,
                actor,
                pulseType,
                subject,
                commitment,
                parentPulseId,
                sequence
            )
        );
        emit FlowPulse(pulseId, rootfieldId, actor, pulseType, subject, commitment, parentPulseId, sequence, occurredAt, uri);
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
