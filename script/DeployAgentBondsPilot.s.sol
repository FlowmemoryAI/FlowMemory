// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentBondManager} from "../contracts/AgentBondManager.sol";
import {AgentBondTimelockedMultisig} from "../contracts/AgentBondTimelockedMultisig.sol";
import {AgentStakeRegistry} from "../contracts/AgentStakeRegistry.sol";
import {TaskBondEscrow} from "../contracts/TaskBondEscrow.sol";
import {TaskPolicyRegistry} from "../contracts/TaskPolicyRegistry.sol";

interface AgentBondDeployVm {
    function startBroadcast(address signer) external;
    function stopBroadcast() external;
    function envAddress(string calldata key) external returns (address value);
    function envBool(string calldata key) external returns (bool value);
    function envOr(string calldata key, bool defaultValue) external returns (bool value);
    function envUint(string calldata key) external returns (uint256 value);
}

/// @title DeployAgentBondsPilot
/// @notice Foundry deployment script for a capped Agent Bonds pilot.
/// @dev This is a production-shaped deployment path for a capped pilot only. It is not an uncapped public launch script.
contract DeployAgentBondsPilot {
    AgentBondDeployVm private constant VM = AgentBondDeployVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant LOCAL_ANVIL_CHAIN_ID = 31_337;
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint256 internal constant BASE_MAINNET_CHAIN_ID = 8_453;

    struct Config {
        address broadcaster;
        address owner;
        address pauseGuardian;
        address resolutionAuthority;
        address settlementToken;
        address stakeToken;
        address requester;
        address agent;
        address verifier;
        address confirmingVerifier;
        address multisigOwner1;
        address multisigOwner2;
        address multisigOwner3;
        uint256 multisigThreshold;
        uint64 multisigMinDelay;
        uint256 minAgentStake;
        uint256 minVerifierStake;
        uint256 capacityUnit;
        uint256 capacityBondUnit;
        uint256 maxPayoutPerTask;
        uint256 maxOpenExposure;
        uint256 maxOpenTasks;
        uint16 agentBondBps;
        uint16 verifierFeeBps;
        uint16 requesterCancelBondBps;
        uint16 disputeBondBps;
        uint8 requiredConfirmations;
        uint64 submissionWindow;
        uint64 disputeWindow;
        uint64 graceWindow;
        uint64 minAvailabilityWindow;
        uint256 minAgentBond;
        uint256 minVerifierFee;
        uint256 minRequesterCancelBond;
        uint256 minDisputeBond;
        bytes32 evidenceSchema;
        uint8 riskTier;
        bool base8453PilotAck;
    }

    struct Deployment {
        address multisig;
        address escrow;
        address stakeRegistry;
        address policyRegistry;
        address manager;
        uint256 chainId;
        bytes32 policyId;
    }

    error UnsupportedDeploymentChain(uint256 chainId);
    error Base8453PilotAckRequired();
    error ZeroConfigAddress(string field);
    error InvalidThreshold();
    error RequiredConfirmationsMissing();

    event AgentBondsPilotDeployed(
        address indexed manager,
        bytes32 indexed policyId,
        uint256 chainId,
        address owner,
        address pendingMultisigOwner,
        address pauseGuardian,
        address resolutionAuthority
    );

    function run() external returns (Deployment memory deployment) {
        Config memory config = _readConfig();
        uint256 chainId = _enforceDeploymentGate(config);
        _validateConfig(config);
        bytes32 policyId = keccak256("flowmemory.agent_bonds.pilot.policy.v1");

        VM.startBroadcast(config.broadcaster);

        address[] memory multisigOwners = new address[](3);
        multisigOwners[0] = config.multisigOwner1;
        multisigOwners[1] = config.multisigOwner2;
        multisigOwners[2] = config.multisigOwner3;
        AgentBondTimelockedMultisig multisig =
            new AgentBondTimelockedMultisig(multisigOwners, config.multisigThreshold, config.multisigMinDelay);

        TaskBondEscrow escrow = new TaskBondEscrow(config.settlementToken, config.owner);
        AgentStakeRegistry stakeRegistry = new AgentStakeRegistry(
            config.stakeToken,
            config.owner,
            config.minAgentStake,
            config.minVerifierStake,
            config.capacityUnit,
            config.capacityBondUnit
        );
        TaskPolicyRegistry policyRegistry = new TaskPolicyRegistry(config.owner);
        AgentBondManager manager = new AgentBondManager(
            address(escrow),
            address(stakeRegistry),
            address(policyRegistry),
            config.owner,
            config.pauseGuardian,
            config.resolutionAuthority
        );

        escrow.setManager(address(manager));
        stakeRegistry.setSlashAuthority(address(manager));
        policyRegistry.createPolicy(policyId, TaskPolicyRegistry.TaskPolicy({
            agentBondBps: config.agentBondBps,
            verifierFeeBps: config.verifierFeeBps,
            requesterCancelBondBps: config.requesterCancelBondBps,
            disputeBondBps: config.disputeBondBps,
            requiredConfirmations: config.requiredConfirmations,
            submissionWindow: config.submissionWindow,
            disputeWindow: config.disputeWindow,
            graceWindow: config.graceWindow,
            minAvailabilityWindow: config.minAvailabilityWindow,
            minAgentBond: config.minAgentBond,
            minVerifierFee: config.minVerifierFee,
            minRequesterCancelBond: config.minRequesterCancelBond,
            minDisputeBond: config.minDisputeBond,
            evidenceSchema: config.evidenceSchema,
            riskTier: config.riskTier,
            objectiveOnly: true,
            active: true
        }));

        manager.setPilotMode(true);
        manager.setPilotCaps(config.maxPayoutPerTask, config.maxOpenExposure, config.maxOpenTasks);
        manager.setRequesterAuthorization(config.requester, true);
        manager.setAgentAuthorization(config.agent, true);
        manager.setVerifierAuthorization(config.verifier, true);
        manager.setVerifierAuthorization(config.confirmingVerifier, true);

        escrow.transferOwnership(address(multisig));
        stakeRegistry.transferOwnership(address(multisig));
        policyRegistry.transferOwnership(address(multisig));
        manager.transferOwnership(address(multisig));

        deployment = Deployment({
            multisig: address(multisig),
            escrow: address(escrow),
            stakeRegistry: address(stakeRegistry),
            policyRegistry: address(policyRegistry),
            manager: address(manager),
            chainId: chainId,
            policyId: policyId
        });

        emit AgentBondsPilotDeployed(
            deployment.manager,
            policyId,
            chainId,
            config.owner,
            address(multisig),
            config.pauseGuardian,
            config.resolutionAuthority
        );

        VM.stopBroadcast();
    }

    function _readConfig() private returns (Config memory config) {
        config = Config({
            broadcaster: VM.envAddress("FLOWMEMORY_AGENT_BONDS_BROADCASTER"),
            owner: VM.envAddress("FLOWMEMORY_AGENT_BONDS_OWNER"),
            pauseGuardian: VM.envAddress("FLOWMEMORY_AGENT_BONDS_PAUSE_GUARDIAN"),
            resolutionAuthority: VM.envAddress("FLOWMEMORY_AGENT_BONDS_RESOLUTION_AUTHORITY"),
            settlementToken: VM.envAddress("FLOWMEMORY_AGENT_BONDS_SETTLEMENT_TOKEN"),
            stakeToken: VM.envAddress("FLOWMEMORY_AGENT_BONDS_STAKE_TOKEN"),
            requester: VM.envAddress("FLOWMEMORY_AGENT_BONDS_REQUESTER"),
            agent: VM.envAddress("FLOWMEMORY_AGENT_BONDS_AGENT"),
            verifier: VM.envAddress("FLOWMEMORY_AGENT_BONDS_VERIFIER"),
            confirmingVerifier: VM.envAddress("FLOWMEMORY_AGENT_BONDS_CONFIRMING_VERIFIER"),
            multisigOwner1: VM.envAddress("FLOWMEMORY_AGENT_BONDS_MULTISIG_OWNER_1"),
            multisigOwner2: VM.envAddress("FLOWMEMORY_AGENT_BONDS_MULTISIG_OWNER_2"),
            multisigOwner3: VM.envAddress("FLOWMEMORY_AGENT_BONDS_MULTISIG_OWNER_3"),
            multisigThreshold: VM.envUint("FLOWMEMORY_AGENT_BONDS_MULTISIG_THRESHOLD"),
            multisigMinDelay: uint64(VM.envUint("FLOWMEMORY_AGENT_BONDS_MULTISIG_MIN_DELAY")),
            minAgentStake: VM.envUint("FLOWMEMORY_AGENT_BONDS_MIN_AGENT_STAKE"),
            minVerifierStake: VM.envUint("FLOWMEMORY_AGENT_BONDS_MIN_VERIFIER_STAKE"),
            capacityUnit: VM.envUint("FLOWMEMORY_AGENT_BONDS_CAPACITY_UNIT"),
            capacityBondUnit: VM.envUint("FLOWMEMORY_AGENT_BONDS_CAPACITY_BOND_UNIT"),
            maxPayoutPerTask: VM.envUint("FLOWMEMORY_AGENT_BONDS_MAX_PAYOUT_PER_TASK"),
            maxOpenExposure: VM.envUint("FLOWMEMORY_AGENT_BONDS_MAX_OPEN_EXPOSURE"),
            maxOpenTasks: VM.envUint("FLOWMEMORY_AGENT_BONDS_MAX_OPEN_TASKS"),
            agentBondBps: uint16(VM.envUint("FLOWMEMORY_AGENT_BONDS_AGENT_BOND_BPS")),
            verifierFeeBps: uint16(VM.envUint("FLOWMEMORY_AGENT_BONDS_VERIFIER_FEE_BPS")),
            requesterCancelBondBps: uint16(VM.envUint("FLOWMEMORY_AGENT_BONDS_REQUESTER_CANCEL_BOND_BPS")),
            disputeBondBps: uint16(VM.envUint("FLOWMEMORY_AGENT_BONDS_DISPUTE_BOND_BPS")),
            requiredConfirmations: uint8(VM.envUint("FLOWMEMORY_AGENT_BONDS_REQUIRED_CONFIRMATIONS")),
            submissionWindow: uint64(VM.envUint("FLOWMEMORY_AGENT_BONDS_SUBMISSION_WINDOW")),
            disputeWindow: uint64(VM.envUint("FLOWMEMORY_AGENT_BONDS_DISPUTE_WINDOW")),
            graceWindow: uint64(VM.envUint("FLOWMEMORY_AGENT_BONDS_GRACE_WINDOW")),
            minAvailabilityWindow: uint64(VM.envUint("FLOWMEMORY_AGENT_BONDS_MIN_AVAILABILITY_WINDOW")),
            minAgentBond: VM.envUint("FLOWMEMORY_AGENT_BONDS_MIN_AGENT_BOND"),
            minVerifierFee: VM.envUint("FLOWMEMORY_AGENT_BONDS_MIN_VERIFIER_FEE"),
            minRequesterCancelBond: VM.envUint("FLOWMEMORY_AGENT_BONDS_MIN_REQUESTER_CANCEL_BOND"),
            minDisputeBond: VM.envUint("FLOWMEMORY_AGENT_BONDS_MIN_DISPUTE_BOND"),
            evidenceSchema: bytes32(VM.envUint("FLOWMEMORY_AGENT_BONDS_EVIDENCE_SCHEMA")),
            riskTier: uint8(VM.envUint("FLOWMEMORY_AGENT_BONDS_RISK_TIER")),
            base8453PilotAck: VM.envOr("FLOWMEMORY_AGENT_BONDS_BASE8453_PILOT_ACK", false)
        });
    }

    function _enforceDeploymentGate(Config memory config) private view returns (uint256 chainId) {
        chainId = block.chainid;
        if (chainId != LOCAL_ANVIL_CHAIN_ID && chainId != BASE_SEPOLIA_CHAIN_ID && chainId != BASE_MAINNET_CHAIN_ID) {
            revert UnsupportedDeploymentChain(chainId);
        }
        if (chainId == BASE_MAINNET_CHAIN_ID && !config.base8453PilotAck) {
            revert Base8453PilotAckRequired();
        }
    }

    function _validateConfig(Config memory config) private pure {
        if (config.owner == address(0)) revert ZeroConfigAddress("owner");
        if (config.pauseGuardian == address(0)) revert ZeroConfigAddress("pauseGuardian");
        if (config.resolutionAuthority == address(0)) revert ZeroConfigAddress("resolutionAuthority");
        if (config.settlementToken == address(0)) revert ZeroConfigAddress("settlementToken");
        if (config.stakeToken == address(0)) revert ZeroConfigAddress("stakeToken");
        if (config.requester == address(0)) revert ZeroConfigAddress("requester");
        if (config.agent == address(0)) revert ZeroConfigAddress("agent");
        if (config.verifier == address(0)) revert ZeroConfigAddress("verifier");
        if (config.confirmingVerifier == address(0)) revert ZeroConfigAddress("confirmingVerifier");
        if (config.multisigOwner1 == address(0)) revert ZeroConfigAddress("multisigOwner1");
        if (config.multisigOwner2 == address(0)) revert ZeroConfigAddress("multisigOwner2");
        if (config.multisigOwner3 == address(0)) revert ZeroConfigAddress("multisigOwner3");
        if (config.multisigOwner1 == config.multisigOwner2) revert InvalidThreshold();
        if (config.multisigOwner1 == config.multisigOwner3) revert InvalidThreshold();
        if (config.multisigOwner2 == config.multisigOwner3) revert InvalidThreshold();
        if (config.multisigThreshold == 0 || config.multisigThreshold > 3) revert InvalidThreshold();
        if (config.multisigMinDelay == 0) revert InvalidThreshold();
        if (config.requiredConfirmations == 0) revert RequiredConfirmationsMissing();
        if (config.confirmingVerifier == config.verifier) revert ZeroConfigAddress("confirmingVerifier must differ from verifier");
        if (config.maxOpenExposure < config.maxPayoutPerTask) revert InvalidThreshold();
    }
}
