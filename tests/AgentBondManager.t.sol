// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentBondManager} from "../contracts/AgentBondManager.sol";
import {AgentStakeRegistry} from "../contracts/AgentStakeRegistry.sol";
import {TaskBondEscrow} from "../contracts/TaskBondEscrow.sol";
import {TaskPolicyRegistry} from "../contracts/TaskPolicyRegistry.sol";

interface AgentBondVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function warp(uint256 newTimestamp) external;
}

contract LocalTestToken {
    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (balanceOf[msg.sender] < amount) {
            return false;
        }
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (balanceOf[from] < amount || allowance[from][msg.sender] < amount) {
            return false;
        }
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract BondActor {
    function approve(LocalTestToken token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    function depositStake(AgentStakeRegistry registry, uint256 amount) external {
        registry.depositStake(amount);
    }

    function openTask(
        AgentBondManager manager,
        bytes32 rootfieldId,
        bytes32 policyId,
        bytes32 termsHash,
        uint256 payout,
        address verifier
    ) external returns (bytes32) {
        return manager.openTask(rootfieldId, policyId, termsHash, payout, verifier, "fixture://task/open");
    }

    function cancelOpenTask(AgentBondManager manager, bytes32 taskId) external {
        manager.cancelOpenTask(taskId, "fixture://task/cancel");
    }

    function acceptTask(AgentBondManager manager, bytes32 taskId) external {
        manager.acceptTask(taskId, "fixture://task/accept");
    }

    function startTask(AgentBondManager manager, bytes32 taskId) external {
        manager.startTask(taskId, "fixture://task/start");
    }

    function commitEvidence(
        AgentBondManager manager,
        bytes32 taskId,
        bytes32 evidenceCommitment,
        bytes32 availabilityCommitment,
        uint64 availabilityUntil
    ) external {
        manager.commitEvidence(taskId, evidenceCommitment, availabilityCommitment, availabilityUntil, "fixture://task/evidence");
    }

    function submitVerifierReport(
        AgentBondManager manager,
        bytes32 taskId,
        bytes32 reportId,
        AgentBondManager.ReportStatus status,
        bytes32 reportDigest
    ) external {
        manager.submitVerifierReport(taskId, reportId, status, reportDigest, "fixture://task/report");
    }

    function confirmVerifierReport(
        AgentBondManager manager,
        bytes32 taskId,
        AgentBondManager.ReportStatus status,
        bytes32 reportDigest
    ) external {
        manager.confirmVerifierReport(taskId, status, reportDigest);
    }

    function challengeTask(AgentBondManager manager, bytes32 taskId, bytes32 challengeCommitment) external {
        manager.challengeTask(taskId, challengeCommitment, "fixture://task/challenge");
    }

    function settleTask(AgentBondManager manager, bytes32 taskId) external {
        manager.settleTask(taskId);
    }

    function slashExpiredNoSubmission(AgentBondManager manager, bytes32 taskId) external {
        manager.slashExpiredNoSubmission(taskId, "fixture://task/expired");
    }

    function withdraw(TaskBondEscrow escrow) external {
        escrow.withdraw();
    }
}

contract AgentBondManagerTest {
    AgentBondVm private constant vm = AgentBondVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FLOWPULSE_SIGNATURE =
        keccak256("FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)");

    uint256 private constant USDC = 1_000_000;
    uint256 private constant STAKE = 1 ether;

    LocalTestToken private settlementToken;
    LocalTestToken private stakeToken;
    TaskBondEscrow private escrow;
    AgentStakeRegistry private stakeRegistry;
    TaskPolicyRegistry private policyRegistry;
    AgentBondManager private manager;
    BondActor private requester;
    BondActor private agent;
    BondActor private verifier;
    BondActor private verifierTwo;

    bytes32 private policyId;
    bytes32 private confirmedPolicyId;
    bytes32 private rootfieldId;
    bytes32 private termsHash;

    error AssertionFailed();

    function setUp() public {
        settlementToken = new LocalTestToken();
        stakeToken = new LocalTestToken();
        escrow = new TaskBondEscrow(address(settlementToken), address(this));
        stakeRegistry = new AgentStakeRegistry(address(stakeToken), address(this), 10_000 * STAKE, 20_000 * STAKE, 10_000 * STAKE, 1_000 * USDC);
        policyRegistry = new TaskPolicyRegistry(address(this));
        manager = new AgentBondManager(address(escrow), address(stakeRegistry), address(policyRegistry), address(this), address(this), address(this));
        escrow.setManager(address(manager));
        stakeRegistry.setSlashAuthority(address(manager));

        requester = new BondActor();
        agent = new BondActor();
        verifier = new BondActor();
        verifierTwo = new BondActor();

        settlementToken.mint(address(requester), 1_000_000 * USDC);
        settlementToken.mint(address(agent), 1_000_000 * USDC);
        settlementToken.mint(address(verifier), 1_000_000 * USDC);
        settlementToken.mint(address(verifierTwo), 1_000_000 * USDC);
        stakeToken.mint(address(agent), 100_000 * STAKE);
        stakeToken.mint(address(verifier), 100_000 * STAKE);
        stakeToken.mint(address(verifierTwo), 100_000 * STAKE);

        requester.approve(settlementToken, address(escrow), type(uint256).max);
        agent.approve(settlementToken, address(escrow), type(uint256).max);
        verifier.approve(settlementToken, address(escrow), type(uint256).max);
        verifierTwo.approve(settlementToken, address(escrow), type(uint256).max);
        agent.approve(stakeToken, address(stakeRegistry), type(uint256).max);
        verifier.approve(stakeToken, address(stakeRegistry), type(uint256).max);
        verifierTwo.approve(stakeToken, address(stakeRegistry), type(uint256).max);
        agent.depositStake(stakeRegistry, 10_000 * STAKE);
        verifier.depositStake(stakeRegistry, 20_000 * STAKE);
        verifierTwo.depositStake(stakeRegistry, 20_000 * STAKE);

        policyId = keccak256("agent-bonds.objective-code.low-risk");
        confirmedPolicyId = keccak256("agent-bonds.objective-code.confirmed");
        rootfieldId = keccak256("rootfield.agent-bonds.objective-code");
        termsHash = keccak256("task.terms.objective-code.v1");
        policyRegistry.createPolicy(policyId, _policy(0));
        policyRegistry.createPolicy(confirmedPolicyId, _policy(1));
    }

    function testVerifiedTaskSettlesEscrowAndEmitsTaskPulse() public {
        vm.recordLogs();
        bytes32 taskId = _openAcceptedStartedTask(policyId, address(verifier));
        agent.commitEvidence(manager, taskId, keccak256("evidence.valid"), keccak256("availability.valid"), uint64(block.timestamp + 3 days));
        verifier.submitVerifierReport(
            manager,
            taskId,
            keccak256("report.valid"),
            AgentBondManager.ReportStatus.Valid,
            keccak256("digest.valid")
        );
        vm.warp(block.timestamp + 2 days);
        requester.settleTask(manager, taskId);
        AgentBondVm.Log[] memory logs = vm.getRecordedLogs();

        _assertTrue(_flowPulseWithType(logs, 5));
        _assertTrue(_flowPulseWithType(logs, 12));
        _assertStatus(taskId, AgentBondManager.TaskStatus.Settled);
        _assertTrue(escrow.lockedByTask(taskId) == 0);
        _assertTrue(escrow.withdrawable(address(agent)) == 125 * USDC);
        _assertTrue(escrow.withdrawable(address(requester)) == 25 * USDC);
        _assertTrue(escrow.withdrawable(address(verifier)) == 10 * USDC);
        _assertTrue(escrow.reserveBalance() == 0);
        _assertTrue(stakeRegistry.openBondExposure(address(agent)) == 0);
        _assertTrue(manager.openExposure() == 0);
        _assertTrue(manager.openTaskCount() == 0);

        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.AlreadySettled.selector, taskId));
        requester.settleTask(manager, taskId);
    }

    function testConfirmedPolicyRequiresIndependentVerifierConfirmation() public {
        bytes32 taskId = _openAcceptedStartedTask(confirmedPolicyId, address(verifier));
        bytes32 digest = keccak256("digest.confirmed");
        agent.commitEvidence(manager, taskId, keccak256("evidence.confirmed"), keccak256("availability.confirmed"), uint64(block.timestamp + 3 days));
        verifier.submitVerifierReport(manager, taskId, keccak256("report.confirmed"), AgentBondManager.ReportStatus.Valid, digest);

        verifierTwo.confirmVerifierReport(manager, taskId, AgentBondManager.ReportStatus.Valid, digest);
        vm.warp(block.timestamp + 2 days);
        requester.settleTask(manager, taskId);
        _assertStatus(taskId, AgentBondManager.TaskStatus.Settled);
        _assertTrue(escrow.withdrawable(address(agent)) == 125 * USDC);
    }

    function testInvalidReportSlashesAgentBondWithDeterministicSplit() public {
        bytes32 taskId = _openAcceptedStartedTask(policyId, address(verifier));
        agent.commitEvidence(manager, taskId, keccak256("evidence.invalid"), keccak256("availability.invalid"), uint64(block.timestamp + 3 days));
        verifier.submitVerifierReport(
            manager,
            taskId,
            keccak256("report.invalid"),
            AgentBondManager.ReportStatus.Invalid,
            keccak256("digest.invalid")
        );
        vm.warp(block.timestamp + 2 days);
        requester.settleTask(manager, taskId);

        _assertStatus(taskId, AgentBondManager.TaskStatus.Slashed);
        _assertTrue(escrow.lockedByTask(taskId) == 0);
        _assertTrue(escrow.withdrawable(address(requester)) == 146_250_000);
        _assertTrue(escrow.withdrawable(address(verifier)) == 12_500_000);
        _assertTrue(escrow.withdrawable(address(agent)) == 0);
        _assertTrue(escrow.reserveBalance() == 1_250_000);
        _assertTrue(manager.openExposure() == 0);
    }

    function testExpiredNoSubmissionSlashesWithoutVerifierReward() public {
        bytes32 taskId = requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));
        agent.acceptTask(manager, taskId);
        agent.startTask(manager, taskId);
        vm.warp(block.timestamp + 2 days);
        requester.slashExpiredNoSubmission(manager, taskId);

        _assertStatus(taskId, AgentBondManager.TaskStatus.Slashed);
        _assertTrue(escrow.lockedByTask(taskId) == 0);
        _assertTrue(escrow.withdrawable(address(requester)) == 158_750_000);
        _assertTrue(escrow.withdrawable(address(verifier)) == 0);
        _assertTrue(escrow.withdrawable(address(agent)) == 0);
        _assertTrue(escrow.reserveBalance() == 1_250_000);
        _assertTrue(manager.openExposure() == 0);
    }

    function testUnsupportedReportRefundsWithoutSlashing() public {
        bytes32 taskId = _openAcceptedStartedTask(policyId, address(verifier));
        agent.commitEvidence(manager, taskId, keccak256("evidence.unsupported"), keccak256("availability.unsupported"), uint64(block.timestamp + 3 days));
        verifier.submitVerifierReport(
            manager,
            taskId,
            keccak256("report.unsupported"),
            AgentBondManager.ReportStatus.Unsupported,
            keccak256("digest.unsupported")
        );
        requester.settleTask(manager, taskId);

        _assertStatus(taskId, AgentBondManager.TaskStatus.Refunded);
        _assertTrue(escrow.lockedByTask(taskId) == 0);
        _assertTrue(escrow.withdrawable(address(requester)) == 125 * USDC);
        _assertTrue(escrow.withdrawable(address(agent)) == 25 * USDC);
        _assertTrue(escrow.withdrawable(address(verifier)) == 10 * USDC);
        _assertTrue(escrow.reserveBalance() == 0);
    }

    function testChallengeCanOverturnVerifierReportAndSlashVerifierStake() public {
        bytes32 taskId = _openAcceptedStartedTask(policyId, address(verifier));
        agent.commitEvidence(manager, taskId, keccak256("evidence.challenged"), keccak256("availability.challenged"), uint64(block.timestamp + 3 days));
        verifier.submitVerifierReport(
            manager,
            taskId,
            keccak256("report.challenged"),
            AgentBondManager.ReportStatus.Valid,
            keccak256("digest.challenged")
        );
        requester.challengeTask(manager, taskId, keccak256("challenge.validity"));
        manager.resolveChallenge(
            taskId,
            AgentBondManager.ReportStatus.Invalid,
            keccak256("resolution.overturned"),
            200,
            "fixture://task/resolution"
        );
        requester.settleTask(manager, taskId);

        _assertStatus(taskId, AgentBondManager.TaskStatus.Slashed);
        _assertTrue(escrow.lockedByTask(taskId) == 0);
        _assertTrue(escrow.withdrawable(address(requester)) == 206_250_000);
        _assertTrue(escrow.withdrawable(address(verifier)) == 2_500_000);
        _assertTrue(escrow.reserveBalance() == 1_250_000);
        _assertTrue(stakeRegistry.stakeOf(address(verifier)) == 19_600 * STAKE);
        _assertTrue(stakeToken.balanceOf(address(this)) == 400 * STAKE);
        _assertTrue(manager.openExposure() == 0);
    }

    function testChallengeRequiresNonzeroCommitment() public {
        bytes32 taskId = _openAcceptedStartedTask(policyId, address(verifier));
        agent.commitEvidence(manager, taskId, keccak256("evidence.challenge.zero"), keccak256("availability.challenge.zero"), uint64(block.timestamp + 3 days));
        verifier.submitVerifierReport(
            manager,
            taskId,
            keccak256("report.challenge.zero"),
            AgentBondManager.ReportStatus.Valid,
            keccak256("digest.challenge.zero")
        );

        vm.expectRevert(AgentBondManager.ZeroChallengeCommitment.selector);
        requester.challengeTask(manager, taskId, bytes32(0));
    }

    function testAcceptanceRequiresEligibleAgentStake() public {
        BondActor unstakedAgent = new BondActor();
        settlementToken.mint(address(unstakedAgent), 1_000 * USDC);
        unstakedAgent.approve(settlementToken, address(escrow), type(uint256).max);

        bytes32 taskId = requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));
        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.AgentNotEligible.selector, address(unstakedAgent)));
        unstakedAgent.acceptTask(manager, taskId);
    }

    function testEvidenceCommitmentRequiresTaskAgentAndAvailabilityWindow() public {
        bytes32 taskId = _openAcceptedStartedTask(policyId, address(verifier));

        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.NotTaskAgent.selector, address(requester), address(agent)));
        requester.commitEvidence(manager, taskId, keccak256("evidence.not-agent"), keccak256("availability.not-agent"), uint64(block.timestamp + 3 days));

        vm.expectRevert(AgentBondManager.ZeroEvidenceCommitment.selector);
        agent.commitEvidence(manager, taskId, bytes32(0), keccak256("availability.zero"), uint64(block.timestamp + 3 days));

        vm.expectRevert(AgentBondManager.ZeroAvailabilityCommitment.selector);
        agent.commitEvidence(manager, taskId, keccak256("evidence.zero"), bytes32(0), uint64(block.timestamp + 3 days));

        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.AvailabilityWindowTooShort.selector, uint256(block.timestamp) + 1 days, uint64(block.timestamp + 1 hours)));
        agent.commitEvidence(manager, taskId, keccak256("evidence.short"), keccak256("availability.short"), uint64(block.timestamp + 1 hours));
    }

    function testPilotModeEnforcesAllowlistsAndCaps() public {
        manager.setPilotMode(true);
        manager.setPilotCaps(100 * USDC, 160 * USDC, 1);

        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.RequesterNotAuthorized.selector, address(requester)));
        requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));

        manager.setRequesterAuthorization(address(requester), true);
        manager.setVerifierAuthorization(address(verifier), true);
        bytes32 taskId = requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));
        _assertTrue(manager.openExposure() == 135 * USDC);

        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.AgentNotAuthorized.selector, address(agent)));
        agent.acceptTask(manager, taskId);

        manager.setAgentAuthorization(address(agent), true);
        agent.acceptTask(manager, taskId);
        _assertTrue(manager.openExposure() == 160 * USDC);

        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.OpenTaskCapExceeded.selector, uint256(2), uint256(1)));
        requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));
    }

    function testPauseAndEmergencyStopProtectNewExposure() public {
        manager.setPaused(true);
        vm.expectRevert(AgentBondManager.Paused.selector);
        requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));

        manager.setPaused(false);
        bytes32 taskId = requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));
        agent.acceptTask(manager, taskId);
        manager.setEmergencyStopped(true);

        vm.expectRevert(AgentBondManager.Paused.selector);
        requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));

        vm.expectRevert(AgentBondManager.EmergencyStopped.selector);
        agent.startTask(manager, taskId);

        vm.expectRevert(AgentBondManager.EmergencyStopped.selector);
        agent.commitEvidence(manager, taskId, keccak256("evidence.blocked"), keccak256("availability.blocked"), uint64(block.timestamp + 3 days));
    }

    function testOpenTaskCanBeCanceledByRequesterBeforeAcceptance() public {
        bytes32 taskId = requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));
        requester.cancelOpenTask(manager, taskId);

        _assertStatus(taskId, AgentBondManager.TaskStatus.Refunded);
        _assertTrue(escrow.withdrawable(address(requester)) == 135 * USDC);
        _assertTrue(manager.openExposure() == 0);
        _assertTrue(manager.openTaskCount() == 0);
    }

    function testRejectsZeroTaskInputsAndInactivePolicy() public {
        vm.expectRevert(AgentBondManager.ZeroRootfieldId.selector);
        requester.openTask(manager, bytes32(0), policyId, termsHash, 100 * USDC, address(verifier));

        vm.expectRevert(AgentBondManager.ZeroPolicyId.selector);
        requester.openTask(manager, rootfieldId, bytes32(0), termsHash, 100 * USDC, address(verifier));

        vm.expectRevert(AgentBondManager.ZeroTermsHash.selector);
        requester.openTask(manager, rootfieldId, policyId, bytes32(0), 100 * USDC, address(verifier));

        vm.expectRevert(AgentBondManager.ZeroPayout.selector);
        requester.openTask(manager, rootfieldId, policyId, termsHash, 0, address(verifier));

        policyRegistry.setPolicyActive(policyId, false);
        vm.expectRevert(abi.encodeWithSelector(AgentBondManager.PolicyInactive.selector, policyId));
        requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier));
    }

    function _openAcceptedStartedTask(bytes32 selectedPolicyId, address verifierAddress) private returns (bytes32 taskId) {
        taskId = requester.openTask(manager, rootfieldId, selectedPolicyId, termsHash, 100 * USDC, verifierAddress);
        agent.acceptTask(manager, taskId);
        agent.startTask(manager, taskId);
    }

    function _policy(uint8 requiredConfirmations) private pure returns (TaskPolicyRegistry.TaskPolicy memory) {
        return TaskPolicyRegistry.TaskPolicy({
            agentBondBps: 1_000,
            verifierFeeBps: 200,
            requesterCancelBondBps: 500,
            disputeBondBps: 2_500,
            requiredConfirmations: requiredConfirmations,
            submissionWindow: 1 days,
            disputeWindow: 1 days,
            graceWindow: 1 hours,
            minAvailabilityWindow: 1 days,
            minAgentBond: 25 * USDC,
            minVerifierFee: 10 * USDC,
            minRequesterCancelBond: 25 * USDC,
            minDisputeBond: 50 * USDC,
            evidenceSchema: keccak256("flowmemory.task_bond_evidence.v1"),
            riskTier: 1,
            objectiveOnly: true,
            active: true
        });
    }

    function _assertStatus(bytes32 taskId, AgentBondManager.TaskStatus expected) private view {
        AgentBondManager.Task memory task = manager.getTask(taskId);
        _assertTrue(task.status == expected);
    }

    function _flowPulseWithType(AgentBondVm.Log[] memory logs, uint8 pulseType) private pure returns (bool) {
        for (uint256 index = 0; index < logs.length; index += 1) {
            if (logs[index].topics.length == 4 && logs[index].topics[0] == FLOWPULSE_SIGNATURE) {
                (
                    uint8 emittedType,
                    bytes32 subject,
                    bytes32 commitment,
                    bytes32 parentPulseId,
                    uint64 sequence,
                    uint64 occurredAt,
                    string memory uri
                ) = abi.decode(logs[index].data, (uint8, bytes32, bytes32, bytes32, uint64, uint64, string));
                subject;
                commitment;
                parentPulseId;
                sequence;
                occurredAt;
                uri;
                if (emittedType == pulseType) {
                    return true;
                }
            }
        }
        return false;
    }

    function _assertTrue(bool condition) private pure {
        if (!condition) revert AssertionFailed();
    }
}
