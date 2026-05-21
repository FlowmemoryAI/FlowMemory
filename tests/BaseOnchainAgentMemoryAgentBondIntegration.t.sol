// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseOnchainAgentMemory} from "../contracts/BaseOnchainAgentMemory.sol";
import {AgentBondManager} from "../contracts/AgentBondManager.sol";
import {AgentStakeRegistry} from "../contracts/AgentStakeRegistry.sol";
import {TaskBondEscrow} from "../contracts/TaskBondEscrow.sol";
import {TaskPolicyRegistry} from "../contracts/TaskPolicyRegistry.sol";

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

contract BondRequesterActor {
    function approve(LocalTestToken token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    function openTask(
        AgentBondManager manager,
        bytes32 rootfieldId,
        bytes32 policyId,
        bytes32 termsHash,
        uint256 payout,
        address verifier,
        string calldata uri
    ) external returns (bytes32) {
        return manager.openTask(rootfieldId, policyId, termsHash, payout, verifier, uri);
    }
}

contract BondVerifierActor {
    function approve(LocalTestToken token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    function depositStake(AgentStakeRegistry registry, uint256 amount) external {
        registry.depositStake(amount);
    }
}

contract AgentMemoryBondHarness is BaseOnchainAgentMemory {
    function approveToken(LocalTestToken token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    function depositStake(AgentStakeRegistry registry, uint256 amount) external {
        registry.depositStake(amount);
    }
}

contract BaseOnchainAgentMemoryAgentBondIntegrationTest {
    uint256 private constant USDC = 1_000_000;
    uint256 private constant STAKE = 1 ether;

    LocalTestToken private settlementToken;
    LocalTestToken private stakeToken;
    TaskBondEscrow private escrow;
    AgentStakeRegistry private stakeRegistry;
    TaskPolicyRegistry private policyRegistry;
    AgentBondManager private manager;
    AgentMemoryBondHarness private agentMemory;
    BondRequesterActor private requester;
    BondVerifierActor private verifier;

    bytes32 private rootfieldId;
    bytes32 private policyId;
    bytes32 private termsHash;
    bytes32 private agentId;

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

        requester = new BondRequesterActor();
        verifier = new BondVerifierActor();
        agentMemory = new AgentMemoryBondHarness();

        settlementToken.mint(address(requester), 1_000_000 * USDC);
        settlementToken.mint(address(agentMemory), 1_000_000 * USDC);
        stakeToken.mint(address(verifier), 100_000 * STAKE);
        stakeToken.mint(address(agentMemory), 100_000 * STAKE);

        requester.approve(settlementToken, address(escrow), type(uint256).max);
        verifier.approve(stakeToken, address(stakeRegistry), type(uint256).max);
        agentMemory.approveToken(settlementToken, address(escrow), type(uint256).max);
        agentMemory.approveToken(stakeToken, address(stakeRegistry), type(uint256).max);

        verifier.depositStake(stakeRegistry, 20_000 * STAKE);
        agentMemory.depositStake(stakeRegistry, 10_000 * STAKE);

        rootfieldId = keccak256("rootfield.agent-bonds.docs-review");
        policyId = keccak256("agent-bonds.docs-review.low-risk");
        termsHash = keccak256("task.terms.docs-review.v1");

        policyRegistry.createPolicy(policyId, TaskPolicyRegistry.TaskPolicy({
            agentBondBps: 1_000,
            verifierFeeBps: 800,
            requesterCancelBondBps: 200,
            disputeBondBps: 1_000,
            requiredConfirmations: 1,
            submissionWindow: 2 days,
            disputeWindow: 1 days,
            graceWindow: 1 days,
            minAvailabilityWindow: 1 days,
            minAgentBond: 25 * USDC,
            minVerifierFee: 10 * USDC,
            minRequesterCancelBond: 5 * USDC,
            minDisputeBond: 5 * USDC,
            evidenceSchema: keccak256("docs-review.public.v1"),
            riskTier: 1,
            objectiveOnly: true,
            active: true
        }));

        agentId = agentMemory.registerAgent({
            owner: address(this),
            rootfieldId: rootfieldId,
            policyRoot: keccak256("policy.docs-review.conservative"),
            toolAllowlistRoot: keccak256("allowlist.acceptTask"),
            initialMemoryRoot: keccak256("memory.initial"),
            activeGoal: keccak256("accept-low-risk-docs-review-tasks"),
            autonomyLevel: 2,
            kernelClass: agentMemory.TASK_SCOUT_KERNEL_CLASS(),
            salt: keccak256("agent-bond-integration"),
            uri: "fixture://agent/register"
        });

        agentMemory.setToolPolicy(
            agentId,
            agentMemory.ACCEPT_TASK_TOOL_ID(),
            BaseOnchainAgentMemory.ToolPolicy({
                target: address(manager),
                selector: agentMemory.ACCEPT_TASK_SELECTOR(),
                perActionValueCap: 0,
                epochValueCap: 0,
                maxTaskReward: 500 * USDC,
                enabled: true
            }),
            "fixture://tool/acceptTask"
        );
    }

    function testTaskScoutAcceptsAgentBondTaskThroughManager() public {
        bytes32 taskId = requester.openTask(manager, rootfieldId, policyId, termsHash, 100 * USDC, address(verifier), "fixture://task/open");

        BaseOnchainAgentMemory.TaskObservation memory observation = BaseOnchainAgentMemory.TaskObservation({
            taskId: taskId,
            taskKind: agentMemory.DOCS_REVIEW_TASK_KIND(),
            evidenceRequirement: agentMemory.PUBLIC_EVIDENCE_REQUIREMENT(),
            rewardAmount: 100 * USDC,
            deadline: 1_800_000,
            taskStatus: 1,
            recentFailureCount: 0,
            humanReviewRequired: false
        });

        BaseOnchainAgentMemory.StepPreview memory preview = agentMemory.previewStep(agentId, observation);
        _assertTrue(preview.action == BaseOnchainAgentMemory.AgentAction.AcceptTask);

        (bytes32 actionReceiptId, bytes32 newMemoryRoot) = agentMemory.step(agentId, observation, preview, "fixture://task/accept");
        AgentBondManager.Task memory task = manager.getTask(taskId);
        BaseOnchainAgentMemory.HotMemory memory hotMemory = agentMemory.getHotMemory(agentId);

        _assertTrue(actionReceiptId != bytes32(0));
        _assertTrue(newMemoryRoot != bytes32(0));
        _assertTrue(task.agent == address(agentMemory));
        _assertTrue(task.status == AgentBondManager.TaskStatus.Accepted);
        _assertTrue(hotMemory.lastActionReceiptId == actionReceiptId);
        _assertTrue(hotMemory.latestMemoryRoot == newMemoryRoot);
    }

    function _assertTrue(bool value) private pure {
        if (!value) revert AssertionFailed();
    }
}
