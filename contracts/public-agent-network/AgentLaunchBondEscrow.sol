// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20SettlementToken} from "../interfaces/IERC20SettlementToken.sol";
import {TwoStepOwnable} from "../shared/TwoStepOwnable.sol";
import {ReentrancyGuard} from "../shared/ReentrancyGuard.sol";
import {AgentLaunchTypes} from "./lib/AgentLaunchTypes.sol";
import {IAgentLaunchBondEscrow} from "./interfaces/IAgentLaunchBondEscrow.sol";

contract AgentLaunchBondEscrow is TwoStepOwnable, ReentrancyGuard, IAgentLaunchBondEscrow {
    struct Bond {
        bytes32 agentId;
        bytes32 classId;
        address payer;
        address beneficiary;
        address token;
        uint256 amount;
        uint64 lockedAt;
        uint64 releaseAfter;
        uint64 releaseRequestedAt;
        AgentLaunchTypes.BondStatus status;
        bytes32 policyRoot;
    }

    mapping(bytes32 agentId => Bond bond) private _bonds;
    mapping(bytes32 classId => AgentLaunchTypes.BondPolicy policy) public classBondPolicies;
    mapping(address token => bool approved) public approvedBondToken;
    mapping(address locker => bool authorized) public isAuthorizedLocker;
    mapping(bytes32 agentId => uint256 slashedAmount) public totalSlashedByAgent;

    error ZeroAgentId();
    error ZeroBeneficiary();
    error ZeroToken();
    error ZeroLocker();
    error BondAlreadyExists(bytes32 agentId);
    error BondNotFound(bytes32 agentId);
    error UnauthorizedLocker(address caller);
    error UnapprovedBondToken(address token);
    error InactiveBondPolicy(bytes32 classId);
    error BondBelowMinimum(uint256 amount, uint256 minimum);
    error BondAboveMaximum(uint256 amount, uint256 maximum);
    error InvalidSlashCap(uint16 slashCapBps);
    error InvalidReleaseSchedule(uint64 releaseAfter, uint64 nowTime);
    error InvalidBondStatus(bytes32 agentId, AgentLaunchTypes.BondStatus status);
    error EarlyRelease(bytes32 agentId, uint64 releaseAfter, uint64 nowTime);
    error SlashAboveCap(uint256 requested, uint256 available);
    error TransferFailed();
    error ZeroEvidenceRoot();

    event ApprovedBondTokenSet(address indexed token, bool approved);
    event AuthorizedLockerSet(address indexed locker, bool authorized);
    event BondPolicyUpdated(
        bytes32 indexed classId,
        address token,
        uint256 minAmount,
        uint256 maxAmount,
        uint64 minLockSeconds,
        uint64 releaseDelaySeconds,
        uint16 slashCapBps,
        bool active
    );
    event LaunchBondLocked(
        bytes32 indexed agentId,
        address indexed payer,
        address indexed beneficiary,
        address token,
        uint256 amount,
        bytes32 policyRoot,
        uint64 releaseAfter
    );
    event LaunchBondReleaseRequested(bytes32 indexed agentId, uint64 releaseAt);
    event LaunchBondReleased(bytes32 indexed agentId, address indexed recipient, uint256 amount);
    event LaunchBondSlashed(bytes32 indexed agentId, uint256 amount, bytes32 reasonCode, bytes32 evidenceRoot);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    modifier onlyAuthorizedLocker() {
        if (!isAuthorizedLocker[msg.sender]) revert UnauthorizedLocker(msg.sender);
        _;
    }

    function setApprovedBondToken(address token, bool approved) external onlyOwner {
        if (token == address(0)) revert ZeroToken();
        approvedBondToken[token] = approved;
        emit ApprovedBondTokenSet(token, approved);
    }

    function setAuthorizedLocker(address locker, bool authorized) external onlyOwner {
        if (locker == address(0)) revert ZeroLocker();
        isAuthorizedLocker[locker] = authorized;
        emit AuthorizedLockerSet(locker, authorized);
    }

    function setBondPolicy(bytes32 classId, AgentLaunchTypes.BondPolicy calldata policy) external onlyOwner {
        if (classId == bytes32(0)) revert ZeroAgentId();
        if (policy.token == address(0)) revert ZeroToken();
        if (policy.slashCapBps > 10_000) revert InvalidSlashCap(policy.slashCapBps);
        classBondPolicies[classId] = policy;
        emit BondPolicyUpdated(
            classId,
            policy.token,
            policy.minAmount,
            policy.maxAmount,
            policy.minLockSeconds,
            policy.releaseDelaySeconds,
            policy.slashCapBps,
            policy.active
        );
    }

    function lockLaunchBond(
        bytes32 agentId,
        address payer,
        address beneficiary,
        bytes32 classId,
        address token,
        uint256 amount,
        bytes32 policyRoot
    ) external nonReentrant onlyAuthorizedLocker returns (bool) {
        if (agentId == bytes32(0)) revert ZeroAgentId();
        if (beneficiary == address(0)) revert ZeroBeneficiary();
        if (token == address(0)) revert ZeroToken();
        if (_bonds[agentId].status != AgentLaunchTypes.BondStatus.None) revert BondAlreadyExists(agentId);
        if (!approvedBondToken[token]) revert UnapprovedBondToken(token);

        AgentLaunchTypes.BondPolicy memory policy = classBondPolicies[classId];
        if (!policy.active) revert InactiveBondPolicy(classId);
        if (policy.token != token) revert UnapprovedBondToken(token);
        if (amount < policy.minAmount) revert BondBelowMinimum(amount, policy.minAmount);
        if (policy.maxAmount != 0 && amount > policy.maxAmount) revert BondAboveMaximum(amount, policy.maxAmount);

        uint64 now64 = uint64(block.timestamp);
        uint64 releaseAfter = now64 + policy.minLockSeconds;
        _bonds[agentId] = Bond({
            agentId: agentId,
            classId: classId,
            payer: payer,
            beneficiary: beneficiary,
            token: token,
            amount: amount,
            lockedAt: now64,
            releaseAfter: releaseAfter,
            releaseRequestedAt: 0,
            status: AgentLaunchTypes.BondStatus.Locked,
            policyRoot: policyRoot
        });

        if (!IERC20SettlementToken(token).transferFrom(payer, address(this), amount)) revert TransferFailed();
        emit LaunchBondLocked(agentId, payer, beneficiary, token, amount, policyRoot, releaseAfter);
        return true;
    }

    function requestRelease(bytes32 agentId) external {
        Bond storage bond = _bonds[agentId];
        if (bond.status == AgentLaunchTypes.BondStatus.None) revert BondNotFound(agentId);
        if (msg.sender != bond.beneficiary && msg.sender != bond.payer) revert UnauthorizedLocker(msg.sender);
        if (bond.status != AgentLaunchTypes.BondStatus.Locked) revert InvalidBondStatus(agentId, bond.status);

        AgentLaunchTypes.BondPolicy memory policy = classBondPolicies[bond.classId];
        uint64 releaseAt = policy.releaseDelaySeconds == 0
            ? bond.releaseAfter
            : uint64(block.timestamp) + policy.releaseDelaySeconds;
        bond.releaseRequestedAt = releaseAt;
        bond.status = AgentLaunchTypes.BondStatus.ReleaseRequested;
        emit LaunchBondReleaseRequested(agentId, releaseAt);
    }

    function releaseBond(bytes32 agentId) external nonReentrant {
        Bond storage bond = _bonds[agentId];
        if (bond.status == AgentLaunchTypes.BondStatus.None) revert BondNotFound(agentId);
        if (msg.sender != bond.beneficiary && msg.sender != bond.payer) revert UnauthorizedLocker(msg.sender);
        if (bond.status != AgentLaunchTypes.BondStatus.ReleaseRequested && bond.status != AgentLaunchTypes.BondStatus.Locked) {
            revert InvalidBondStatus(agentId, bond.status);
        }
        uint64 releaseAt = bond.status == AgentLaunchTypes.BondStatus.ReleaseRequested && bond.releaseRequestedAt != 0
            ? bond.releaseRequestedAt
            : bond.releaseAfter;
        if (uint64(block.timestamp) < releaseAt) revert EarlyRelease(agentId, releaseAt, uint64(block.timestamp));

        uint256 amount = bond.amount;
        address token = bond.token;
        address recipient = bond.beneficiary;
        bond.amount = 0;
        bond.status = AgentLaunchTypes.BondStatus.Released;

        if (!IERC20SettlementToken(token).transfer(recipient, amount)) revert TransferFailed();
        emit LaunchBondReleased(agentId, recipient, amount);
    }

    function slashBond(bytes32 agentId, uint256 amount, bytes32 reasonCode, bytes32 evidenceRoot)
        external
        nonReentrant
        onlyAuthorizedLocker
    {
        Bond storage bond = _bonds[agentId];
        if (bond.status == AgentLaunchTypes.BondStatus.None) revert BondNotFound(agentId);
        if (bond.status != AgentLaunchTypes.BondStatus.Locked && bond.status != AgentLaunchTypes.BondStatus.ReleaseRequested) {
            revert InvalidBondStatus(agentId, bond.status);
        }
        if (evidenceRoot == bytes32(0)) revert ZeroEvidenceRoot();

        AgentLaunchTypes.BondPolicy memory policy = classBondPolicies[bond.classId];
        uint256 slashCap = policy.slashCapBps == 0 ? bond.amount : bond.amount * policy.slashCapBps / 10_000;
        if (amount > slashCap || amount > bond.amount) revert SlashAboveCap(amount, bond.amount < slashCap ? bond.amount : slashCap);

        bond.amount -= amount;
        totalSlashedByAgent[agentId] += amount;
        if (bond.amount == 0) {
            bond.status = AgentLaunchTypes.BondStatus.Slashed;
        }
        emit LaunchBondSlashed(agentId, amount, reasonCode, evidenceRoot);
    }

    function getBond(bytes32 agentId) external view returns (Bond memory) {
        Bond memory bond = _bonds[agentId];
        if (bond.status == AgentLaunchTypes.BondStatus.None) revert BondNotFound(agentId);
        return bond;
    }
}
