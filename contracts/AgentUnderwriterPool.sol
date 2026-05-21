// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20SettlementToken} from "./interfaces/IERC20SettlementToken.sol";
import {IUnderwriterPool} from "./interfaces/IUnderwriterPool.sol";
import {TwoStepOwnable} from "./shared/TwoStepOwnable.sol";

contract AgentUnderwriterPool is TwoStepOwnable, IUnderwriterPool {
    IERC20SettlementToken public immutable token;
    PoolType public immutable override poolType;
    address public immutable override asset;

    uint256 public override totalLocked;
    uint256 public override totalAllocated;
    uint256 public override maxCoveragePerTask;
    uint8 public maxRiskTier;

    mapping(address account => uint256 shares) public sharesOf;
    uint256 public totalShares;
    mapping(bytes32 taskId => uint256 amount) public lockedByTask;
    mapping(address allocator => bool authorized) public isAllocator;
    mapping(uint256 epoch => uint256 paid) public lossPaidByEpoch;
    mapping(address provider => uint256 availableAt) public withdrawalAvailableAt;

    uint256 public epochDuration;
    uint256 public maxLossPerEpoch;
    uint256 public withdrawalCooldown;

    error ZeroToken();
    error ZeroAmount();
    error ZeroAllocator();
    error NotAllocator(address caller);
    error CoverageAlreadyLocked(bytes32 taskId);
    error CoverageNotLocked(bytes32 taskId);
    error CoverageExceedsCap(uint256 amount, uint256 cap);
    error InsufficientAvailableCapacity(uint256 requested, uint256 available);
    error InsufficientUnlockedLiquidity(uint256 requested, uint256 available);
    error TransferFailed();
    error PoolInvariantBroken();
    error ClaimExceedsEpochCap(uint256 requested, uint256 remaining, uint256 epoch);
    error WithdrawalCooldownActive(uint256 availableAt);
    error InvalidEpochDuration();

    event AllocatorSet(address indexed allocator, bool authorized);
    event PoolParametersSet(uint256 maxCoveragePerTask, uint8 maxRiskTier);
    event PoolRiskControlsSet(uint256 epochDuration, uint256 maxLossPerEpoch, uint256 withdrawalCooldown);
    event Deposited(address indexed provider, uint256 amount, uint256 sharesMinted);
    event Withdrawn(address indexed provider, uint256 amount, uint256 sharesBurned);
    event WithdrawalRequested(address indexed provider, uint256 availableAt);
    event CoverageLocked(bytes32 indexed taskId, uint256 amount);
    event CoverageReleased(bytes32 indexed taskId, uint256 amount);
    event ClaimPaid(bytes32 indexed taskId, address indexed recipient, bytes32 indexed reason, uint256 paid);

    modifier onlyAllocator() {
        if (!isAllocator[msg.sender]) revert NotAllocator(msg.sender);
        _;
    }

    constructor(address asset_, PoolType poolType_, address initialOwner, uint256 maxCoveragePerTask_, uint8 maxRiskTier_)
        TwoStepOwnable(initialOwner)
    {
        if (asset_ == address(0)) revert ZeroToken();
        if (initialOwner == address(0)) revert ZeroOwner();
        token = IERC20SettlementToken(asset_);
        asset = asset_;
        poolType = poolType_;
        maxCoveragePerTask = maxCoveragePerTask_;
        maxRiskTier = maxRiskTier_;
    }

    function setAllocator(address allocator, bool authorized) external onlyOwner {
        if (allocator == address(0)) revert ZeroAllocator();
        isAllocator[allocator] = authorized;
        emit AllocatorSet(allocator, authorized);
    }

    function setPoolParameters(uint256 maxCoveragePerTask_, uint8 maxRiskTier_) external onlyOwner {
        maxCoveragePerTask = maxCoveragePerTask_;
        maxRiskTier = maxRiskTier_;
        emit PoolParametersSet(maxCoveragePerTask_, maxRiskTier_);
    }

    function setPoolRiskControls(uint256 epochDuration_, uint256 maxLossPerEpoch_, uint256 withdrawalCooldown_)
        external
        onlyOwner
    {
        if (maxLossPerEpoch_ != 0 && epochDuration_ == 0) revert InvalidEpochDuration();
        epochDuration = epochDuration_;
        maxLossPerEpoch = maxLossPerEpoch_;
        withdrawalCooldown = withdrawalCooldown_;
        emit PoolRiskControlsSet(epochDuration_, maxLossPerEpoch_, withdrawalCooldown_);
    }

    function currentEpoch() public view returns (uint256) {
        if (epochDuration == 0) return 0;
        return block.timestamp / epochDuration;
    }

    function remainingEpochLossCapacity() public view returns (uint256) {
        if (maxLossPerEpoch == 0) return type(uint256).max;
        uint256 used = lossPaidByEpoch[currentEpoch()] + totalLocked;
        if (used >= maxLossPerEpoch) return 0;
        return maxLossPerEpoch - used;
    }

    function totalDeposited() public view override returns (uint256) {
        return token.balanceOf(address(this));
    }

    function availableCapacity() public view override returns (uint256) {
        uint256 balance = token.balanceOf(address(this));
        if (balance <= totalLocked) return 0;
        return balance - totalLocked;
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 shares;
        if (totalShares < 1) {
            shares = amount;
        } else {
            if (balanceBefore < 1) revert PoolInvariantBroken();
            shares = amount * totalShares / balanceBefore;
        }
        sharesOf[msg.sender] += shares;
        totalShares += shares;
        emit Deposited(msg.sender, amount, shares);
        if (!token.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function requestWithdrawal() external {
        if (sharesOf[msg.sender] < 1) revert ZeroAmount();
        uint256 availableAt = block.timestamp + withdrawalCooldown;
        withdrawalAvailableAt[msg.sender] = availableAt;
        emit WithdrawalRequested(msg.sender, availableAt);
    }

    function withdraw(uint256 shares) external {
        if (shares == 0) revert ZeroAmount();
        if (withdrawalCooldown != 0) {
            uint256 availableAt = withdrawalAvailableAt[msg.sender];
            if (availableAt < 1 || block.timestamp < availableAt) revert WithdrawalCooldownActive(availableAt);
        }
        uint256 accountShares = sharesOf[msg.sender];
        if (accountShares < shares) revert InsufficientUnlockedLiquidity(shares, accountShares);
        uint256 balance = token.balanceOf(address(this));
        uint256 amount = balance * shares / totalShares;
        uint256 unlocked = availableCapacity();
        if (amount > unlocked) revert InsufficientUnlockedLiquidity(amount, unlocked);
        sharesOf[msg.sender] = accountShares - shares;
        totalShares -= shares;
        emit Withdrawn(msg.sender, amount, shares);
        if (!token.transfer(msg.sender, amount)) revert TransferFailed();
    }

    function canBackTask(bytes32, uint256 payout, uint8 riskTier) external view override returns (bool) {
        if (maxRiskTier != 0 && riskTier > maxRiskTier) return false;
        if (maxCoveragePerTask != 0 && payout > maxCoveragePerTask) return false;
        if (payout > remainingEpochLossCapacity()) return false;
        return payout <= availableCapacity();
    }

    function lockCoverage(bytes32 taskId, uint256 amount) external override onlyAllocator {
        if (taskId == bytes32(0)) revert CoverageNotLocked(taskId);
        if (amount == 0) revert ZeroAmount();
        if (lockedByTask[taskId] != 0) revert CoverageAlreadyLocked(taskId);
        if (maxCoveragePerTask != 0 && amount > maxCoveragePerTask) revert CoverageExceedsCap(amount, maxCoveragePerTask);
        uint256 available = availableCapacity();
        if (amount > available) revert InsufficientAvailableCapacity(amount, available);
        uint256 epochRemaining = remainingEpochLossCapacity();
        if (amount > epochRemaining) revert ClaimExceedsEpochCap(amount, epochRemaining, currentEpoch());
        lockedByTask[taskId] = amount;
        totalLocked += amount;
        totalAllocated += amount;
        emit CoverageLocked(taskId, amount);
    }

    function releaseForTask(bytes32 taskId) external override onlyAllocator returns (uint256 released) {
        released = lockedByTask[taskId];
        if (released == 0) revert CoverageNotLocked(taskId);
        delete lockedByTask[taskId];
        totalLocked -= released;
        totalAllocated -= released;
        emit CoverageReleased(taskId, released);
    }

    function payClaim(bytes32 taskId, address recipient, uint256 amount, bytes32 reason)
        external
        override
        onlyAllocator
        returns (uint256 paid)
    {
        uint256 locked = lockedByTask[taskId];
        if (locked == 0) revert CoverageNotLocked(taskId);
        if (recipient == address(0)) revert ZeroAllocator();
        paid = amount > locked ? locked : amount;
        if (maxLossPerEpoch != 0 && paid > 0) {
            uint256 epoch = currentEpoch();
            uint256 paidThisEpoch = lossPaidByEpoch[epoch];
            uint256 remaining = paidThisEpoch >= maxLossPerEpoch ? 0 : maxLossPerEpoch - paidThisEpoch;
            if (paid > remaining) revert ClaimExceedsEpochCap(paid, remaining, epoch);
            lossPaidByEpoch[epoch] = paidThisEpoch + paid;
        }
        delete lockedByTask[taskId];
        totalLocked -= locked;
        totalAllocated -= locked;
        emit ClaimPaid(taskId, recipient, reason, paid);
        if (locked > paid) emit CoverageReleased(taskId, locked - paid);
        if (paid > 0 && !token.transfer(recipient, paid)) revert TransferFailed();
    }
}
