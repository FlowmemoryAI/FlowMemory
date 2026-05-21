// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SwarmPolicyRegistry} from "../contracts/public-agent-network/swarm/SwarmPolicyRegistry.sol";
import {SwarmRegistry} from "../contracts/public-agent-network/swarm/SwarmRegistry.sol";
import {SwarmBudgetVault} from "../contracts/public-agent-network/swarm/SwarmBudgetVault.sol";
import {SwarmFactory} from "../contracts/public-agent-network/swarm/SwarmFactory.sol";
import {SwarmTypes} from "../contracts/public-agent-network/lib/SwarmTypes.sol";

contract SwarmTestToken {
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

contract SwarmPayoutRecipient {}

contract PublicSwarmNetworkTest {
    SwarmPolicyRegistry private policyRegistry;
    SwarmRegistry private registry;
    SwarmBudgetVault private budgetVault;
    SwarmFactory private factory;
    SwarmTestToken private token;
    SwarmPayoutRecipient private recipient;

    error AssertionFailed();

    function setUp() public {
        policyRegistry = new SwarmPolicyRegistry(address(this));
        registry = new SwarmRegistry(address(this));
        budgetVault = new SwarmBudgetVault(address(this));
        factory = new SwarmFactory(address(policyRegistry), address(registry), address(budgetVault), address(this));
        token = new SwarmTestToken();
        recipient = new SwarmPayoutRecipient();

        registry.setAuthorizedRegistrar(address(factory), true);
        budgetVault.setAuthorizedOperator(address(this), true);

        token.mint(address(this), 1_000_000 ether);
        token.approve(address(budgetVault), type(uint256).max);

        policyRegistry.registerPolicy(SwarmTypes.SwarmPolicy({
            policyId: keccak256("policy.research-swarm.v0"),
            swarmClass: keccak256("RESEARCH_SWARM_V0"),
            admissionPolicyRoot: keccak256("admission.root"),
            budgetPolicyRoot: keccak256("budget.root"),
            rolePolicyRoot: keccak256("role.root"),
            maxMemberRiskTier: 2,
            maxMembers: 10,
            active: true
        }));
    }

    function testFactoryCreatesSwarmAndDepositsBudget() public {
        SwarmTypes.SwarmIntent memory intent = SwarmTypes.SwarmIntent({
            creator: address(this),
            swarmClass: keccak256("RESEARCH_SWARM_V0"),
            missionRoot: keccak256("mission.root"),
            sharedMemoryRoot: keccak256("shared.memory.root"),
            policyRoot: keccak256("policy.root"),
            roleRoot: keccak256("role.root"),
            profileDigest: keccak256("profile.digest"),
            budgetAsset: address(token),
            initialBudget: 100 ether,
            validAfter: uint64(block.timestamp),
            validUntil: uint64(block.timestamp + 1 days),
            nonce: 0,
            parentSwarmId: bytes32(0),
            salt: keccak256("swarm.salt")
        });
        SwarmTypes.SwarmMember[] memory initialMembers = new SwarmTypes.SwarmMember[](1);
        initialMembers[0] = SwarmTypes.SwarmMember({
            memberType: SwarmTypes.MemberType.Wallet,
            wallet: address(this),
            agentId: bytes32(0),
            childSwarmId: bytes32(0),
            shell: address(0),
            role: keccak256("founder"),
            permissionsRoot: keccak256("founder.permissions"),
            weight: 100,
            active: true,
            joinedAt: 0,
            updatedAt: 0
        });

        bytes32 swarmId = factory.createSwarm(keccak256("policy.research-swarm.v0"), intent, initialMembers);
        SwarmTypes.Swarm memory swarm = registry.getSwarm(swarmId);
        _assertTrue(swarm.creator == address(this));
        _assertTrue(swarm.budgetVault == address(budgetVault));
        _assertTrue(budgetVault.swarmBalances(swarmId, address(token)) == 100 ether);
    }

    function testSwarmRegistrySupportsMembershipAndLifecycle() public {
        bytes32 swarmId = keccak256("swarm.alpha");
        SwarmTypes.Swarm memory swarm = SwarmTypes.Swarm({
            swarmId: swarmId,
            creator: address(this),
            swarmClass: keccak256("RESEARCH_SWARM_V0"),
            missionRoot: keccak256("mission.root"),
            sharedMemoryRoot: keccak256("shared.memory.root"),
            policyRoot: keccak256("policy.root"),
            roleRoot: keccak256("role.root"),
            profileDigest: keccak256("profile.digest"),
            status: SwarmTypes.SwarmStatus.Active,
            budgetVault: address(budgetVault),
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp),
            generation: 0,
            parentSwarmId: bytes32(0)
        });
        SwarmTypes.SwarmMember[] memory none = new SwarmTypes.SwarmMember[](0);
        registry.setAuthorizedRegistrar(address(this), true);
        registry.createSwarm(swarm, none);

        registry.joinSwarm(
            swarmId,
            SwarmTypes.SwarmMember({
                memberType: SwarmTypes.MemberType.Agent,
                wallet: address(0),
                agentId: keccak256("agent.alpha"),
                childSwarmId: bytes32(0),
                shell: address(0),
                role: keccak256("researcher"),
                permissionsRoot: keccak256("researcher.permissions"),
                weight: 50,
                active: true,
                joinedAt: 0,
                updatedAt: 0
            }),
            ""
        );
        bytes32[] memory memberKeys = registry.getMemberKeys(swarmId);
        _assertTrue(memberKeys.length == 1);

        registry.updateMissionRoot(swarmId, keccak256("mission.root.v2"), keccak256("goal.shift"));
        registry.updateSharedMemoryRoot(swarmId, keccak256("shared.memory.root.v2"), keccak256("receipt.root"));
        registry.pauseSwarm(swarmId, keccak256("pause.reason"));
        registry.dissolveSwarm(swarmId, keccak256("final.memory.root"), keccak256("final.receipt.root"));
        SwarmTypes.Swarm memory dissolved = registry.getSwarm(swarmId);
        _assertTrue(dissolved.status == SwarmTypes.SwarmStatus.Dissolved);
    }

    function testSwarmBudgetVaultCreatesLinesAndSpendsWithinCaps() public {
        bytes32 swarmId = keccak256("swarm.budget");
        budgetVault.deposit(swarmId, address(this), address(token), 100 ether);
        bytes32 budgetLineId = budgetVault.createBudgetLine(
            swarmId,
            address(token),
            50 ether,
            keccak256("purpose.root"),
            keccak256("role.policy.root"),
            1 days
        );
        bytes32 reservationId = budgetVault.reserve(swarmId, budgetLineId, 20 ether, keccak256("intent.root"));
        budgetVault.releaseReservation(swarmId, budgetLineId, reservationId);
        budgetVault.spend(swarmId, budgetLineId, address(recipient), 10 ether, keccak256("receipt.root"));
        SwarmBudgetVault.BudgetLine memory line = budgetVault.getBudgetLine(budgetLineId);
        _assertTrue(line.spent == 10 ether);
        _assertTrue(token.balanceOf(address(recipient)) == 10 ether);
    }

    function _assertTrue(bool value) private pure {
        if (!value) revert AssertionFailed();
    }
}
