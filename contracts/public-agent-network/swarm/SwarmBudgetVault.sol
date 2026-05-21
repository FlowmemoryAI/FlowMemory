// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20SettlementToken} from "../../interfaces/IERC20SettlementToken.sol";
import {TwoStepOwnable} from "../../shared/TwoStepOwnable.sol";
import {ReentrancyGuard} from "../../shared/ReentrancyGuard.sol";

contract SwarmBudgetVault is TwoStepOwnable, ReentrancyGuard {
    struct BudgetLine {
        bytes32 budgetLineId;
        bytes32 swarmId;
        address asset;
        uint256 cap;
        uint256 spent;
        uint256 reserved;
        bytes32 purposeRoot;
        bytes32 rolePolicyRoot;
        uint64 windowStart;
        uint64 windowSeconds;
        bool active;
    }

    mapping(bytes32 swarmId => mapping(address asset => uint256 balance)) public swarmBalances;
    mapping(bytes32 budgetLineId => BudgetLine line) private _budgetLines;
    mapping(bytes32 reservationId => uint256 amount) public reservedAmountByReservation;
    mapping(bytes32 swarmId => mapping(bytes32 budgetLineId => bool allowed)) public swarmHasBudgetLine;
    mapping(address operator => bool authorized) public isAuthorizedOperator;

    error ZeroSwarmId();
    error ZeroAsset();
    error ZeroAmount();
    error ZeroOperator();
    error BudgetLineAlreadyExists(bytes32 budgetLineId);
    error BudgetLineNotFound(bytes32 budgetLineId);
    error InactiveBudgetLine(bytes32 budgetLineId);
    error UnauthorizedOperator(address caller);
    error InsufficientSwarmBalance(bytes32 swarmId, address asset, uint256 requested, uint256 available);
    error BudgetCapExceeded(bytes32 budgetLineId, uint256 attempted, uint256 cap);
    error ReservationNotFound(bytes32 reservationId);
    error TransferFailed();

    event AuthorizedOperatorSet(address indexed operator, bool authorized);
    event SwarmBudgetDeposited(bytes32 indexed swarmId, address indexed depositor, address asset, uint256 amount);
    event SwarmBudgetLineCreated(
        bytes32 indexed swarmId,
        bytes32 indexed budgetLineId,
        address asset,
        uint256 cap,
        bytes32 purposeRoot,
        bytes32 rolePolicyRoot
    );
    event SwarmBudgetReserved(
        bytes32 indexed swarmId,
        bytes32 indexed budgetLineId,
        bytes32 indexed reservationId,
        uint256 amount,
        bytes32 intentRoot
    );
    event SwarmBudgetSpent(
        bytes32 indexed swarmId,
        bytes32 indexed budgetLineId,
        bytes32 indexed spendId,
        address recipient,
        address asset,
        uint256 amount,
        bytes32 receiptRoot
    );
    event SwarmBudgetReleased(bytes32 indexed swarmId, bytes32 indexed budgetLineId, bytes32 indexed reservationId, uint256 amount);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    modifier onlyAuthorizedOperator() {
        if (!isAuthorizedOperator[msg.sender]) revert UnauthorizedOperator(msg.sender);
        _;
    }

    function setAuthorizedOperator(address operator, bool authorized) external onlyOwner {
        if (operator == address(0)) revert ZeroOperator();
        isAuthorizedOperator[operator] = authorized;
        emit AuthorizedOperatorSet(operator, authorized);
    }

    function deposit(bytes32 swarmId, address payer, address asset, uint256 amount) external nonReentrant {
        if (swarmId == bytes32(0)) revert ZeroSwarmId();
        if (asset == address(0)) revert ZeroAsset();
        if (amount == 0) revert ZeroAmount();
        swarmBalances[swarmId][asset] += amount;
        if (!IERC20SettlementToken(asset).transferFrom(payer, address(this), amount)) revert TransferFailed();
        emit SwarmBudgetDeposited(swarmId, payer, asset, amount);
    }

    function createBudgetLine(
        bytes32 swarmId,
        address asset,
        uint256 cap,
        bytes32 purposeRoot,
        bytes32 rolePolicyRoot,
        uint64 windowSeconds
    ) external onlyAuthorizedOperator returns (bytes32 budgetLineId) {
        if (swarmId == bytes32(0)) revert ZeroSwarmId();
        if (asset == address(0)) revert ZeroAsset();
        if (cap == 0) revert ZeroAmount();
        budgetLineId = keccak256(abi.encode(swarmId, asset, purposeRoot, rolePolicyRoot, block.timestamp));
        if (_budgetLines[budgetLineId].budgetLineId != bytes32(0)) revert BudgetLineAlreadyExists(budgetLineId);
        _budgetLines[budgetLineId] = BudgetLine({
            budgetLineId: budgetLineId,
            swarmId: swarmId,
            asset: asset,
            cap: cap,
            spent: 0,
            reserved: 0,
            purposeRoot: purposeRoot,
            rolePolicyRoot: rolePolicyRoot,
            windowStart: uint64(block.timestamp),
            windowSeconds: windowSeconds,
            active: true
        });
        swarmHasBudgetLine[swarmId][budgetLineId] = true;
        emit SwarmBudgetLineCreated(swarmId, budgetLineId, asset, cap, purposeRoot, rolePolicyRoot);
    }

    function reserve(bytes32 swarmId, bytes32 budgetLineId, uint256 amount, bytes32 intentRoot)
        external
        onlyAuthorizedOperator
        returns (bytes32 reservationId)
    {
        if (amount == 0) revert ZeroAmount();
        BudgetLine storage line = _requireLine(swarmId, budgetLineId);
        uint256 availableLine = line.cap - line.spent - line.reserved;
        if (amount > availableLine) revert BudgetCapExceeded(budgetLineId, line.spent + line.reserved + amount, line.cap);
        uint256 availableSwarm = swarmBalances[swarmId][line.asset];
        if (amount > availableSwarm) revert InsufficientSwarmBalance(swarmId, line.asset, amount, availableSwarm);

        line.reserved += amount;
        reservationId = keccak256(abi.encode(budgetLineId, amount, intentRoot, block.timestamp));
        reservedAmountByReservation[reservationId] = amount;
        emit SwarmBudgetReserved(swarmId, budgetLineId, reservationId, amount, intentRoot);
    }

    function spend(bytes32 swarmId, bytes32 budgetLineId, address recipient, uint256 amount, bytes32 receiptRoot)
        external
        nonReentrant
        onlyAuthorizedOperator
    {
        if (recipient == address(0)) revert ZeroOperator();
        if (amount == 0) revert ZeroAmount();
        BudgetLine storage line = _requireLine(swarmId, budgetLineId);
        uint256 availableLine = line.cap - line.spent;
        if (amount > availableLine) revert BudgetCapExceeded(budgetLineId, line.spent + amount, line.cap);
        uint256 availableSwarm = swarmBalances[swarmId][line.asset];
        if (amount > availableSwarm) revert InsufficientSwarmBalance(swarmId, line.asset, amount, availableSwarm);

        line.spent += amount;
        swarmBalances[swarmId][line.asset] -= amount;
        bytes32 spendId = keccak256(abi.encode(budgetLineId, recipient, amount, receiptRoot, block.timestamp));
        if (!IERC20SettlementToken(line.asset).transfer(recipient, amount)) revert TransferFailed();
        emit SwarmBudgetSpent(swarmId, budgetLineId, spendId, recipient, line.asset, amount, receiptRoot);
    }

    function releaseReservation(bytes32 swarmId, bytes32 budgetLineId, bytes32 reservationId) external onlyAuthorizedOperator {
        BudgetLine storage line = _requireLine(swarmId, budgetLineId);
        uint256 reservedAmount = reservedAmountByReservation[reservationId];
        if (reservedAmount == 0) revert ReservationNotFound(reservationId);
        line.reserved -= reservedAmount;
        delete reservedAmountByReservation[reservationId];
        emit SwarmBudgetReleased(swarmId, budgetLineId, reservationId, reservedAmount);
    }

    function getBudgetLine(bytes32 budgetLineId) external view returns (BudgetLine memory) {
        BudgetLine memory line = _budgetLines[budgetLineId];
        if (line.budgetLineId == bytes32(0)) revert BudgetLineNotFound(budgetLineId);
        return line;
    }

    function _requireLine(bytes32 swarmId, bytes32 budgetLineId) private view returns (BudgetLine storage line) {
        line = _budgetLines[budgetLineId];
        if (line.budgetLineId == bytes32(0)) revert BudgetLineNotFound(budgetLineId);
        if (!line.active || line.swarmId != swarmId) revert InactiveBudgetLine(budgetLineId);
    }
}
