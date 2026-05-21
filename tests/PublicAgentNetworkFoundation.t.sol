// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentClassRegistry} from "../contracts/public-agent-network/AgentClassRegistry.sol";
import {ToolRegistry} from "../contracts/public-agent-network/ToolRegistry.sol";
import {AgentProfileRegistry} from "../contracts/public-agent-network/AgentProfileRegistry.sol";
import {AgentLaunchBondEscrow} from "../contracts/public-agent-network/AgentLaunchBondEscrow.sol";
import {AgentMemoryFuelVault} from "../contracts/public-agent-network/AgentMemoryFuelVault.sol";
import {AgentLineageRegistry} from "../contracts/public-agent-network/AgentLineageRegistry.sol";
import {AgentReceiptAnchor} from "../contracts/public-agent-network/AgentReceiptAnchor.sol";
import {AgentLaunchTypes} from "../contracts/public-agent-network/lib/AgentLaunchTypes.sol";

interface Vm {
    function warp(uint256 newTimestamp) external;
    function expectRevert() external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
}

contract PublicTestToken {
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

contract TokenActor {
    function approve(PublicTestToken token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }
}

contract PublicAgentNetworkFoundationTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    AgentClassRegistry private classRegistry;
    ToolRegistry private toolRegistry;
    AgentProfileRegistry private profileRegistry;
    AgentLaunchBondEscrow private bondEscrow;
    AgentMemoryFuelVault private fuelVault;
    AgentLineageRegistry private lineageRegistry;
    AgentReceiptAnchor private receiptAnchor;
    PublicTestToken private token;
    TokenActor private ownerActor;
    TokenActor private sponsorActor;

    error AssertionFailed();

    function setUp() public {
        classRegistry = new AgentClassRegistry(address(this));
        toolRegistry = new ToolRegistry(address(this));
        profileRegistry = new AgentProfileRegistry(address(this));
        bondEscrow = new AgentLaunchBondEscrow(address(this));
        fuelVault = new AgentMemoryFuelVault(address(this));
        lineageRegistry = new AgentLineageRegistry(address(this));
        receiptAnchor = new AgentReceiptAnchor(address(this));
        token = new PublicTestToken();
        ownerActor = new TokenActor();
        sponsorActor = new TokenActor();

        token.mint(address(ownerActor), 1_000_000 ether);
        token.mint(address(sponsorActor), 1_000_000 ether);
        ownerActor.approve(token, address(bondEscrow), type(uint256).max);
        ownerActor.approve(token, address(fuelVault), type(uint256).max);
        sponsorActor.approve(token, address(bondEscrow), type(uint256).max);
        sponsorActor.approve(token, address(fuelVault), type(uint256).max);

        bondEscrow.setApprovedBondToken(address(token), true);
        bondEscrow.setAuthorizedLocker(address(this), true);
        fuelVault.setApprovedFuelToken(address(token), true);
        fuelVault.setAuthorizedRegistrar(address(this), true);
        fuelVault.setAuthorizedMeter(address(this), true);
        profileRegistry.setAuthorizedRegistrar(address(this), true);
        lineageRegistry.setAuthorizedRegistrar(address(this), true);
        receiptAnchor.setAuthorizedAttestor(address(this), true);
    }

    function testClassRegistrySupportsRegisterUpdateAndDeprecation() public {
        AgentLaunchTypes.AgentClass memory config = _classConfig();
        classRegistry.registerClass(config);
        _assertTrue(classRegistry.isLaunchable(config.classId));

        config.version = 2;
        config.metadataDigest = keccak256("class.metadata.v2");
        classRegistry.updateClass(config.classId, config);
        AgentLaunchTypes.AgentClass memory stored = classRegistry.getClass(config.classId);
        _assertTrue(stored.version == 2);
        _assertTrue(stored.metadataDigest == keccak256("class.metadata.v2"));

        classRegistry.deprecateClass(config.classId, keccak256("class.deprecated"));
        _assertTrue(!classRegistry.isLaunchable(config.classId));
    }

    function testToolRegistryValidatesToolSetForClass() public {
        AgentLaunchTypes.Tool memory tool = _tool();
        toolRegistry.registerTool(tool);
        AgentLaunchTypes.ToolSet memory toolSet = AgentLaunchTypes.ToolSet({
            toolSetRoot: keccak256("toolset.task-scout"),
            version: 1,
            active: true,
            maxRiskTier: 2,
            maxAutonomyLevel: 3,
            metadataDigest: keccak256("toolset.metadata")
        });
        toolRegistry.registerToolSet(toolSet);
        toolRegistry.setToolInToolSet(toolSet.toolSetRoot, tool.toolId, true);
        toolRegistry.allowToolSetForClass(_classId(), toolSet.toolSetRoot);
        _assertTrue(toolRegistry.validateToolSetForClass(_classId(), toolSet.toolSetRoot, 2));
        _assertTrue(!toolRegistry.validateToolSetForClass(_classId(), toolSet.toolSetRoot, 4));
    }

    function testProfileRegistryClaimsAndProtectsHandle() public {
        bytes32 agentId = keccak256("agent.alpha");
        profileRegistry.setProfile(
            agentId,
            address(ownerActor),
            keccak256("profile.digest"),
            keccak256("profile.metadata"),
            keccak256("profile.tags"),
            keccak256("profile.avatar"),
            keccak256("handle.alpha"),
            true
        );
        AgentLaunchTypes.AgentProfile memory profile = profileRegistry.getProfile(agentId);
        _assertTrue(profile.owner == address(ownerActor));
        _assertTrue(profile.handleHash == keccak256("handle.alpha"));

        vm.expectRevert();
        profileRegistry.setProfile(
            keccak256("agent.beta"),
            address(sponsorActor),
            keccak256("profile.digest.beta"),
            keccak256("profile.metadata.beta"),
            keccak256("profile.tags.beta"),
            keccak256("profile.avatar.beta"),
            keccak256("handle.alpha"),
            true
        );
    }

    function testBondEscrowLocksReleasesAndSlashes() public {
        bytes32 classId = _classId();
        bondEscrow.setBondPolicy(classId, AgentLaunchTypes.BondPolicy({
            token: address(token),
            minAmount: 10 ether,
            maxAmount: 100 ether,
            minLockSeconds: 1 days,
            releaseDelaySeconds: 1 days,
            slashCapBps: 5_000,
            active: true
        }));

        bytes32 agentId = keccak256("agent.bonded");
        bondEscrow.lockLaunchBond(agentId, address(ownerActor), address(this), classId, address(token), 20 ether, keccak256("policy.root"));
        vm.expectRevert();
        bondEscrow.releaseBond(agentId);

        vm.warp(block.timestamp + 1 days + 1);
        bondEscrow.requestRelease(agentId);
        vm.warp(block.timestamp + 1 days + 1);
        bondEscrow.releaseBond(agentId);
        _assertTrue(token.balanceOf(address(this)) == 20 ether);

        bytes32 slashedAgentId = keccak256("agent.slashed");
        bondEscrow.lockLaunchBond(slashedAgentId, address(sponsorActor), address(this), classId, address(token), 20 ether, keccak256("policy.root"));
        bondEscrow.slashBond(slashedAgentId, 10 ether, keccak256("spam"), keccak256("evidence.root"));
        AgentLaunchBondEscrow.Bond memory bond = bondEscrow.getBond(slashedAgentId);
        _assertTrue(bond.amount == 10 ether);
    }

    function testFuelVaultRegistersDepositsReservesConsumesAndRefunds() public {
        bytes32 classId = _classId();
        fuelVault.setFuelPolicy(AgentMemoryFuelVault.FuelPolicy({
            classId: classId,
            token: address(token),
            minInitialFuel: 5 ether,
            unitPrice: 1 ether,
            maxDebitPerStep: 3 ether,
            sponsorAllowed: true,
            active: true
        }));

        bytes32 agentId = keccak256("agent.fuel");
        fuelVault.registerFuelAccount(agentId, address(ownerActor), classId, address(token));
        fuelVault.depositFuel(agentId, address(ownerActor), address(token), 10 ether);
        fuelVault.reserveFuel(agentId, 2 ether, keccak256("reservation.root"));
        fuelVault.releaseReservation(agentId, keccak256("reservation.root"));
        fuelVault.consumeFuel(agentId, 3, keccak256("receipt.root"));
        fuelVault.refundFuel(agentId, address(ownerActor), 2 ether);
        AgentMemoryFuelVault.FuelAccount memory account = fuelVault.getFuelAccount(agentId);
        _assertTrue(account.balance == 5 ether);
        _assertTrue(account.reserved == 0);
    }

    function testLineageRegistryAndReceiptAnchorStoreReplayState() public {
        bytes32 childAgentId = keccak256("agent.child");
        bytes32 parentAgentId = keccak256("agent.parent");
        lineageRegistry.attachLineage(
            childAgentId,
            AgentLaunchTypes.ParentType.Agent,
            parentAgentId,
            bytes32(0),
            address(0),
            keccak256("lineage.root"),
            1
        );
        AgentLineageRegistry.Lineage memory lineage = lineageRegistry.getLineage(childAgentId);
        _assertTrue(lineage.parentAgentId == parentAgentId);
        _assertTrue(lineage.generation == 1);
        _assertTrue(lineageRegistry.getAgentChildren(parentAgentId).length == 1);

        bytes32 receiptId = keccak256("receipt.anchor");
        receiptAnchor.anchorReceipt(
            receiptId,
            childAgentId,
            keccak256("event.root"),
            keccak256("receipt.root"),
            keccak256("previous.root"),
            keccak256("new.root"),
            1
        );
        AgentReceiptAnchor.ReceiptAnchor memory anchor = receiptAnchor.getReceipt(receiptId);
        _assertTrue(anchor.agentId == childAgentId);
        _assertTrue(anchor.receiptRoot == keccak256("receipt.root"));
    }

    function _classId() private pure returns (bytes32) {
        return keccak256("TASK_SCOUT_V0");
    }

    function _classConfig() private pure returns (AgentLaunchTypes.AgentClass memory) {
        return AgentLaunchTypes.AgentClass({
            classId: _classId(),
            version: 1,
            active: true,
            deprecated: false,
            kernelClass: keccak256("flowmemory.kernel.task_scout.rule_scoring.v1"),
            schemaRoot: keccak256("schema.root"),
            defaultPolicyRoot: keccak256("policy.root"),
            allowedToolPolicyRoot: keccak256("tool.policy.root"),
            pricingRoot: keccak256("pricing.root"),
            metadataDigest: keccak256("metadata.root"),
            minAutonomyLevel: 1,
            maxAutonomyLevel: 3,
            maxToolRiskTier: 2,
            maxTools: 4,
            minLaunchBond: 10 ether,
            minMemoryFuel: 5 ether,
            allowPublicLaunch: true,
            allowSwarmMembership: true,
            allowShellGraduation: false
        });
    }

    function _tool() private pure returns (AgentLaunchTypes.Tool memory) {
        return AgentLaunchTypes.Tool({
            toolId: keccak256("tool.accept.task.v0"),
            version: 1,
            active: true,
            deprecated: false,
            category: keccak256("TASK_ACCEPT"),
            adapterDigest: keccak256("adapter.digest"),
            schemaRoot: keccak256("tool.schema.root"),
            policyRoot: keccak256("tool.policy.root"),
            metadataDigest: keccak256("tool.metadata.root"),
            riskTier: 2,
            mutating: true,
            requiresDryRun: true,
            requiresHumanConfirm: false,
            requiresExtraBond: false,
            compatibleKernelRoot: keccak256("flowmemory.kernel.task_scout.rule_scoring.v1")
        });
    }

    function _assertTrue(bool value) private pure {
        if (!value) revert AssertionFailed();
    }
}
