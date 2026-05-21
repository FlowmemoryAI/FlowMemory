// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../shared/TwoStepOwnable.sol";
import {ReentrancyGuard} from "../shared/ReentrancyGuard.sol";
import {AgentLaunchTypes} from "./lib/AgentLaunchTypes.sol";
import {AgentLaunchHashing} from "./lib/AgentLaunchHashing.sol";
import {IAgentRuntime} from "./interfaces/IAgentRuntime.sol";
import {IAgentClassRegistry} from "./interfaces/IAgentClassRegistry.sol";
import {IToolRegistry} from "./interfaces/IToolRegistry.sol";
import {IAgentProfileRegistry} from "./interfaces/IAgentProfileRegistry.sol";
import {IAgentLaunchBondEscrow} from "./interfaces/IAgentLaunchBondEscrow.sol";
import {IAgentMemoryFuelVault} from "./interfaces/IAgentMemoryFuelVault.sol";
import {IAgentLineageRegistry} from "./interfaces/IAgentLineageRegistry.sol";

contract AgentFactory is TwoStepOwnable, ReentrancyGuard {
    string public constant EIP712_NAME = "FlowMemory AgentFactory";
    string public constant EIP712_VERSION = "1";

    IAgentRuntime public immutable runtime;
    IAgentClassRegistry public immutable classRegistry;
    IToolRegistry public immutable toolRegistry;
    IAgentProfileRegistry public immutable profileRegistry;
    IAgentLaunchBondEscrow public immutable bondEscrow;
    IAgentMemoryFuelVault public immutable fuelVault;
    IAgentLineageRegistry public immutable lineageRegistry;

    mapping(address ownerAccount => uint64 nonce) public nonces;
    mapping(bytes32 launchIntentHash => bool consumed) public consumedLaunchIntent;
    mapping(bytes32 launchId => bytes32 agentId) public launchIdToAgentId;

    address public launchGuardian;
    bool public paused;
    uint64 public minIntentValidity;
    uint64 public maxIntentValidity;

    error ZeroAddress();
    error FactoryPaused();
    error NotLaunchGuardian(address caller);
    error InvalidNonce(address owner, uint64 expected, uint64 provided);
    error InvalidValidityWindow(uint64 validAfter, uint64 validUntil);
    error IntentNotActive(uint64 validAfter, uint64 validUntil, uint64 nowTime);
    error LaunchIntentAlreadyConsumed(bytes32 launchIntentHash);
    error InvalidSigner(address recovered, address expectedOwner);
    error ClassNotLaunchable(bytes32 classId);
    error KernelClassMismatch(bytes32 classId, bytes32 expectedKernelClass, bytes32 providedKernelClass);
    error AutonomyOutOfRange(bytes32 classId, uint8 minimum, uint8 maximum, uint8 provided);
    error ToolSetNotAllowed(bytes32 classId, bytes32 toolSetRoot, uint8 autonomyLevel);
    error BondBelowMinimum(uint256 provided, uint256 minimum);
    error FuelBelowMinimum(uint256 provided, uint256 minimum);
    error MissingBondToken();
    error MissingFuelToken();
    error InvalidSignatureLength(uint256 length);
    error SignatureRecoveryFailed();

    event LaunchGuardianSet(address indexed previousGuardian, address indexed newGuardian);
    event PausedSet(bool paused);
    event IntentWindowSet(uint64 minIntentValidity, uint64 maxIntentValidity);
    event LaunchIntentConsumed(
        bytes32 indexed launchIntentHash,
        address indexed owner,
        bytes32 indexed classId,
        uint64 nonce
    );
    event AgentLaunched(
        bytes32 indexed launchIntentHash,
        bytes32 indexed launchId,
        bytes32 indexed agentId,
        address owner,
        bytes32 classId,
        bytes32 policyRoot,
        bytes32 toolAllowlistRoot,
        bytes32 initialMemoryRoot,
        bytes32 activeGoalRoot,
        bytes32 profileDigest,
        uint8 autonomyLevel,
        uint8 riskLevel
    );
    event AgentLaunchLinkedToLineage(
        bytes32 indexed agentId,
        bytes32 indexed parentAgentId,
        bytes32 indexed parentSwarmId
    );
    event LaunchIntentCancelled(address indexed owner, uint64 indexed nonce, bytes32 indexed salt);

    constructor(
        address runtime_,
        address classRegistry_,
        address toolRegistry_,
        address profileRegistry_,
        address bondEscrow_,
        address fuelVault_,
        address lineageRegistry_,
        address initialOwner,
        address initialLaunchGuardian,
        uint64 minIntentValidity_,
        uint64 maxIntentValidity_
    ) TwoStepOwnable(initialOwner) {
        if (
            runtime_ == address(0)
                || classRegistry_ == address(0)
                || toolRegistry_ == address(0)
                || profileRegistry_ == address(0)
                || bondEscrow_ == address(0)
                || fuelVault_ == address(0)
                || lineageRegistry_ == address(0)
                || initialLaunchGuardian == address(0)
        ) revert ZeroAddress();
        runtime = IAgentRuntime(runtime_);
        classRegistry = IAgentClassRegistry(classRegistry_);
        toolRegistry = IToolRegistry(toolRegistry_);
        profileRegistry = IAgentProfileRegistry(profileRegistry_);
        bondEscrow = IAgentLaunchBondEscrow(bondEscrow_);
        fuelVault = IAgentMemoryFuelVault(fuelVault_);
        lineageRegistry = IAgentLineageRegistry(lineageRegistry_);
        launchGuardian = initialLaunchGuardian;
        minIntentValidity = minIntentValidity_;
        maxIntentValidity = maxIntentValidity_;
    }

    modifier whenNotPaused() {
        if (paused) revert FactoryPaused();
        _;
    }

    modifier onlyLaunchGuardianOrOwner() {
        if (msg.sender != launchGuardian && msg.sender != owner) revert NotLaunchGuardian(msg.sender);
        _;
    }

    function setLaunchGuardian(address nextGuardian) external onlyOwner {
        if (nextGuardian == address(0)) revert ZeroAddress();
        address previous = launchGuardian;
        launchGuardian = nextGuardian;
        emit LaunchGuardianSet(previous, nextGuardian);
    }

    function setPaused(bool value) external onlyLaunchGuardianOrOwner {
        paused = value;
        emit PausedSet(value);
    }

    function setIntentWindows(uint64 minValidity, uint64 maxValidity) external onlyOwner {
        minIntentValidity = minValidity;
        maxIntentValidity = maxValidity;
        emit IntentWindowSet(minValidity, maxValidity);
    }

    function previewLaunch(AgentLaunchTypes.LaunchIntent calldata intent)
        external
        view
        returns (bytes32 launchIntentHash, bool valid, bytes32[] memory warnings)
    {
        launchIntentHash = AgentLaunchHashing.launchIntentStructHash(intent);
        warnings = new bytes32[](4);
        uint256 warningCount = 0;

        AgentLaunchTypes.AgentClass memory classConfig = classRegistry.getClass(intent.classId);
        if (!(classConfig.active && !classConfig.deprecated && classConfig.allowPublicLaunch)) {
            warnings[warningCount] = keccak256("class.not_launchable");
            warningCount += 1;
        }
        if (intent.kernelClass != classConfig.kernelClass) {
            warnings[warningCount] = keccak256("class.kernel_mismatch");
            warningCount += 1;
        }
        if (intent.autonomyLevel < classConfig.minAutonomyLevel || intent.autonomyLevel > classConfig.maxAutonomyLevel) {
            warnings[warningCount] = keccak256("class.autonomy_out_of_range");
            warningCount += 1;
        }
        if (!toolRegistry.validateToolSetForClass(intent.classId, intent.toolAllowlistRoot, intent.autonomyLevel)) {
            warnings[warningCount] = keccak256("toolset.not_allowed");
            warningCount += 1;
        }

        valid = warningCount == 0 && _isIntentWindowValid(intent);
        assembly {
            mstore(warnings, warningCount)
        }
    }

    function launchAgent(
        AgentLaunchTypes.LaunchIntent calldata intent,
        bytes calldata ownerSig,
        AgentLaunchTypes.LaunchPayment calldata payment
    ) external nonReentrant whenNotPaused returns (bytes32 agentId, bytes32 launchId) {
        _validateIntentWindow(intent);

        uint64 currentNonce = nonces[intent.owner];
        if (intent.nonce != currentNonce) revert InvalidNonce(intent.owner, currentNonce, intent.nonce);

        bytes32 launchIntentHash = AgentLaunchHashing.launchIntentStructHash(intent);
        if (consumedLaunchIntent[launchIntentHash]) revert LaunchIntentAlreadyConsumed(launchIntentHash);
        _verifySigner(intent, ownerSig);

        AgentLaunchTypes.AgentClass memory classConfig = classRegistry.getClass(intent.classId);
        if (!(classConfig.active && !classConfig.deprecated && classConfig.allowPublicLaunch)) {
            revert ClassNotLaunchable(intent.classId);
        }
        if (intent.kernelClass != classConfig.kernelClass) {
            revert KernelClassMismatch(intent.classId, classConfig.kernelClass, intent.kernelClass);
        }
        if (intent.autonomyLevel < classConfig.minAutonomyLevel || intent.autonomyLevel > classConfig.maxAutonomyLevel) {
            revert AutonomyOutOfRange(intent.classId, classConfig.minAutonomyLevel, classConfig.maxAutonomyLevel, intent.autonomyLevel);
        }
        if (!toolRegistry.validateToolSetForClass(intent.classId, intent.toolAllowlistRoot, intent.autonomyLevel)) {
            revert ToolSetNotAllowed(intent.classId, intent.toolAllowlistRoot, intent.autonomyLevel);
        }
        if (intent.profileDigest == bytes32(0) || intent.launchSpecRoot == bytes32(0) || intent.activeGoalRoot == bytes32(0)) {
            revert ZeroAddress();
        }
        if (intent.bondAmount < classConfig.minLaunchBond) revert BondBelowMinimum(intent.bondAmount, classConfig.minLaunchBond);
        if (intent.initialFuelAmount < classConfig.minMemoryFuel) revert FuelBelowMinimum(intent.initialFuelAmount, classConfig.minMemoryFuel);
        if (classConfig.minLaunchBond != 0 && intent.bondToken == address(0)) revert MissingBondToken();
        if (classConfig.minMemoryFuel != 0 && intent.fuelToken == address(0)) revert MissingFuelToken();

        consumedLaunchIntent[launchIntentHash] = true;
        nonces[intent.owner] = currentNonce + 1;

        launchId = AgentLaunchHashing.launchId(block.chainid, address(this), intent);
        agentId = runtime.registerAgent(
            intent.owner,
            intent.rootfieldId,
            intent.policyRoot,
            intent.toolAllowlistRoot,
            intent.initialMemoryRoot,
            intent.activeGoalRoot,
            intent.autonomyLevel,
            intent.kernelClass,
            intent.salt,
            "flowmemory://public-launch/register"
        );
        launchIdToAgentId[launchId] = agentId;

        address payer = payment.sponsorMode ? payment.sponsor : intent.owner;
        if (classConfig.minLaunchBond != 0) {
            bondEscrow.lockLaunchBond(
                agentId,
                payer,
                intent.owner,
                intent.classId,
                intent.bondToken,
                intent.bondAmount,
                intent.policyRoot
            );
        }
        if (intent.fuelToken != address(0)) {
            fuelVault.registerFuelAccount(agentId, intent.owner, intent.classId, intent.fuelToken);
            if (intent.initialFuelAmount != 0) {
                fuelVault.depositFuel(agentId, payer, intent.fuelToken, intent.initialFuelAmount);
            }
        }

        profileRegistry.setProfile(
            agentId,
            intent.owner,
            intent.profileDigest,
            intent.profileDigest,
            intent.launchSpecRoot,
            bytes32(0),
            bytes32(0),
            intent.discoverable
        );

        if (intent.parentAgentId != bytes32(0) || intent.parentSwarmId != bytes32(0)) {
            AgentLaunchTypes.ParentType parentType = intent.parentAgentId != bytes32(0)
                ? AgentLaunchTypes.ParentType.Agent
                : AgentLaunchTypes.ParentType.Swarm;
            lineageRegistry.attachLineage(
                agentId,
                parentType,
                intent.parentAgentId,
                intent.parentSwarmId,
                address(0),
                keccak256(abi.encode(intent.parentAgentId, intent.parentSwarmId, intent.launchSpecRoot)),
                parentType == AgentLaunchTypes.ParentType.None ? 0 : 1
            );
            emit AgentLaunchLinkedToLineage(agentId, intent.parentAgentId, intent.parentSwarmId);
        }

        emit LaunchIntentConsumed(launchIntentHash, intent.owner, intent.classId, intent.nonce);
        emit AgentLaunched(
            launchIntentHash,
            launchId,
            agentId,
            intent.owner,
            intent.classId,
            intent.policyRoot,
            intent.toolAllowlistRoot,
            intent.initialMemoryRoot,
            intent.activeGoalRoot,
            intent.profileDigest,
            intent.autonomyLevel,
            intent.riskLevel
        );
    }

    function cancelLaunchIntent(uint64 nonce, bytes32 salt) external {
        uint64 currentNonce = nonces[msg.sender];
        if (nonce != currentNonce) revert InvalidNonce(msg.sender, currentNonce, nonce);
        nonces[msg.sender] = nonce + 1;
        emit LaunchIntentCancelled(msg.sender, nonce, salt);
    }

    function _isIntentWindowValid(AgentLaunchTypes.LaunchIntent calldata intent) private view returns (bool) {
        if (intent.validUntil <= intent.validAfter) return false;
        uint64 width = intent.validUntil - intent.validAfter;
        if (minIntentValidity != 0 && width < minIntentValidity) return false;
        if (maxIntentValidity != 0 && width > maxIntentValidity) return false;
        return uint64(block.timestamp) >= intent.validAfter && uint64(block.timestamp) <= intent.validUntil;
    }

    function _validateIntentWindow(AgentLaunchTypes.LaunchIntent calldata intent) private view {
        if (intent.validUntil <= intent.validAfter) revert InvalidValidityWindow(intent.validAfter, intent.validUntil);
        uint64 width = intent.validUntil - intent.validAfter;
        if ((minIntentValidity != 0 && width < minIntentValidity) || (maxIntentValidity != 0 && width > maxIntentValidity)) {
            revert InvalidValidityWindow(intent.validAfter, intent.validUntil);
        }
        if (uint64(block.timestamp) < intent.validAfter || uint64(block.timestamp) > intent.validUntil) {
            revert IntentNotActive(intent.validAfter, intent.validUntil, uint64(block.timestamp));
        }
    }

    function _verifySigner(AgentLaunchTypes.LaunchIntent calldata intent, bytes calldata signature) private view {
        if (signature.length != 65) revert InvalidSignatureLength(signature.length);
        bytes32 digest = AgentLaunchHashing.launchIntentDigest(EIP712_NAME, EIP712_VERSION, block.chainid, address(this), intent);
        (bytes32 r, bytes32 s, uint8 v) = AgentLaunchHashing.splitSignature(signature);
        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0)) revert SignatureRecoveryFailed();
        if (recovered != intent.owner) revert InvalidSigner(recovered, intent.owner);
    }
}
