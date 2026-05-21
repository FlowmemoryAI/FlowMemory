// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseOnchainAgentMemory} from "../contracts/BaseOnchainAgentMemory.sol";
import {AgentClassRegistry} from "../contracts/public-agent-network/AgentClassRegistry.sol";
import {ToolRegistry} from "../contracts/public-agent-network/ToolRegistry.sol";
import {AgentProfileRegistry} from "../contracts/public-agent-network/AgentProfileRegistry.sol";
import {AgentLaunchBondEscrow} from "../contracts/public-agent-network/AgentLaunchBondEscrow.sol";
import {AgentMemoryFuelVault} from "../contracts/public-agent-network/AgentMemoryFuelVault.sol";
import {AgentLineageRegistry} from "../contracts/public-agent-network/AgentLineageRegistry.sol";
import {AgentFactory} from "../contracts/public-agent-network/AgentFactory.sol";
import {AgentLaunchHashing} from "../contracts/public-agent-network/lib/AgentLaunchHashing.sol";
import {AgentLaunchTypes} from "../contracts/public-agent-network/lib/AgentLaunchTypes.sol";

interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
    function prank(address caller) external;
    function expectRevert() external;
    function expectRevert(bytes4 revertData) external;
}

contract PublicIntegrationToken {
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

contract PublicAgentFactoryIntegrationTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant OWNER_PK = 0xA11CE;

    BaseOnchainAgentMemory private runtime;
    AgentClassRegistry private classRegistry;
    ToolRegistry private toolRegistry;
    AgentProfileRegistry private profileRegistry;
    AgentLaunchBondEscrow private bondEscrow;
    AgentMemoryFuelVault private fuelVault;
    AgentLineageRegistry private lineageRegistry;
    AgentFactory private factory;
    PublicIntegrationToken private token;
    address private ownerAccount;

    bytes32 private constant CLASS_ID = keccak256("TASK_SCOUT_V0");
    bytes32 private constant TOOL_ID = keccak256("tool.accept.task.v0");
    bytes32 private constant TOOL_SET_ROOT = keccak256("toolset.task-scout.v0");

    error AssertionFailed();

    function setUp() public {
        runtime = new BaseOnchainAgentMemory();
        classRegistry = new AgentClassRegistry(address(this));
        toolRegistry = new ToolRegistry(address(this));
        profileRegistry = new AgentProfileRegistry(address(this));
        bondEscrow = new AgentLaunchBondEscrow(address(this));
        fuelVault = new AgentMemoryFuelVault(address(this));
        lineageRegistry = new AgentLineageRegistry(address(this));
        token = new PublicIntegrationToken();
        factory = new AgentFactory(
            address(runtime),
            address(classRegistry),
            address(toolRegistry),
            address(profileRegistry),
            address(bondEscrow),
            address(fuelVault),
            address(lineageRegistry),
            address(this),
            address(this),
            1 minutes,
            7 days
        );

        ownerAccount = vm.addr(OWNER_PK);
        token.mint(ownerAccount, 1_000_000 ether);
        vm.prank(ownerAccount);
        token.approve(address(bondEscrow), type(uint256).max);
        vm.prank(ownerAccount);
        token.approve(address(fuelVault), type(uint256).max);

        classRegistry.registerClass(_classConfig());
        toolRegistry.registerTool(_tool());
        toolRegistry.registerToolSet(_toolSet());
        toolRegistry.setToolInToolSet(TOOL_SET_ROOT, TOOL_ID, true);
        toolRegistry.allowToolSetForClass(CLASS_ID, TOOL_SET_ROOT);

        bondEscrow.setApprovedBondToken(address(token), true);
        bondEscrow.setAuthorizedLocker(address(factory), true);
        bondEscrow.setBondPolicy(CLASS_ID, AgentLaunchTypes.BondPolicy({
            token: address(token),
            minAmount: 10 ether,
            maxAmount: 100 ether,
            minLockSeconds: 1 days,
            releaseDelaySeconds: 1 days,
            slashCapBps: 5_000,
            active: true
        }));

        fuelVault.setApprovedFuelToken(address(token), true);
        fuelVault.setAuthorizedRegistrar(address(factory), true);
        fuelVault.setAuthorizedMeter(address(this), true);
        fuelVault.setFuelPolicy(AgentMemoryFuelVault.FuelPolicy({
            classId: CLASS_ID,
            token: address(token),
            minInitialFuel: 5 ether,
            unitPrice: 1 ether,
            maxDebitPerStep: 3 ether,
            sponsorAllowed: true,
            active: true
        }));

        profileRegistry.setAuthorizedRegistrar(address(factory), true);
        lineageRegistry.setAuthorizedRegistrar(address(factory), true);
    }

    function testFactoryLaunchesAgentIntoRuntimeAndFundsState() public {
        AgentLaunchTypes.LaunchIntent memory intent = _launchIntent(bytes32(0), bytes32(0));
        bytes memory signature = _sign(intent);

        (bytes32 agentId, bytes32 launchId) = factory.launchAgent(
            intent,
            signature,
            AgentLaunchTypes.LaunchPayment({ sponsorMode: false, sponsor: address(0) })
        );

        BaseOnchainAgentMemory.AgentConfig memory agent = runtime.getAgent(agentId);
        AgentLaunchBondEscrow.Bond memory bond = bondEscrow.getBond(agentId);
        AgentMemoryFuelVault.FuelAccount memory fuelAccount = fuelVault.getFuelAccount(agentId);
        AgentLaunchTypes.AgentProfile memory profile = profileRegistry.getProfile(agentId);

        _assertTrue(agent.owner == ownerAccount);
        _assertTrue(agent.rootfieldId == intent.rootfieldId);
        _assertTrue(agent.policyRoot == intent.policyRoot);
        _assertTrue(agent.toolAllowlistRoot == intent.toolAllowlistRoot);
        _assertTrue(bond.amount == intent.bondAmount);
        _assertTrue(fuelAccount.balance == intent.initialFuelAmount);
        _assertTrue(profile.owner == ownerAccount);
        _assertTrue(factory.launchIdToAgentId(launchId) == agentId);
        _assertTrue(factory.nonces(ownerAccount) == 1);
    }

    function testFactoryLaunchRejectsBadSignatureAndNonceReuse() public {
        AgentLaunchTypes.LaunchIntent memory intent = _launchIntent(bytes32(0), bytes32(0));
        bytes memory signature = _sign(intent);
        signature[0] = bytes1(uint8(signature[0]) + 1);
        vm.expectRevert();
        factory.launchAgent(intent, signature, AgentLaunchTypes.LaunchPayment({ sponsorMode: false, sponsor: address(0) }));

        AgentLaunchTypes.LaunchIntent memory validIntent = _launchIntent(bytes32(0), bytes32(0));
        bytes memory validSignature = _sign(validIntent);
        factory.launchAgent(validIntent, validSignature, AgentLaunchTypes.LaunchPayment({ sponsorMode: false, sponsor: address(0) }));

        vm.expectRevert();
        factory.launchAgent(validIntent, validSignature, AgentLaunchTypes.LaunchPayment({ sponsorMode: false, sponsor: address(0) }));
    }

    function testFactoryAttachesLineageWhenParentProvided() public {
        bytes32 parentAgentId = keccak256("agent.parent");
        AgentLaunchTypes.LaunchIntent memory intent = _launchIntent(parentAgentId, bytes32(0));
        bytes memory signature = _sign(intent);

        (bytes32 agentId,) = factory.launchAgent(
            intent,
            signature,
            AgentLaunchTypes.LaunchPayment({ sponsorMode: false, sponsor: address(0) })
        );

        AgentLineageRegistry.Lineage memory lineage = lineageRegistry.getLineage(agentId);
        _assertTrue(lineage.parentAgentId == parentAgentId);
        _assertTrue(lineage.generation == 1);
    }

    function _launchIntent(bytes32 parentAgentId, bytes32 parentSwarmId)
        private
        view
        returns (AgentLaunchTypes.LaunchIntent memory)
    {
        return AgentLaunchTypes.LaunchIntent({
            owner: ownerAccount,
            operator: address(0),
            classId: CLASS_ID,
            rootfieldId: keccak256("rootfield.public.task-scout.alpha"),
            kernelClass: keccak256("flowmemory.kernel.task_scout.rule_scoring.v1"),
            policyRoot: keccak256("policy.public.task-scout.alpha"),
            toolAllowlistRoot: TOOL_SET_ROOT,
            initialMemoryRoot: keccak256("memory.public.task-scout.alpha"),
            activeGoalRoot: keccak256("goal.public.task-scout.alpha"),
            profileDigest: keccak256("profile.public.task-scout.alpha"),
            launchSpecRoot: keccak256("launch.public.task-scout.alpha"),
            autonomyLevel: 2,
            riskLevel: 1,
            parentAgentId: parentAgentId,
            parentSwarmId: parentSwarmId,
            bondToken: address(token),
            bondAmount: 10 ether,
            fuelToken: address(token),
            initialFuelAmount: 5 ether,
            discoverable: true,
            validAfter: uint64(block.timestamp),
            validUntil: uint64(block.timestamp + 1 days),
            nonce: factory.nonces(ownerAccount),
            salt: keccak256(abi.encode(ownerAccount, factory.nonces(ownerAccount)))
        });
    }

    function _sign(AgentLaunchTypes.LaunchIntent memory intent) private returns (bytes memory) {
        bytes32 digest = AgentLaunchHashing.launchIntentDigest(
            factory.EIP712_NAME(),
            factory.EIP712_VERSION(),
            block.chainid,
            address(factory),
            intent
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);
        return abi.encodePacked(r, s, v);
    }

    function _classConfig() private pure returns (AgentLaunchTypes.AgentClass memory) {
        return AgentLaunchTypes.AgentClass({
            classId: CLASS_ID,
            version: 1,
            active: true,
            deprecated: false,
            kernelClass: keccak256("flowmemory.kernel.task_scout.rule_scoring.v1"),
            schemaRoot: keccak256("schema.task-scout.v0"),
            defaultPolicyRoot: keccak256("policy.task-scout.v0"),
            allowedToolPolicyRoot: TOOL_SET_ROOT,
            pricingRoot: keccak256("pricing.task-scout.v0"),
            metadataDigest: keccak256("metadata.task-scout.v0"),
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
            toolId: TOOL_ID,
            version: 1,
            active: true,
            deprecated: false,
            category: keccak256("TASK_ACCEPT"),
            adapterDigest: keccak256("adapter.accept-task"),
            schemaRoot: keccak256("schema.accept-task"),
            policyRoot: keccak256("policy.accept-task"),
            metadataDigest: keccak256("metadata.accept-task"),
            riskTier: 2,
            mutating: true,
            requiresDryRun: true,
            requiresHumanConfirm: false,
            requiresExtraBond: false,
            compatibleKernelRoot: keccak256("flowmemory.kernel.task_scout.rule_scoring.v1")
        });
    }

    function _toolSet() private pure returns (AgentLaunchTypes.ToolSet memory) {
        return AgentLaunchTypes.ToolSet({
            toolSetRoot: TOOL_SET_ROOT,
            version: 1,
            active: true,
            maxRiskTier: 2,
            maxAutonomyLevel: 3,
            metadataDigest: keccak256("metadata.toolset.task-scout.v0")
        });
    }

    function _assertTrue(bool value) private pure {
        if (!value) revert AssertionFailed();
    }
}
