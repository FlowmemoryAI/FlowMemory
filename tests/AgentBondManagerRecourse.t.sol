// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentBondManager} from "../contracts/AgentBondManager.sol";
import {AgentStakeRegistry} from "../contracts/AgentStakeRegistry.sol";
import {TaskBondEscrow} from "../contracts/TaskBondEscrow.sol";
import {TaskPolicyRegistry} from "../contracts/TaskPolicyRegistry.sol";
import {AgentUnderwriterPool} from "../contracts/AgentUnderwriterPool.sol";
import {IUnderwriterPool} from "../contracts/interfaces/IUnderwriterPool.sol";
import {UnderwriterPoolRegistry} from "../contracts/UnderwriterPoolRegistry.sol";
import {AgentCreditAttestationRegistry} from "../contracts/AgentCreditAttestationRegistry.sol";

interface RecourseVm {
    function expectRevert(bytes calldata) external;
    function warp(uint256 newTimestamp) external;
}

contract RecourseToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (balanceOf[msg.sender] < amount) return false;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (balanceOf[from] < amount || allowance[from][msg.sender] < amount) return false;
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract RecourseActor {
    function approve(RecourseToken token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    function depositStake(AgentStakeRegistry registry, uint256 amount) external {
        registry.depositStake(amount);
    }

    function openTaskWithRecourse(
        AgentBondManager manager,
        bytes32 rootfieldId,
        bytes32 policyId,
        bytes32 termsHash,
        uint256 payout,
        address verifier,
        address recoursePool,
        uint256 recourseCoverage
    ) external returns (bytes32) {
        return manager.openTaskWithRecourse(rootfieldId, policyId, termsHash, payout, verifier, recoursePool, recourseCoverage, "fixture://task/open-recourse");
    }

    function acceptTask(AgentBondManager manager, bytes32 taskId) external {
        manager.acceptTask(taskId, "fixture://task/accept");
    }

    function startTask(AgentBondManager manager, bytes32 taskId) external {
        manager.startTask(taskId, "fixture://task/start");
    }

    function commitEvidence(AgentBondManager manager, bytes32 taskId, bytes32 evidenceCommitment, bytes32 availabilityCommitment, uint64 availabilityUntil) external {
        manager.commitEvidence(taskId, evidenceCommitment, availabilityCommitment, availabilityUntil, "fixture://task/evidence");
    }

    function submitVerifierReport(AgentBondManager manager, bytes32 taskId, bytes32 reportId, AgentBondManager.ReportStatus status, bytes32 reportDigest) external {
        manager.submitVerifierReport(taskId, reportId, status, reportDigest, "fixture://task/report");
    }

    function settleTask(AgentBondManager manager, bytes32 taskId) external {
        manager.settleTask(taskId);
    }

    function slashExpiredNoSubmission(AgentBondManager manager, bytes32 taskId) external {
        manager.slashExpiredNoSubmission(taskId, "fixture://task/expired");
    }

    function depositPool(AgentUnderwriterPool pool, uint256 amount) external {
        pool.deposit(amount);
    }
}

contract AgentBondManagerRecourseTest {
    RecourseVm private constant vm = RecourseVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant USDC = 1_000_000;
    uint256 private constant STAKE = 1 ether;

    RecourseToken private settlementToken;
    RecourseToken private stakeToken;
    TaskBondEscrow private escrow;
    AgentStakeRegistry private stakeRegistry;
    TaskPolicyRegistry private policyRegistry;
    AgentBondManager private manager;
    UnderwriterPoolRegistry private registry;
    AgentCreditAttestationRegistry private creditRegistry;
    AgentUnderwriterPool private recoursePool;
    RecourseActor private requester;
    RecourseActor private agent;
    RecourseActor private verifier;
    RecourseActor private underwriter;

    bytes32 private policyId;
    bytes32 private rootfieldId;
    bytes32 private termsHash;

    function setUp() public {
        settlementToken = new RecourseToken();
        stakeToken = new RecourseToken();
        escrow = new TaskBondEscrow(address(settlementToken), address(this));
        stakeRegistry = new AgentStakeRegistry(address(stakeToken), address(this), 10_000 * STAKE, 20_000 * STAKE, 10_000 * STAKE, 1_000 * USDC);
        policyRegistry = new TaskPolicyRegistry(address(this));
        manager = new AgentBondManager(address(escrow), address(stakeRegistry), address(policyRegistry), address(this), address(this), address(this));
        registry = new UnderwriterPoolRegistry(address(this));
        creditRegistry = new AgentCreditAttestationRegistry(address(this));
        recoursePool = new AgentUnderwriterPool(address(settlementToken), IUnderwriterPool.PoolType.UsdcRecoursePool, address(this), 100 * USDC, 3);
        escrow.setManager(address(manager));
        stakeRegistry.setSlashAuthority(address(manager));
        manager.setUnderwriterPoolRegistry(address(registry));
        manager.setCreditAttestationRegistry(address(creditRegistry));
        recoursePool.setAllocator(address(manager), true);
        registry.registerPool(address(recoursePool), IUnderwriterPool.PoolType.UsdcRecoursePool, address(settlementToken), 3);
        creditRegistry.setAuthorizedAttester(address(this), true);

        requester = new RecourseActor();
        agent = new RecourseActor();
        verifier = new RecourseActor();
        underwriter = new RecourseActor();

        settlementToken.mint(address(requester), 1_000_000 * USDC);
        settlementToken.mint(address(agent), 1_000_000 * USDC);
        settlementToken.mint(address(verifier), 1_000_000 * USDC);
        settlementToken.mint(address(underwriter), 1_000_000 * USDC);
        stakeToken.mint(address(agent), 100_000 * STAKE);
        stakeToken.mint(address(verifier), 100_000 * STAKE);

        requester.approve(settlementToken, address(escrow), type(uint256).max);
        agent.approve(settlementToken, address(escrow), type(uint256).max);
        verifier.approve(settlementToken, address(escrow), type(uint256).max);
        underwriter.approve(settlementToken, address(recoursePool), type(uint256).max);
        agent.approve(stakeToken, address(stakeRegistry), type(uint256).max);
        verifier.approve(stakeToken, address(stakeRegistry), type(uint256).max);
        agent.depositStake(stakeRegistry, 10_000 * STAKE);
        verifier.depositStake(stakeRegistry, 20_000 * STAKE);
        underwriter.depositPool(recoursePool, 250 * USDC);

        policyId = keccak256("agent-bonds.objective-code.low-risk");
        rootfieldId = keccak256("rootfield.agent-bonds.objective-code");
        termsHash = keccak256("task.terms.objective-code.v1");
        policyRegistry.createPolicy(policyId, _policy(0));
    }

    function testVerifiedTaskReleasesRecourseCoverage() public {
        bytes32 taskId = requester.openTaskWithRecourse(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier), address(recoursePool), 40 * USDC);
        agent.acceptTask(manager, taskId);
        require(recoursePool.totalLocked() == 40 * USDC, "coverage locked after accept");
        agent.startTask(manager, taskId);
        agent.commitEvidence(manager, taskId, keccak256("evidence.valid"), keccak256("availability.valid"), uint64(block.timestamp + 3 days));
        verifier.submitVerifierReport(manager, taskId, keccak256("report.valid"), AgentBondManager.ReportStatus.Valid, keccak256("digest.valid"));
        vm.warp(block.timestamp + 2 days);
        requester.settleTask(manager, taskId);
        require(recoursePool.totalLocked() == 0, "coverage released on success");
        require(recoursePool.availableCapacity() == 250 * USDC, "capacity restored on success");
    }

    function testInvalidReportTaskPaysAdditionalRecourseToRequester() public {
        bytes32 taskId = requester.openTaskWithRecourse(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier), address(recoursePool), 40 * USDC);
        agent.acceptTask(manager, taskId);
        agent.startTask(manager, taskId);
        agent.commitEvidence(manager, taskId, keccak256("evidence.invalid"), keccak256("availability.invalid"), uint64(block.timestamp + 3 days));
        verifier.submitVerifierReport(manager, taskId, keccak256("report.invalid"), AgentBondManager.ReportStatus.Invalid, keccak256("digest.invalid"));
        vm.warp(block.timestamp + 2 days);
        requester.settleTask(manager, taskId);
        require(recoursePool.totalLocked() == 0, "coverage consumed on failure");
        require(recoursePool.availableCapacity() == 210 * USDC, "pool balance reduced by paid claim");
        require(escrow.withdrawable(address(requester)) == 146_250_000, "requester receives escrow refund, slash share, and recourse claim");
    }

    function testExpiredNoSubmissionAlsoPaysRecourse() public {
        bytes32 taskId = requester.openTaskWithRecourse(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier), address(recoursePool), 30 * USDC);
        agent.acceptTask(manager, taskId);
        vm.warp(block.timestamp + 2 days);
        requester.slashExpiredNoSubmission(manager, taskId);
        require(recoursePool.availableCapacity() == 220 * USDC, "timeout recourse paid");
    }

    function testOpenTaskWithRecourseRequiresApprovedPool() public {
        AgentUnderwriterPool unapproved = new AgentUnderwriterPool(address(settlementToken), IUnderwriterPool.PoolType.UsdcRecoursePool, address(this), 100 * USDC, 3);
        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.RecoursePoolNotApproved.selector, address(unapproved)));
        requester.openTaskWithRecourse(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier), address(unapproved), 10 * USDC);
    }

    function testRecourseAcceptRequiresCreditAttestationWhenEnabled() public {
        manager.setRecourseAttestationRequirements(true, 700, 2);
        bytes32 taskId = requester.openTaskWithRecourse(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier), address(recoursePool), 20 * USDC);
        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.CreditAttestationMissing.selector, address(agent), policyId));
        agent.acceptTask(manager, taskId);

        _publishCreditAttestation(address(agent), policyId, 720, 1, uint64(block.timestamp + 1 days), keccak256("agent-credit"));
        agent.acceptTask(manager, taskId);
        require(recoursePool.totalLocked() == 20 * USDC, "coverage locked after attested accept");
    }

    function testRecourseExposureCapsLimitAcceptance() public {
        manager.setRecourseExposureCaps(25 * USDC, 25 * USDC, 25 * USDC);
        bytes32 taskId = requester.openTaskWithRecourse(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier), address(recoursePool), 30 * USDC);
        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.RecourseRequesterExposureCapExceeded.selector, 30 * USDC, 25 * USDC));
        agent.acceptTask(manager, taskId);
    }

    function _publishCreditAttestation(address agentAddress, bytes32 scope, uint16 score, uint8 riskBand, uint64 expiresAt, bytes32 scoreHash) private {
        creditRegistry.publishAttestation(agentAddress, scope, score, riskBand, expiresAt, scoreHash);
    }

    function _policy(uint8 requiredConfirmations) private pure returns (TaskPolicyRegistry.TaskPolicy memory) {
        return TaskPolicyRegistry.TaskPolicy({
            agentBondBps: 2_500,
            verifierFeeBps: 1_000,
            requesterCancelBondBps: 2_500,
            disputeBondBps: 5_000,
            requiredConfirmations: requiredConfirmations,
            submissionWindow: 1 days,
            disputeWindow: 1 days,
            graceWindow: 1 hours,
            minAvailabilityWindow: 2 days,
            minAgentBond: 10 * USDC,
            minVerifierFee: 1 * USDC,
            minRequesterCancelBond: 1 * USDC,
            minDisputeBond: 1 * USDC,
            evidenceSchema: keccak256("task-bond-evidence-v1"),
            riskTier: 1,
            objectiveOnly: true,
            active: true
        });
    }
}
