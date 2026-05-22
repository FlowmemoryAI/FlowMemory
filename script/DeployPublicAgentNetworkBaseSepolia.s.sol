// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseOnchainAgentMemory} from "../contracts/BaseOnchainAgentMemory.sol";
import {AgentClassRegistry} from "../contracts/public-agent-network/AgentClassRegistry.sol";
import {ToolRegistry} from "../contracts/public-agent-network/ToolRegistry.sol";
import {AgentProfileRegistry} from "../contracts/public-agent-network/AgentProfileRegistry.sol";
import {AgentLaunchBondEscrow} from "../contracts/public-agent-network/AgentLaunchBondEscrow.sol";
import {AgentMemoryFuelVault} from "../contracts/public-agent-network/AgentMemoryFuelVault.sol";
import {AgentLineageRegistry} from "../contracts/public-agent-network/AgentLineageRegistry.sol";
import {AgentReceiptAnchor} from "../contracts/public-agent-network/AgentReceiptAnchor.sol";
import {AgentFactory} from "../contracts/public-agent-network/AgentFactory.sol";
import {AgentShellFactory} from "../contracts/public-agent-network/shell/AgentShellFactory.sol";
import {SwarmPolicyRegistry} from "../contracts/public-agent-network/swarm/SwarmPolicyRegistry.sol";
import {SwarmRegistry} from "../contracts/public-agent-network/swarm/SwarmRegistry.sol";
import {SwarmBudgetVault} from "../contracts/public-agent-network/swarm/SwarmBudgetVault.sol";
import {SwarmFactory} from "../contracts/public-agent-network/swarm/SwarmFactory.sol";
import {AgentLaunchHashing} from "../contracts/public-agent-network/lib/AgentLaunchHashing.sol";
import {AgentLaunchTypes} from "../contracts/public-agent-network/lib/AgentLaunchTypes.sol";
import {SwarmTypes} from "../contracts/public-agent-network/lib/SwarmTypes.sol";

interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function envAddress(string calldata key) external returns (address);
    function envUint(string calldata key) external returns (uint256);
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract PublicNetworkBaseSepoliaToken {
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

/// @title DeployPublicAgentNetworkBaseSepolia
/// @notice Public testnet deployment script for the public agent + swarm stack.
/// @dev Requires BASE_SEPOLIA_DEPLOYER_KEY_HEX and BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS in local env.
/// It broadcasts only on Base Sepolia and verifies that the private key derives the declared deployer address.
contract DeployPublicAgentNetworkBaseSepolia {
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

    bytes32 internal constant CLASS_ID = keccak256("TASK_SCOUT_V0");
    bytes32 internal constant TOOL_ID = keccak256("tool.accept.task.v0");
    bytes32 internal constant TOOL_SET_ROOT = keccak256("toolset.task-scout.v0");
    bytes32 internal constant SWARM_CLASS = keccak256("RESEARCH_SWARM_V0");
    bytes32 internal constant SWARM_POLICY_ID = keccak256("policy.research-swarm.v0");

    error UnexpectedChain(uint256 expected, uint256 actual);
    error DeployerAddressMismatch(address expected, address derived);
    error ZeroConfiguredDeployer();

    struct Deployment {
        address deployer;
        address runtime;
        address classRegistry;
        address toolRegistry;
        address profileRegistry;
        address bondEscrow;
        address fuelVault;
        address lineageRegistry;
        address receiptAnchor;
        address shellFactory;
        address agentFactory;
        address swarmPolicyRegistry;
        address swarmRegistry;
        address swarmBudgetVault;
        address swarmFactory;
        address token;
        bytes32 agentId;
        bytes32 launchId;
        bytes32 swarmId;
        bytes32 budgetLineId;
        bytes32 reservationId;
        bytes32 receiptId;
    }

    event PublicAgentNetworkBaseSepoliaDeployed(
        address indexed deployer,
        address indexed agentFactory,
        address indexed swarmFactory,
        address runtime,
        address token,
        bytes32 agentId,
        bytes32 launchId,
        bytes32 swarmId,
        bytes32 budgetLineId,
        bytes32 reservationId,
        bytes32 receiptId
    );

    function run() external returns (Deployment memory deployment) {
        if (block.chainid != BASE_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(BASE_SEPOLIA_CHAIN_ID, block.chainid);
        }

        uint256 deployerPrivateKey = VM.envUint("BASE_SEPOLIA_DEPLOYER_KEY_HEX");
        address configuredDeployer = VM.envAddress("BASE_SEPOLIA_PUBLIC_AGENT_DEPLOYER_ADDRESS");
        if (configuredDeployer == address(0)) revert ZeroConfiguredDeployer();
        address derivedDeployer = VM.addr(deployerPrivateKey);
        if (derivedDeployer != configuredDeployer) {
            revert DeployerAddressMismatch(configuredDeployer, derivedDeployer);
        }

        VM.startBroadcast(deployerPrivateKey);

        BaseOnchainAgentMemory runtime = new BaseOnchainAgentMemory();
        AgentClassRegistry classRegistry = new AgentClassRegistry(configuredDeployer);
        ToolRegistry toolRegistry = new ToolRegistry(configuredDeployer);
        AgentProfileRegistry profileRegistry = new AgentProfileRegistry(configuredDeployer);
        AgentLaunchBondEscrow bondEscrow = new AgentLaunchBondEscrow(configuredDeployer);
        AgentMemoryFuelVault fuelVault = new AgentMemoryFuelVault(configuredDeployer);
        AgentLineageRegistry lineageRegistry = new AgentLineageRegistry(configuredDeployer);
        AgentReceiptAnchor receiptAnchor = new AgentReceiptAnchor(configuredDeployer);
        PublicNetworkBaseSepoliaToken token = new PublicNetworkBaseSepoliaToken();
        AgentFactory agentFactory = new AgentFactory(
            address(runtime),
            address(classRegistry),
            address(toolRegistry),
            address(profileRegistry),
            address(bondEscrow),
            address(fuelVault),
            address(lineageRegistry),
            configuredDeployer,
            configuredDeployer,
            1 minutes,
            7 days
        );
        AgentShellFactory shellFactory = new AgentShellFactory(address(runtime), configuredDeployer);

        SwarmPolicyRegistry swarmPolicyRegistry = new SwarmPolicyRegistry(configuredDeployer);
        SwarmRegistry swarmRegistry = new SwarmRegistry(configuredDeployer);
        SwarmBudgetVault swarmBudgetVault = new SwarmBudgetVault(configuredDeployer);
        SwarmFactory swarmFactory = new SwarmFactory(
            address(swarmPolicyRegistry),
            address(swarmRegistry),
            address(swarmBudgetVault),
            configuredDeployer
        );

        token.mint(configuredDeployer, 1_000_000 ether);
        token.approve(address(bondEscrow), type(uint256).max);
        token.approve(address(fuelVault), type(uint256).max);
        token.approve(address(swarmBudgetVault), type(uint256).max);

        classRegistry.registerClass(_classConfig());
        toolRegistry.registerTool(_tool());
        toolRegistry.registerToolSet(_toolSet());
        toolRegistry.setToolInToolSet(TOOL_SET_ROOT, TOOL_ID, true);
        toolRegistry.allowToolSetForClass(CLASS_ID, TOOL_SET_ROOT);

        bondEscrow.setApprovedBondToken(address(token), true);
        bondEscrow.setAuthorizedLocker(address(agentFactory), true);
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
        fuelVault.setAuthorizedRegistrar(address(agentFactory), true);
        fuelVault.setFuelPolicy(AgentMemoryFuelVault.FuelPolicy({
            classId: CLASS_ID,
            token: address(token),
            minInitialFuel: 5 ether,
            unitPrice: 1 ether,
            maxDebitPerStep: 3 ether,
            sponsorAllowed: true,
            active: true
        }));

        profileRegistry.setAuthorizedRegistrar(address(agentFactory), true);
        lineageRegistry.setAuthorizedRegistrar(address(agentFactory), true);
        receiptAnchor.setAuthorizedAttestor(configuredDeployer, true);
        shellFactory.setAuthorizedLauncher(configuredDeployer, true);

        AgentLaunchTypes.LaunchIntent memory launchIntent = _launchIntent(
            configuredDeployer,
            address(token),
            agentFactory.nonces(configuredDeployer)
        );
        (bytes32 agentId, bytes32 launchId) = agentFactory.launchAgent(
            launchIntent,
            _signLaunch(deployerPrivateKey, agentFactory, launchIntent),
            AgentLaunchTypes.LaunchPayment({sponsorMode: true, sponsor: configuredDeployer})
        );

        bytes32 receiptId = keccak256("receipt.public-network.base-sepolia.task-scout.v0");
        receiptAnchor.anchorReceipt(
            receiptId,
            agentId,
            keccak256("event.public-network.base-sepolia.task-scout.v0"),
            keccak256("root.receipt.public-network.base-sepolia.task-scout.v0"),
            launchIntent.initialMemoryRoot,
            keccak256("memory.public-network.base-sepolia.after-first-receipt"),
            1
        );

        swarmRegistry.setAuthorizedRegistrar(address(swarmFactory), true);
        swarmBudgetVault.setAuthorizedOperator(configuredDeployer, true);
        swarmPolicyRegistry.registerPolicy(SwarmTypes.SwarmPolicy({
            policyId: SWARM_POLICY_ID,
            swarmClass: SWARM_CLASS,
            admissionPolicyRoot: keccak256("admission.public-network.base-sepolia"),
            budgetPolicyRoot: keccak256("budget.public-network.base-sepolia"),
            rolePolicyRoot: keccak256("role.public-network.base-sepolia"),
            maxMemberRiskTier: 2,
            maxMembers: 10,
            active: true
        }));

        SwarmTypes.SwarmMember[] memory members = new SwarmTypes.SwarmMember[](2);
        members[0] = _walletMember(configuredDeployer);
        members[1] = _agentMember(agentId);
        bytes32 swarmId = swarmFactory.createSwarm(
            SWARM_POLICY_ID,
            _swarmIntent(configuredDeployer, address(token), swarmFactory.nonces(configuredDeployer)),
            members
        );
        bytes32 budgetLineId = swarmBudgetVault.createBudgetLine(
            swarmId,
            address(token),
            20 ether,
            keccak256("budget.public-network.base-sepolia.research"),
            keccak256("role.public-network.base-sepolia.researcher"),
            1 days
        );
        bytes32 reservationId = swarmBudgetVault.reserve(
            swarmId,
            budgetLineId,
            5 ether,
            keccak256("intent.public-network.base-sepolia.reservation")
        );
        swarmBudgetVault.releaseReservation(swarmId, budgetLineId, reservationId);
        swarmBudgetVault.spend(
            swarmId,
            budgetLineId,
            configuredDeployer,
            1 ether,
            keccak256("receipt.public-network.base-sepolia.spend")
        );

        deployment = Deployment({
            deployer: configuredDeployer,
            runtime: address(runtime),
            classRegistry: address(classRegistry),
            toolRegistry: address(toolRegistry),
            profileRegistry: address(profileRegistry),
            bondEscrow: address(bondEscrow),
            fuelVault: address(fuelVault),
            lineageRegistry: address(lineageRegistry),
            receiptAnchor: address(receiptAnchor),
            shellFactory: address(shellFactory),
            agentFactory: address(agentFactory),
            swarmPolicyRegistry: address(swarmPolicyRegistry),
            swarmRegistry: address(swarmRegistry),
            swarmBudgetVault: address(swarmBudgetVault),
            swarmFactory: address(swarmFactory),
            token: address(token),
            agentId: agentId,
            launchId: launchId,
            swarmId: swarmId,
            budgetLineId: budgetLineId,
            reservationId: reservationId,
            receiptId: receiptId
        });

        emit PublicAgentNetworkBaseSepoliaDeployed(
            deployment.deployer,
            deployment.agentFactory,
            deployment.swarmFactory,
            deployment.runtime,
            deployment.token,
            deployment.agentId,
            deployment.launchId,
            deployment.swarmId,
            deployment.budgetLineId,
            deployment.reservationId,
            deployment.receiptId
        );

        VM.stopBroadcast();
    }

    function _launchIntent(address ownerAccount, address token, uint64 nonce)
        private
        view
        returns (AgentLaunchTypes.LaunchIntent memory)
    {
        return AgentLaunchTypes.LaunchIntent({
            owner: ownerAccount,
            operator: address(0),
            classId: CLASS_ID,
            rootfieldId: keccak256("rootfield.public-network.base-sepolia"),
            kernelClass: keccak256("flowmemory.kernel.task_scout.rule_scoring.v1"),
            policyRoot: keccak256("policy.public-network.base-sepolia"),
            toolAllowlistRoot: TOOL_SET_ROOT,
            initialMemoryRoot: keccak256("memory.public-network.base-sepolia.initial"),
            activeGoalRoot: keccak256("goal.public-network.base-sepolia"),
            profileDigest: keccak256("profile.public-network.base-sepolia"),
            launchSpecRoot: keccak256("launch.public-network.base-sepolia"),
            autonomyLevel: 2,
            riskLevel: 1,
            parentAgentId: bytes32(0),
            parentSwarmId: bytes32(0),
            bondToken: token,
            bondAmount: 10 ether,
            fuelToken: token,
            initialFuelAmount: 5 ether,
            discoverable: true,
            validAfter: uint64(block.timestamp),
            validUntil: uint64(block.timestamp + 1 days),
            nonce: nonce,
            salt: keccak256("public-network.base-sepolia.agent")
        });
    }

    function _swarmIntent(address sponsor, address token, uint64 nonce) private view returns (SwarmTypes.SwarmIntent memory) {
        return SwarmTypes.SwarmIntent({
            creator: sponsor,
            swarmClass: SWARM_CLASS,
            missionRoot: keccak256("mission.public-network.base-sepolia"),
            sharedMemoryRoot: keccak256("shared-memory.public-network.base-sepolia"),
            policyRoot: keccak256("policy.public-network.base-sepolia.swarm"),
            roleRoot: keccak256("roles.public-network.base-sepolia"),
            profileDigest: keccak256("profile.public-network.base-sepolia.swarm"),
            budgetAsset: token,
            initialBudget: 100 ether,
            validAfter: uint64(block.timestamp),
            validUntil: uint64(block.timestamp + 1 days),
            nonce: nonce,
            parentSwarmId: bytes32(0),
            salt: keccak256("public-network.base-sepolia.swarm")
        });
    }

    function _signLaunch(uint256 deployerPrivateKey, AgentFactory agentFactory, AgentLaunchTypes.LaunchIntent memory intent)
        private
        returns (bytes memory)
    {
        bytes32 digest = AgentLaunchHashing.launchIntentDigest(
            agentFactory.EIP712_NAME(),
            agentFactory.EIP712_VERSION(),
            block.chainid,
            address(agentFactory),
            intent
        );
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(deployerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _walletMember(address wallet) private view returns (SwarmTypes.SwarmMember memory) {
        return SwarmTypes.SwarmMember({
            memberType: SwarmTypes.MemberType.Wallet,
            wallet: wallet,
            agentId: bytes32(0),
            childSwarmId: bytes32(0),
            shell: address(0),
            role: keccak256("founder"),
            permissionsRoot: keccak256("permissions.public-network.base-sepolia.founder"),
            weight: 100,
            active: true,
            joinedAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp)
        });
    }

    function _agentMember(bytes32 agentId) private view returns (SwarmTypes.SwarmMember memory) {
        return SwarmTypes.SwarmMember({
            memberType: SwarmTypes.MemberType.Agent,
            wallet: address(0),
            agentId: agentId,
            childSwarmId: bytes32(0),
            shell: address(0),
            role: keccak256("task-scout"),
            permissionsRoot: keccak256("permissions.public-network.base-sepolia.task-scout"),
            weight: 50,
            active: true,
            joinedAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp)
        });
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
}
