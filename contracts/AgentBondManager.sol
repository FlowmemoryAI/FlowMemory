// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFlowPulse, FlowPulseTypes} from "./FlowPulse.sol";
import {AgentStakeRegistry} from "./AgentStakeRegistry.sol";
import {TaskBondEscrow} from "./TaskBondEscrow.sol";
import {TaskPolicyRegistry} from "./TaskPolicyRegistry.sol";
import {IUnderwriterPool} from "./interfaces/IUnderwriterPool.sol";
import {UnderwriterPoolRegistry} from "./UnderwriterPoolRegistry.sol";
import {AgentCreditAttestationRegistry} from "./AgentCreditAttestationRegistry.sol";
import {TwoStepOwnable} from "./shared/TwoStepOwnable.sol";

/// @title AgentBondManager
/// @notice Objective task-bond lifecycle for FlowMemory Agent Bonds v1 local/test and capped pilot flows.
contract AgentBondManager is IFlowPulse, TwoStepOwnable {
    bytes32 public constant AGENT_BOND_SCHEMA_ID = keccak256("flowmemory.agent_bonds.v1");
    uint16 public constant REQUESTER_SLASH_BPS = 8_500;
    uint16 public constant VERIFIER_SLASH_BPS = 1_000;
    uint16 public constant RESERVE_SLASH_BPS = 500;
    uint16 public constant LATE_SLASH_BPS = 1_000;

    enum TaskStatus {
        Unknown,
        Open,
        Accepted,
        Started,
        EvidenceCommitted,
        Verified,
        Failed,
        Challenged,
        Settled,
        Refunded,
        Slashed,
        Unsupported,
        Reorged
    }

    enum ReportStatus {
        Unknown,
        Valid,
        Invalid,
        Unresolved,
        Unsupported,
        Reorged
    }

    struct Task {
        address requester;
        address agent;
        address verifier;
        address challenger;
        bytes32 rootfieldId;
        bytes32 policyId;
        bytes32 termsHash;
        bytes32 evidenceCommitment;
        bytes32 evidenceAvailabilityCommitment;
        bytes32 reportId;
        bytes32 reportDigest;
        bytes32 lastPulseId;
        uint256 payout;
        uint256 agentBond;
        uint256 verifierFee;
        uint256 requesterCancelBond;
        uint256 disputeBondQuote;
        uint256 disputeBondLocked;
        uint256 recourseCoverage;
        uint64 openedAt;
        uint64 acceptedAt;
        uint64 submissionDeadline;
        uint64 evidenceCommittedAt;
        uint64 evidenceAvailabilityUntil;
        uint64 reportedAt;
        uint64 disputeWindow;
        uint64 graceWindow;
        uint64 sequence;
        uint8 requiredConfirmations;
        uint8 reportConfirmations;
        TaskStatus status;
        TaskStatus preChallengeStatus;
        bool challengeResolved;
        bool recourseClaimPaid;
        bool exists;
        address recoursePool;
    }

    struct TaskQuote {
        uint256 agentBond;
        uint256 verifierFee;
        uint256 requesterCancelBond;
        uint256 disputeBond;
    }

    TaskBondEscrow public immutable escrow;
    AgentStakeRegistry public immutable stakeRegistry;
    TaskPolicyRegistry public immutable policyRegistry;

    UnderwriterPoolRegistry public underwriterPoolRegistry;
    AgentCreditAttestationRegistry public creditAttestationRegistry;
    address public resolutionAuthority;
    address public pauseGuardian;
    bool public paused;
    bool public emergencyStopped;
    bool public pilotMode;

    uint256 public taskNonce;
    uint256 public maxPayoutPerTask;
    uint256 public maxOpenExposure;
    uint256 public maxOpenTasks;
    uint256 public openExposure;
    uint256 public openTaskCount;
    uint256 public maxRecourseCoveragePerAgent;
    uint256 public maxRecourseCoveragePerRequester;
    uint256 public maxRecourseCoveragePerVerifier;
    uint16 public minimumRecourseScore;
    uint8 public maximumRecourseRiskBand = 5;
    bool public requireRecourseAttestations;

    mapping(bytes32 taskId => Task task) private _tasks;
    mapping(bytes32 taskId => mapping(address verifier => bool confirmed)) private _reportConfirmedBy;
    mapping(address requester => bool authorized) public requesterAuthorization;
    mapping(address agent => bool authorized) public agentAuthorization;
    mapping(address verifier => bool authorized) public verifierAuthorization;
    mapping(address requester => uint256 exposure) public recourseCoverageByRequester;
    mapping(address agent => uint256 exposure) public recourseCoverageByAgent;
    mapping(address verifier => uint256 exposure) public recourseCoverageByVerifier;

    bool private _entered;

    error ReentrantCall();
    error NotResolutionAuthority(address caller);
    error NotPauseGuardian(address caller);
    error ZeroRootfieldId();
    error ZeroPolicyId();
    error ZeroTermsHash();
    error ZeroPayout();
    error ZeroVerifier();
    error ZeroPauseGuardian();
    error ZeroEscrow();
    error ZeroStakeRegistry();
    error ZeroPolicyRegistry();
    error ZeroResolutionAuthority();
    error ZeroEvidenceCommitment();
    error ZeroAvailabilityCommitment();
    error ZeroReport();
    error ZeroChallengeCommitment();
    error PolicyInactive(bytes32 policyId);
    error VerifierNotEligible(address verifier);
    error AgentNotEligible(address agent);
    error AgentCapacityExceeded(address agent, uint256 additionalBond);
    error RequesterNotAuthorized(address requester);
    error AgentNotAuthorized(address agent);
    error VerifierNotAuthorizedForPilot(address verifier);
    error PayoutExceedsCap(uint256 payout, uint256 cap);
    error OpenExposureCapExceeded(uint256 attempted, uint256 cap);
    error OpenTaskCapExceeded(uint256 attempted, uint256 cap);
    error TaskNotFound(bytes32 taskId);
    error TaskExists(bytes32 taskId);
    error InvalidTaskStatus(bytes32 taskId, TaskStatus status);
    error NotTaskAgent(address caller, address agent);
    error NotTaskRequester(address caller, address requester);
    error InvalidReportStatus(ReportStatus status);
    error SubmissionDeadlinePassed(uint64 deadline, uint64 nowTime);
    error ChallengeWindowOpen(uint64 deadline, uint64 nowTime);
    error ChallengeWindowClosed(uint64 deadline, uint64 nowTime);
    error ConfirmationWindowClosed(uint64 deadline, uint64 nowTime);
    error NoSubmissionExpiryNotReached(uint64 deadline, uint64 nowTime);
    error AlreadySettled(bytes32 taskId);
    error ReportAlreadyConfirmed(bytes32 taskId, address verifier);
    error ReportDigestMismatch(bytes32 expected, bytes32 provided);
    error ReportStatusMismatch(TaskStatus expected, TaskStatus provided);
    error AvailabilityWindowTooShort(uint256 minimumRequired, uint64 provided);
    error InsufficientReportConfirmations(bytes32 taskId, uint8 requiredConfirmations, uint8 actualConfirmations);
    error Paused();
    error EmergencyStopped();
    error RecoursePoolRequired();
    error ZeroRecourseCoverage();
    error RecoursePoolNotApproved(address pool);
    error RecoursePoolTypeUnsupported(address pool, IUnderwriterPool.PoolType poolType);
    error RecourseCoverageUnavailable(address pool, uint256 amount);
    error CreditAttestationRegistryRequired();
    error CreditAttestationMissing(address agent, bytes32 scope);
    error RecourseRequesterExposureCapExceeded(uint256 attempted, uint256 cap);
    error RecourseAgentExposureCapExceeded(uint256 attempted, uint256 cap);
    error RecourseVerifierExposureCapExceeded(uint256 attempted, uint256 cap);

    event ResolutionAuthoritySet(address indexed previousAuthority, address indexed newAuthority);
    event PauseGuardianSet(address indexed previousGuardian, address indexed newGuardian);
    event PausedSet(bool paused);
    event EmergencyStopSet(bool stopped);
    event PilotModeSet(bool enabled);
    event PilotCapsSet(uint256 maxPayoutPerTask, uint256 maxOpenExposure, uint256 maxOpenTasks);
    event RequesterAuthorizationSet(address indexed requester, bool authorized);
    event AgentAuthorizationSet(address indexed agent, bool authorized);
    event VerifierAuthorizationSet(address indexed verifier, bool authorized);
    event UnderwriterPoolRegistrySet(address indexed previousRegistry, address indexed newRegistry);
    event CreditAttestationRegistrySet(address indexed previousRegistry, address indexed newRegistry);
    event RecourseExposureCapsSet(uint256 maxPerAgent, uint256 maxPerRequester, uint256 maxPerVerifier);
    event RecourseAttestationRequirementsSet(bool required, uint16 minimumScore, uint8 maximumRiskBand);
    event TaskOpened(bytes32 indexed taskId, address indexed requester, bytes32 indexed rootfieldId, bytes32 policyId, uint256 payout, uint256 verifierFee, uint256 requesterCancelBond, string uri);
    event TaskCanceled(bytes32 indexed taskId, address indexed requester, string uri);
    event TaskAccepted(bytes32 indexed taskId, address indexed agent, uint256 agentBond, uint64 submissionDeadline, string uri);
    event TaskStarted(bytes32 indexed taskId, address indexed agent, string uri);
    event TaskEvidenceCommitted(bytes32 indexed taskId, address indexed agent, bytes32 evidenceCommitment, bytes32 availabilityCommitment, uint64 availabilityUntil, string evidenceURI);
    event TaskVerifierReportSubmitted(bytes32 indexed taskId, address indexed verifier, bytes32 reportId, ReportStatus reportStatus, bytes32 reportDigest, uint8 requiredConfirmations, string evidenceURI);
    event TaskVerifierReportConfirmed(bytes32 indexed taskId, address indexed verifier, uint8 confirmations);
    event TaskChallenged(bytes32 indexed taskId, address indexed challenger, uint256 disputeBond, bytes32 challengeCommitment, string uri);
    event TaskChallengeResolved(bytes32 indexed taskId, address indexed resolver, TaskStatus finalStatus, bool challengerWon, bytes32 resolutionDigest, string uri);
    event TaskRecourseConfigured(bytes32 indexed taskId, address indexed pool, uint256 coverage);
    event TaskRecourseReleased(bytes32 indexed taskId, address indexed pool, uint256 released);
    event TaskRecourseClaimPaid(bytes32 indexed taskId, address indexed pool, address indexed recipient, uint256 amount, bytes32 reason);
    event TaskSettled(bytes32 indexed taskId, TaskStatus finalStatus, uint256 payout, uint256 agentBond, uint256 reserveAmount);

    modifier nonReentrant() {
        if (_entered) revert ReentrantCall();
        _entered = true;
        _;
        _entered = false;
    }

    modifier onlyResolutionAuthority() {
        if (msg.sender != resolutionAuthority) revert NotResolutionAuthority(msg.sender);
        _;
    }

    modifier onlyPauseGuardianOrOwner() {
        if (msg.sender != pauseGuardian && msg.sender != owner) revert NotPauseGuardian(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier whenNotEmergencyStopped() {
        if (emergencyStopped) revert EmergencyStopped();
        _;
    }

    constructor(
        address escrow_,
        address stakeRegistry_,
        address policyRegistry_,
        address initialOwner,
        address pauseGuardian_,
        address resolutionAuthority_
    ) TwoStepOwnable(initialOwner) {
        if (escrow_ == address(0)) revert ZeroEscrow();
        if (stakeRegistry_ == address(0)) revert ZeroStakeRegistry();
        if (policyRegistry_ == address(0)) revert ZeroPolicyRegistry();
        if (pauseGuardian_ == address(0)) revert ZeroPauseGuardian();
        if (resolutionAuthority_ == address(0)) revert ZeroResolutionAuthority();
        escrow = TaskBondEscrow(escrow_);
        stakeRegistry = AgentStakeRegistry(stakeRegistry_);
        policyRegistry = TaskPolicyRegistry(policyRegistry_);
        pauseGuardian = pauseGuardian_;
        resolutionAuthority = resolutionAuthority_;
    }

    function setResolutionAuthority(address authority) external onlyOwner {
        if (authority == address(0)) revert ZeroResolutionAuthority();
        address previousAuthority = resolutionAuthority;
        resolutionAuthority = authority;
        emit ResolutionAuthoritySet(previousAuthority, authority);
    }

    function setPauseGuardian(address guardian) external onlyOwner {
        if (guardian == address(0)) revert ZeroPauseGuardian();
        address previousGuardian = pauseGuardian;
        pauseGuardian = guardian;
        emit PauseGuardianSet(previousGuardian, guardian);
    }

    function setPaused(bool value) external onlyOwner {
        paused = value;
        emit PausedSet(value);
    }

    function setEmergencyStopped(bool value) external onlyPauseGuardianOrOwner {
        if (!value && msg.sender != owner) revert NotOwner(msg.sender);
        emergencyStopped = value;
        if (value) {
            paused = true;
            emit PausedSet(true);
        }
        emit EmergencyStopSet(value);
    }

    function setPilotMode(bool enabled) external onlyOwner {
        pilotMode = enabled;
        emit PilotModeSet(enabled);
    }

    function setPilotCaps(uint256 maxPayoutPerTask_, uint256 maxOpenExposure_, uint256 maxOpenTasks_) external onlyOwner {
        maxPayoutPerTask = maxPayoutPerTask_;
        maxOpenExposure = maxOpenExposure_;
        maxOpenTasks = maxOpenTasks_;
        emit PilotCapsSet(maxPayoutPerTask_, maxOpenExposure_, maxOpenTasks_);
    }

    function setRequesterAuthorization(address requester, bool authorized) external onlyOwner {
        requesterAuthorization[requester] = authorized;
        emit RequesterAuthorizationSet(requester, authorized);
    }

    function setAgentAuthorization(address agent, bool authorized) external onlyOwner {
        agentAuthorization[agent] = authorized;
        emit AgentAuthorizationSet(agent, authorized);
    }

    function setVerifierAuthorization(address verifier, bool authorized) external onlyOwner {
        verifierAuthorization[verifier] = authorized;
        emit VerifierAuthorizationSet(verifier, authorized);
    }

    function setUnderwriterPoolRegistry(address registry) external onlyOwner {
        address previous = address(underwriterPoolRegistry);
        underwriterPoolRegistry = UnderwriterPoolRegistry(registry);
        emit UnderwriterPoolRegistrySet(previous, registry);
    }

    function setCreditAttestationRegistry(address registry) external onlyOwner {
        address previous = address(creditAttestationRegistry);
        creditAttestationRegistry = AgentCreditAttestationRegistry(registry);
        emit CreditAttestationRegistrySet(previous, registry);
    }

    function setRecourseExposureCaps(uint256 maxPerAgent, uint256 maxPerRequester, uint256 maxPerVerifier) external onlyOwner {
        maxRecourseCoveragePerAgent = maxPerAgent;
        maxRecourseCoveragePerRequester = maxPerRequester;
        maxRecourseCoveragePerVerifier = maxPerVerifier;
        emit RecourseExposureCapsSet(maxPerAgent, maxPerRequester, maxPerVerifier);
    }

    function setRecourseAttestationRequirements(bool required, uint16 minimumScore, uint8 maximumRiskBand) external onlyOwner {
        requireRecourseAttestations = required;
        minimumRecourseScore = minimumScore;
        maximumRecourseRiskBand = maximumRiskBand;
        emit RecourseAttestationRequirementsSet(required, minimumScore, maximumRiskBand);
    }

    function openTask(
        bytes32 rootfieldId,
        bytes32 policyId,
        bytes32 termsHash,
        uint256 payout,
        address verifier,
        string calldata uri
    ) external nonReentrant whenNotPaused whenNotEmergencyStopped returns (bytes32 taskId) {
        return _openTask(rootfieldId, policyId, termsHash, payout, verifier, address(0), 0, uri);
    }

    function openTaskWithRecourse(
        bytes32 rootfieldId,
        bytes32 policyId,
        bytes32 termsHash,
        uint256 payout,
        address verifier,
        address recoursePool,
        uint256 recourseCoverage,
        string calldata uri
    ) external nonReentrant whenNotPaused whenNotEmergencyStopped returns (bytes32 taskId) {
        return _openTask(rootfieldId, policyId, termsHash, payout, verifier, recoursePool, recourseCoverage, uri);
    }

    // slither-disable-next-line cyclomatic-complexity,reentrancy-no-eth
    function _openTask(
        bytes32 rootfieldId,
        bytes32 policyId,
        bytes32 termsHash,
        uint256 payout,
        address verifier,
        address recoursePool,
        uint256 recourseCoverage,
        string memory uri
    ) private returns (bytes32 taskId) {
        _validateOpenTaskInput(rootfieldId, policyId, termsHash, payout, verifier);

        TaskPolicyRegistry.TaskPolicy memory policy = policyRegistry.getPolicy(policyId);
        if (!policy.active) revert PolicyInactive(policyId);
        _validateRecourseConfiguration(policyId, policy.riskTier, recoursePool, recourseCoverage);

        TaskQuote memory quote = TaskQuote({ agentBond: 0, verifierFee: 0, requesterCancelBond: 0, disputeBond: 0 });
        (quote.agentBond, quote.verifierFee, quote.requesterCancelBond, quote.disputeBond) =
            policyRegistry.quote(policyId, payout);
        uint256 requesterEscrow = payout + quote.verifierFee + quote.requesterCancelBond;
        _increaseOpenExposure(requesterEscrow);

        taskId = _taskId(msg.sender, rootfieldId, policyId, termsHash, taskNonce);
        if (_tasks[taskId].exists) revert TaskExists(taskId);
        taskNonce += 1;

        Task storage task = _tasks[taskId];
        task.requester = msg.sender;
        task.verifier = verifier;
        task.rootfieldId = rootfieldId;
        task.policyId = policyId;
        task.termsHash = termsHash;
        task.payout = payout;
        task.agentBond = quote.agentBond;
        task.verifierFee = quote.verifierFee;
        task.requesterCancelBond = quote.requesterCancelBond;
        task.disputeBondQuote = quote.disputeBond;
        task.recoursePool = recoursePool;
        task.recourseCoverage = recourseCoverage;
        task.openedAt = _blockTimestamp();
        task.disputeWindow = policy.disputeWindow;
        task.graceWindow = policy.graceWindow;
        task.requiredConfirmations = policy.requiredConfirmations;
        task.status = TaskStatus.Open;
        task.exists = true;
        openTaskCount += 1;

        _emitTaskPulse(
            taskId,
            task,
            FlowPulseTypes.TASK_OPENED,
            keccak256(abi.encode(termsHash, payout, quote.verifierFee, quote.requesterCancelBond, quote.disputeBond, recoursePool, recourseCoverage)),
            uri
        );
        escrow.lockFrom(taskId, msg.sender, requesterEscrow);
        emit TaskOpened(taskId, task.requester, task.rootfieldId, task.policyId, task.payout, task.verifierFee, task.requesterCancelBond, uri);
    }

    // slither-disable-next-line reentrancy-no-eth
    function cancelOpenTask(bytes32 taskId, string calldata uri) external nonReentrant {
        Task storage task = _requireTask(taskId);
        if (msg.sender != task.requester) revert NotTaskRequester(msg.sender, task.requester);
        if (task.status != TaskStatus.Open) revert InvalidTaskStatus(taskId, task.status);

        task.status = TaskStatus.Refunded;
        _decreaseOpenExposure(_requesterEscrow(task));
        openTaskCount -= 1;
        escrow.releaseTo(taskId, task.requester, _requesterEscrow(task));
        _emitTaskPulse(taskId, task, FlowPulseTypes.TASK_SETTLED, keccak256(abi.encode(taskId, task.status)), uri);
        emit TaskCanceled(taskId, task.requester, uri);
    }

    // slither-disable-next-line reentrancy-no-eth
    function acceptTask(bytes32 taskId, string calldata uri) external nonReentrant whenNotPaused whenNotEmergencyStopped {
        Task storage task = _requireTask(taskId);
        if (task.status != TaskStatus.Open) revert InvalidTaskStatus(taskId, task.status);
        if (!stakeRegistry.isAgentEligible(msg.sender)) revert AgentNotEligible(msg.sender);
        if (!stakeRegistry.canOpenAgentBond(msg.sender, task.agentBond)) revert AgentCapacityExceeded(msg.sender, task.agentBond);
        if (pilotMode && !agentAuthorization[msg.sender]) revert AgentNotAuthorized(msg.sender);

        _increaseOpenExposure(task.agentBond);
        TaskPolicyRegistry.TaskPolicy memory policy = policyRegistry.getPolicy(task.policyId);
        _validateRecourseAcceptance(task, msg.sender);
        uint64 now64 = _blockTimestamp();
        task.agent = msg.sender;
        task.acceptedAt = now64;
        task.submissionDeadline = now64 + policy.submissionWindow;
        task.status = TaskStatus.Accepted;

        _emitTaskPulse(taskId, task, FlowPulseTypes.TASK_ACCEPTED, keccak256(abi.encode(msg.sender, task.agentBond, task.submissionDeadline)), uri);
        if (task.recoursePool != address(0) && task.recourseCoverage != 0) {
            _increaseRecourseExposure(task.requester, msg.sender, task.verifier, task.recourseCoverage);
        }
        escrow.lockFrom(taskId, msg.sender, task.agentBond);
        stakeRegistry.recordOpenBond(msg.sender, task.agentBond);
        if (task.recoursePool != address(0) && task.recourseCoverage != 0) {
            IUnderwriterPool(task.recoursePool).lockCoverage(taskId, task.recourseCoverage);
            emit TaskRecourseConfigured(taskId, task.recoursePool, task.recourseCoverage);
        }
        emit TaskAccepted(taskId, msg.sender, task.agentBond, task.submissionDeadline, uri);
    }

    function startTask(bytes32 taskId, string calldata uri) external nonReentrant whenNotEmergencyStopped {
        Task storage task = _requireTask(taskId);
        if (msg.sender != task.agent) revert NotTaskAgent(msg.sender, task.agent);
        if (task.status != TaskStatus.Accepted) revert InvalidTaskStatus(taskId, task.status);
        task.status = TaskStatus.Started;
        _emitTaskPulse(taskId, task, FlowPulseTypes.TASK_STARTED, keccak256(abi.encode(taskId, msg.sender, _blockTimestamp())), uri);
        emit TaskStarted(taskId, msg.sender, uri);
    }

    function commitEvidence(
        bytes32 taskId,
        bytes32 evidenceCommitment,
        bytes32 availabilityCommitment,
        uint64 availabilityUntil,
        string calldata evidenceURI
    ) external nonReentrant whenNotEmergencyStopped {
        Task storage task = _requireTask(taskId);
        if (msg.sender != task.agent) revert NotTaskAgent(msg.sender, task.agent);
        if (task.status != TaskStatus.Accepted && task.status != TaskStatus.Started) {
            revert InvalidTaskStatus(taskId, task.status);
        }
        if (evidenceCommitment == bytes32(0)) revert ZeroEvidenceCommitment();
        if (availabilityCommitment == bytes32(0)) revert ZeroAvailabilityCommitment();

        uint64 now64 = _blockTimestamp();
        uint64 finalDeadline = task.submissionDeadline + task.graceWindow;
        if (now64 > finalDeadline) revert SubmissionDeadlinePassed(finalDeadline, now64);

        TaskPolicyRegistry.TaskPolicy memory policy = policyRegistry.getPolicy(task.policyId);
        uint256 minimumAvailabilityUntil = uint256(now64) + uint256(policy.minAvailabilityWindow);
        if (uint256(availabilityUntil) < minimumAvailabilityUntil) {
            revert AvailabilityWindowTooShort(minimumAvailabilityUntil, availabilityUntil);
        }

        task.evidenceCommitment = evidenceCommitment;
        task.evidenceAvailabilityCommitment = availabilityCommitment;
        task.evidenceAvailabilityUntil = availabilityUntil;
        task.evidenceCommittedAt = now64;
        task.status = TaskStatus.EvidenceCommitted;
        _emitTaskPulse(taskId, task, FlowPulseTypes.TASK_EVIDENCE_COMMITTED, keccak256(abi.encode(evidenceCommitment, availabilityCommitment, availabilityUntil)), evidenceURI);
        emit TaskEvidenceCommitted(taskId, msg.sender, evidenceCommitment, availabilityCommitment, availabilityUntil, evidenceURI);
    }

    function submitVerifierReport(
        bytes32 taskId,
        bytes32 reportId,
        ReportStatus reportStatus,
        bytes32 reportDigest,
        string calldata evidenceURI
    ) external nonReentrant {
        Task storage task = _requireTask(taskId);
        if (task.status != TaskStatus.EvidenceCommitted) revert InvalidTaskStatus(taskId, task.status);
        if (msg.sender != task.verifier) revert VerifierNotEligible(msg.sender);
        if (pilotMode && !verifierAuthorization[msg.sender]) revert VerifierNotAuthorizedForPilot(msg.sender);
        if (!stakeRegistry.isVerifierEligible(msg.sender)) revert VerifierNotEligible(msg.sender);
        if (reportId == bytes32(0) || reportDigest == bytes32(0)) revert ZeroReport();
        if (reportStatus == ReportStatus.Unknown || reportStatus == ReportStatus.Unresolved) revert InvalidReportStatus(reportStatus);

        uint64 now64 = _blockTimestamp();
        uint256 minimumAvailabilityUntil = uint256(now64) + uint256(task.disputeWindow);
        if (uint256(task.evidenceAvailabilityUntil) < minimumAvailabilityUntil) {
            revert AvailabilityWindowTooShort(minimumAvailabilityUntil, task.evidenceAvailabilityUntil);
        }

        task.reportId = reportId;
        task.reportDigest = reportDigest;
        task.reportedAt = now64;
        task.reportConfirmations = 0;
        task.challengeResolved = false;
        task.status = _taskStatusForReport(reportStatus);
        _reportConfirmedBy[taskId][msg.sender] = true;

        uint8 pulseType = reportStatus == ReportStatus.Valid ? FlowPulseTypes.TASK_VERIFIED : FlowPulseTypes.TASK_FAILED;
        _emitTaskPulse(taskId, task, pulseType, reportDigest, evidenceURI);
        emit TaskVerifierReportSubmitted(taskId, msg.sender, reportId, reportStatus, reportDigest, task.requiredConfirmations, evidenceURI);
    }

    function confirmVerifierReport(bytes32 taskId, ReportStatus reportStatus, bytes32 reportDigest) external nonReentrant {
        Task storage task = _requireTask(taskId);
        if (!_isReportBackedStatus(task.status)) revert InvalidTaskStatus(taskId, task.status);
        if (pilotMode && !verifierAuthorization[msg.sender]) revert VerifierNotAuthorizedForPilot(msg.sender);
        if (!stakeRegistry.isVerifierEligible(msg.sender)) revert VerifierNotEligible(msg.sender);
        if (_reportConfirmedBy[taskId][msg.sender]) revert ReportAlreadyConfirmed(taskId, msg.sender);

        uint64 now64 = _blockTimestamp();
        uint64 confirmationDeadline = task.reportedAt + task.disputeWindow;
        if (now64 > confirmationDeadline) revert ConfirmationWindowClosed(confirmationDeadline, now64);
        TaskStatus providedStatus = _taskStatusForReport(reportStatus);
        if (task.status != providedStatus) revert ReportStatusMismatch(task.status, providedStatus);
        if (task.reportDigest != reportDigest) revert ReportDigestMismatch(task.reportDigest, reportDigest);

        _reportConfirmedBy[taskId][msg.sender] = true;
        task.reportConfirmations += 1;
        emit TaskVerifierReportConfirmed(taskId, msg.sender, task.reportConfirmations);
    }

    // slither-disable-next-line reentrancy-no-eth
    function challengeTask(bytes32 taskId, bytes32 challengeCommitment, string calldata uri) external nonReentrant {
        Task storage task = _requireTask(taskId);
        if (!_isReportBackedStatus(task.status)) revert InvalidTaskStatus(taskId, task.status);
        if (challengeCommitment == bytes32(0)) revert ZeroChallengeCommitment();
        uint64 now64 = _blockTimestamp();
        uint64 challengeDeadline = task.reportedAt + task.disputeWindow;
        if (now64 > challengeDeadline) revert ChallengeWindowClosed(challengeDeadline, now64);

        _increaseOpenExposure(task.disputeBondQuote);
        escrow.lockFrom(taskId, msg.sender, task.disputeBondQuote);
        task.challenger = msg.sender;
        task.disputeBondLocked = task.disputeBondQuote;
        task.preChallengeStatus = task.status;
        task.status = TaskStatus.Challenged;

        _emitTaskPulse(taskId, task, FlowPulseTypes.TASK_CHALLENGED, challengeCommitment, uri);
        emit TaskChallenged(taskId, msg.sender, task.disputeBondLocked, challengeCommitment, uri);
    }

    // slither-disable-next-line reentrancy-no-eth,reentrancy-benign
    function resolveChallenge(
        bytes32 taskId,
        ReportStatus finalReportStatus,
        bytes32 resolutionDigest,
        uint16 verifierSlashBps,
        string calldata uri
    ) external nonReentrant onlyResolutionAuthority {
        Task storage task = _requireTask(taskId);
        if (task.status != TaskStatus.Challenged) revert InvalidTaskStatus(taskId, task.status);
        if (resolutionDigest == bytes32(0)) revert ZeroReport();
        if (finalReportStatus == ReportStatus.Unknown || finalReportStatus == ReportStatus.Unresolved) {
            revert InvalidReportStatus(finalReportStatus);
        }
        if (verifierSlashBps > 10_000) revert InvalidReportStatus(finalReportStatus);

        TaskStatus finalStatus = _taskStatusForReport(finalReportStatus);
        bool challengerWon = finalStatus != task.preChallengeStatus;
        address disputeBondRecipient = challengerWon ? task.challenger : task.agent;
        uint256 disputeBondLocked = task.disputeBondLocked;
        task.challengeResolved = true;
        task.status = finalStatus;
        task.reportDigest = resolutionDigest;
        task.reportConfirmations = task.requiredConfirmations;
        _decreaseOpenExposure(disputeBondLocked);
        task.disputeBondLocked = 0;

        uint256 slashAmount = 0;
        if (challengerWon && verifierSlashBps > 0) {
            uint256 verifierStake = stakeRegistry.stakeOf(task.verifier);
            slashAmount = verifierStake * verifierSlashBps / 10_000;
        }

        uint8 pulseType = finalStatus == TaskStatus.Verified ? FlowPulseTypes.TASK_VERIFIED : FlowPulseTypes.TASK_FAILED;
        _emitTaskPulse(taskId, task, pulseType, resolutionDigest, uri);
        escrow.releaseTo(taskId, disputeBondRecipient, disputeBondLocked);
        if (slashAmount > 0) {
            stakeRegistry.slashStake(task.verifier, slashAmount);
        }
        emit TaskChallengeResolved(taskId, msg.sender, finalStatus, challengerWon, resolutionDigest, uri);
    }

    function settleTask(bytes32 taskId) external nonReentrant {
        Task storage task = _requireTask(taskId);
        if (_isTerminal(task.status)) revert AlreadySettled(taskId);
        if ((task.status == TaskStatus.Verified || task.status == TaskStatus.Failed) && !task.challengeResolved) {
            uint64 challengeDeadline = task.reportedAt + task.disputeWindow;
            uint64 now64 = _blockTimestamp();
            if (now64 <= challengeDeadline) revert ChallengeWindowOpen(challengeDeadline, now64);
            if (task.reportConfirmations < task.requiredConfirmations) {
                revert InsufficientReportConfirmations(taskId, task.requiredConfirmations, task.reportConfirmations);
            }
        }

        if (task.status == TaskStatus.Verified) {
            _settleVerified(taskId, task);
        } else if (task.status == TaskStatus.Failed) {
            _settleFailed(taskId, task);
        } else if (task.status == TaskStatus.Unsupported || task.status == TaskStatus.Reorged) {
            _settleRefund(taskId, task);
        } else {
            revert InvalidTaskStatus(taskId, task.status);
        }
    }

    // slither-disable-next-line reentrancy-no-eth,reentrancy-benign
    function slashExpiredNoSubmission(bytes32 taskId, string calldata uri) external nonReentrant {
        Task storage task = _requireTask(taskId);
        if (task.status != TaskStatus.Accepted && task.status != TaskStatus.Started) {
            revert InvalidTaskStatus(taskId, task.status);
        }
        uint64 expiry = task.submissionDeadline + task.graceWindow;
        uint64 now64 = _blockTimestamp();
        if (now64 <= expiry) revert NoSubmissionExpiryNotReached(expiry, now64);

        task.status = TaskStatus.Slashed;
        _decreaseOpenExposure(_requesterEscrow(task) + task.agentBond);
        openTaskCount -= 1;
        _emitTaskPulse(taskId, task, FlowPulseTypes.TASK_SLASHED, keccak256(abi.encode(taskId, task.agentBond, "expired")), uri);
        stakeRegistry.recordClosedBond(task.agent, task.agentBond);
        escrow.releaseTo(taskId, task.requester, _requesterEscrow(task));
        _releaseSlash(taskId, task.requester, task.agentBond, false);
        _payRecourseClaim(taskId, task, task.requester, keccak256("expired_no_submission"));
        emit TaskSettled(taskId, task.status, task.payout, task.agentBond, task.agentBond * RESERVE_SLASH_BPS / 10_000);
    }

    function quoteTask(bytes32 policyId, uint256 payout)
        external
        view
        returns (uint256 agentBond, uint256 verifierFee, uint256 requesterCancelBond, uint256 disputeBond)
    {
        (agentBond, verifierFee, requesterCancelBond, disputeBond) = policyRegistry.quote(policyId, payout);
    }

    function _validateOpenTaskInput(
        bytes32 rootfieldId,
        bytes32 policyId,
        bytes32 termsHash,
        uint256 payout,
        address verifier
    ) private view {
        _validateOpenTaskCore(rootfieldId, policyId, termsHash, payout, verifier);
        _validateOpenTaskPilotAndCaps(payout, verifier);
    }

    function _validateOpenTaskCore(
        bytes32 rootfieldId,
        bytes32 policyId,
        bytes32 termsHash,
        uint256 payout,
        address verifier
    ) private view {
        if (rootfieldId == bytes32(0)) revert ZeroRootfieldId();
        if (policyId == bytes32(0)) revert ZeroPolicyId();
        if (termsHash == bytes32(0)) revert ZeroTermsHash();
        if (payout == 0) revert ZeroPayout();
        if (verifier == address(0)) revert ZeroVerifier();
        if (!stakeRegistry.isVerifierEligible(verifier)) revert VerifierNotEligible(verifier);
    }

    function _validateOpenTaskPilotAndCaps(uint256 payout, address verifier) private view {
        if (pilotMode) {
            if (!requesterAuthorization[msg.sender]) revert RequesterNotAuthorized(msg.sender);
            if (!verifierAuthorization[verifier]) revert VerifierNotAuthorizedForPilot(verifier);
        }
        if (maxPayoutPerTask != 0 && payout > maxPayoutPerTask) revert PayoutExceedsCap(payout, maxPayoutPerTask);
        if (maxOpenTasks != 0 && openTaskCount + 1 > maxOpenTasks) revert OpenTaskCapExceeded(openTaskCount + 1, maxOpenTasks);
    }

    function _validateRecourseConfiguration(
        bytes32 policyId,
        uint8 riskTier,
        address recoursePool,
        uint256 recourseCoverage
    ) private view {
        if (recoursePool == address(0) && recourseCoverage != 0) revert RecoursePoolRequired();
        if (recoursePool != address(0) && recourseCoverage == 0) revert ZeroRecourseCoverage();
        if (recoursePool == address(0)) {
            return;
        }
        if (address(underwriterPoolRegistry) == address(0) || !underwriterPoolRegistry.isPoolApproved(recoursePool)) {
            revert RecoursePoolNotApproved(recoursePool);
        }
        UnderwriterPoolRegistry.PoolRecord memory record = underwriterPoolRegistry.requirePoolAsset(recoursePool, address(escrow.settlementToken()));
        if (record.poolType != IUnderwriterPool.PoolType.UsdcRecoursePool) {
            revert RecoursePoolTypeUnsupported(recoursePool, record.poolType);
        }
        if (!IUnderwriterPool(recoursePool).canBackTask(policyId, recourseCoverage, riskTier)) {
            revert RecourseCoverageUnavailable(recoursePool, recourseCoverage);
        }
    }

    function _validateRecourseAcceptance(Task storage task, address agent) private view {
        if (task.recoursePool == address(0) || task.recourseCoverage == 0) {
            return;
        }
        if (requireRecourseAttestations) {
            if (address(creditAttestationRegistry) == address(0)) revert CreditAttestationRegistryRequired();
            if (!creditAttestationRegistry.isAttestationValid(agent, task.policyId, minimumRecourseScore, maximumRecourseRiskBand)) {
                revert CreditAttestationMissing(agent, task.policyId);
            }
        }
        if (maxRecourseCoveragePerRequester != 0 && recourseCoverageByRequester[task.requester] + task.recourseCoverage > maxRecourseCoveragePerRequester) {
            revert RecourseRequesterExposureCapExceeded(recourseCoverageByRequester[task.requester] + task.recourseCoverage, maxRecourseCoveragePerRequester);
        }
        if (maxRecourseCoveragePerAgent != 0 && recourseCoverageByAgent[agent] + task.recourseCoverage > maxRecourseCoveragePerAgent) {
            revert RecourseAgentExposureCapExceeded(recourseCoverageByAgent[agent] + task.recourseCoverage, maxRecourseCoveragePerAgent);
        }
        if (maxRecourseCoveragePerVerifier != 0 && recourseCoverageByVerifier[task.verifier] + task.recourseCoverage > maxRecourseCoveragePerVerifier) {
            revert RecourseVerifierExposureCapExceeded(recourseCoverageByVerifier[task.verifier] + task.recourseCoverage, maxRecourseCoveragePerVerifier);
        }
    }

    function _increaseRecourseExposure(address requester, address agent, address verifier, uint256 amount) private {
        if (amount < 1) return;
        recourseCoverageByRequester[requester] += amount;
        recourseCoverageByAgent[agent] += amount;
        recourseCoverageByVerifier[verifier] += amount;
    }

    function _decreaseRecourseExposure(address requester, address agent, address verifier, uint256 amount) private {
        if (amount == 0) return;
        recourseCoverageByRequester[requester] -= amount;
        recourseCoverageByAgent[agent] -= amount;
        recourseCoverageByVerifier[verifier] -= amount;
    }

    function getTask(bytes32 taskId) external view returns (Task memory) {
        return _tasks[taskId];
    }

    function hasConfirmedReport(bytes32 taskId, address verifier) external view returns (bool) {
        return _reportConfirmedBy[taskId][verifier];
    }

    // slither-disable-next-line reentrancy-no-eth,reentrancy-benign
    function _settleVerified(bytes32 taskId, Task storage task) private {
        task.status = TaskStatus.Settled;
        _decreaseOpenExposure(_requesterEscrow(task) + task.agentBond);
        openTaskCount -= 1;

        uint256 returnedBond = task.agentBond;
        uint256 reserveAmount = 0;
        uint256 requesterLateSlash = 0;
        if (task.evidenceCommittedAt > task.submissionDeadline) {
            uint256 lateSlash = task.agentBond * LATE_SLASH_BPS / 10_000;
            returnedBond -= lateSlash;
            uint256 reserveShare = task.agentBond * LATE_SLASH_BPS * RESERVE_SLASH_BPS / 100_000_000;
            reserveAmount = reserveShare;
            requesterLateSlash = lateSlash - reserveShare;
        }

        _emitTaskPulse(taskId, task, FlowPulseTypes.TASK_SETTLED, keccak256(abi.encode(taskId, task.reportDigest, task.status)), "flowmemory://agent-bonds/settled");
        stakeRegistry.recordClosedBond(task.agent, task.agentBond);
        if (requesterLateSlash > 0) {
            escrow.releaseTo(taskId, task.requester, requesterLateSlash);
        }
        if (reserveAmount > 0) {
            escrow.moveToReserve(taskId, reserveAmount);
        }
        escrow.releaseTo(taskId, task.agent, task.payout + returnedBond);
        escrow.releaseTo(taskId, task.requester, task.requesterCancelBond);
        escrow.releaseTo(taskId, task.verifier, task.verifierFee);
        _releaseRecourse(taskId, task);
        emit TaskSettled(taskId, task.status, task.payout, task.agentBond, reserveAmount);
    }

    // slither-disable-next-line reentrancy-no-eth,reentrancy-benign
    function _settleFailed(bytes32 taskId, Task storage task) private {
        task.status = TaskStatus.Slashed;
        _decreaseOpenExposure(_requesterEscrow(task) + task.agentBond);
        openTaskCount -= 1;

        address feeRecipient = task.challengeResolved && task.challenger != address(0) && task.preChallengeStatus != TaskStatus.Failed
            ? task.challenger
            : task.verifier;
        _emitTaskPulse(taskId, task, FlowPulseTypes.TASK_SLASHED, keccak256(abi.encode(taskId, task.reportDigest, task.status)), "flowmemory://agent-bonds/slashed");
        stakeRegistry.recordClosedBond(task.agent, task.agentBond);
        escrow.releaseTo(taskId, task.requester, task.payout + task.requesterCancelBond);
        escrow.releaseTo(taskId, feeRecipient, task.verifierFee);
        _releaseSlash(taskId, task.verifier, task.agentBond, true);
        _payRecourseClaim(taskId, task, task.requester, keccak256("task_failed"));
        emit TaskSettled(taskId, task.status, task.payout, task.agentBond, task.agentBond * RESERVE_SLASH_BPS / 10_000);
    }

    // slither-disable-next-line reentrancy-no-eth,reentrancy-benign
    function _settleRefund(bytes32 taskId, Task storage task) private {
        task.status = TaskStatus.Refunded;
        _decreaseOpenExposure(_requesterEscrow(task) + task.agentBond);
        openTaskCount -= 1;

        address feeRecipient = task.challengeResolved && task.challenger != address(0) && task.preChallengeStatus != task.status
            ? task.challenger
            : task.verifier;
        _emitTaskPulse(taskId, task, FlowPulseTypes.TASK_SETTLED, keccak256(abi.encode(taskId, task.reportDigest, task.status)), "flowmemory://agent-bonds/refunded");
        stakeRegistry.recordClosedBond(task.agent, task.agentBond);
        escrow.releaseTo(taskId, task.requester, task.payout + task.requesterCancelBond);
        escrow.releaseTo(taskId, task.agent, task.agentBond);
        escrow.releaseTo(taskId, feeRecipient, task.verifierFee);
        _releaseRecourse(taskId, task);
        emit TaskSettled(taskId, task.status, task.payout, task.agentBond, 0);
    }

    function _releaseRecourse(bytes32 taskId, Task storage task) private {
        if (task.recoursePool == address(0) || task.recourseCoverage == 0 || task.recourseClaimPaid) {
            return;
        }
        _decreaseRecourseExposure(task.requester, task.agent, task.verifier, task.recourseCoverage);
        uint256 released = IUnderwriterPool(task.recoursePool).releaseForTask(taskId);
        emit TaskRecourseReleased(taskId, task.recoursePool, released);
    }

    function _payRecourseClaim(bytes32 taskId, Task storage task, address recipient, bytes32 reason) private {
        if (task.recoursePool == address(0) || task.recourseCoverage == 0 || task.recourseClaimPaid) {
            return;
        }
        task.recourseClaimPaid = true;
        _decreaseRecourseExposure(task.requester, task.agent, task.verifier, task.recourseCoverage);
        uint256 paid = IUnderwriterPool(task.recoursePool).payClaim(taskId, recipient, task.recourseCoverage, reason);
        emit TaskRecourseClaimPaid(taskId, task.recoursePool, recipient, paid, reason);
    }

    function _releaseSlash(bytes32 taskId, address verifierShareRecipient, uint256 amount, bool verifierShare) private {
        uint256 requesterShare = amount * REQUESTER_SLASH_BPS / 10_000;
        uint256 middleShare = verifierShare ? amount * VERIFIER_SLASH_BPS / 10_000 : 0;
        uint256 reserveShare = amount * RESERVE_SLASH_BPS / 10_000;
        uint256 remainder = amount - requesterShare - middleShare - reserveShare;
        escrow.releaseTo(taskId, _tasks[taskId].requester, requesterShare + remainder);
        if (middleShare > 0) {
            escrow.releaseTo(taskId, verifierShareRecipient, middleShare);
        }
        if (reserveShare > 0) {
            escrow.moveToReserve(taskId, reserveShare);
        }
    }

    function _requesterEscrow(Task storage task) private view returns (uint256) {
        return task.payout + task.verifierFee + task.requesterCancelBond;
    }

    function _increaseOpenExposure(uint256 amount) private {
        if (amount == 0) {
            return;
        }
        uint256 attempted = openExposure + amount;
        if (maxOpenExposure != 0 && attempted > maxOpenExposure) {
            revert OpenExposureCapExceeded(attempted, maxOpenExposure);
        }
        openExposure = attempted;
    }

    function _decreaseOpenExposure(uint256 amount) private {
        if (amount == 0) {
            return;
        }
        openExposure -= amount;
    }

    function _taskStatusForReport(ReportStatus reportStatus) private pure returns (TaskStatus) {
        if (reportStatus == ReportStatus.Valid) return TaskStatus.Verified;
        if (reportStatus == ReportStatus.Invalid) return TaskStatus.Failed;
        if (reportStatus == ReportStatus.Unsupported) return TaskStatus.Unsupported;
        if (reportStatus == ReportStatus.Reorged) return TaskStatus.Reorged;
        revert InvalidReportStatus(reportStatus);
    }

    function _isReportBackedStatus(TaskStatus status) private pure returns (bool) {
        return status == TaskStatus.Verified || status == TaskStatus.Failed || status == TaskStatus.Unsupported || status == TaskStatus.Reorged;
    }

    function _isTerminal(TaskStatus status) private pure returns (bool) {
        return status == TaskStatus.Settled || status == TaskStatus.Refunded || status == TaskStatus.Slashed;
    }

    function _requireTask(bytes32 taskId) private view returns (Task storage task) {
        task = _tasks[taskId];
        if (!task.exists) revert TaskNotFound(taskId);
    }

    function _emitTaskPulse(bytes32 taskId, Task storage task, uint8 pulseType, bytes32 commitment, string memory uri)
        private
        returns (bytes32 pulseId)
    {
        task.sequence += 1;
        pulseId = keccak256(
            abi.encode(
                FlowPulseTypes.SCHEMA_ID,
                AGENT_BOND_SCHEMA_ID,
                block.chainid,
                address(this),
                taskId,
                pulseType,
                task.sequence,
                commitment
            )
        );
        emit FlowPulse(
            pulseId,
            task.rootfieldId,
            msg.sender,
            pulseType,
            taskId,
            commitment,
            task.lastPulseId,
            task.sequence,
            _blockTimestamp(),
            uri
        );
        task.lastPulseId = pulseId;
    }

    function _taskId(address requester, bytes32 rootfieldId, bytes32 policyId, bytes32 termsHash, uint256 nonce)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(AGENT_BOND_SCHEMA_ID, block.chainid, address(this), requester, rootfieldId, policyId, termsHash, nonce)
        );
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert SubmissionDeadlinePassed(type(uint64).max, type(uint64).max);
        return uint64(block.timestamp);
    }
}
