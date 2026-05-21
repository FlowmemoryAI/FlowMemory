// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20SettlementToken} from "./interfaces/IERC20SettlementToken.sol";
import {TwoStepOwnable} from "./shared/TwoStepOwnable.sol";

/// @title TaskBondEscrow
/// @notice Isolated settlement-token custody for Agent Bonds v1 local/test and capped pilot flows.
contract TaskBondEscrow is TwoStepOwnable {
    IERC20SettlementToken public immutable settlementToken;
    address public manager;
    uint256 public reserveBalance;

    mapping(bytes32 taskId => uint256 amount) private _lockedByTask;
    mapping(address account => uint256 amount) private _withdrawable;

    bool private _entered;

    error NotManager(address caller);
    error ZeroToken();
    error ZeroManager();
    error ZeroTaskId();
    error ZeroAccount();
    error ZeroAmount();
    error ReentrantCall();
    error InsufficientLocked(bytes32 taskId, uint256 available, uint256 requested);
    error InsufficientReserve(uint256 available, uint256 requested);
    error TransferFailed();

    event ManagerSet(address indexed previousManager, address indexed newManager);
    event Locked(bytes32 indexed taskId, address indexed payer, uint256 amount);
    event Released(bytes32 indexed taskId, address indexed account, uint256 amount);
    event Reserved(bytes32 indexed taskId, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event ReserveWithdrawn(address indexed account, uint256 amount);

    modifier onlyManager() {
        if (msg.sender != manager) revert NotManager(msg.sender);
        _;
    }

    modifier nonReentrant() {
        if (_entered) revert ReentrantCall();
        _entered = true;
        _;
        _entered = false;
    }

    constructor(address settlementToken_, address initialOwner) TwoStepOwnable(initialOwner) {
        if (settlementToken_ == address(0)) revert ZeroToken();
        settlementToken = IERC20SettlementToken(settlementToken_);
    }

    function setManager(address manager_) external onlyOwner {
        if (manager_ == address(0)) revert ZeroManager();
        address previousManager = manager;
        manager = manager_;
        emit ManagerSet(previousManager, manager_);
    }

    function lockFrom(bytes32 taskId, address payer, uint256 amount) external onlyManager nonReentrant {
        if (taskId == bytes32(0)) revert ZeroTaskId();
        if (payer == address(0)) revert ZeroAccount();
        if (amount == 0) revert ZeroAmount();
        _lockedByTask[taskId] += amount;
        emit Locked(taskId, payer, amount);
        // slither-disable-next-line arbitrary-send-erc20
        if (!settlementToken.transferFrom(payer, address(this), amount)) revert TransferFailed();
    }

    function releaseTo(bytes32 taskId, address account, uint256 amount) external onlyManager {
        _decreaseLocked(taskId, amount);
        if (account == address(0)) revert ZeroAccount();
        _withdrawable[account] += amount;
        emit Released(taskId, account, amount);
    }

    function moveToReserve(bytes32 taskId, uint256 amount) external onlyManager {
        _decreaseLocked(taskId, amount);
        reserveBalance += amount;
        emit Reserved(taskId, amount);
    }

    function withdraw() external nonReentrant {
        uint256 amount = _withdrawable[msg.sender];
        if (amount == 0) revert ZeroAmount();
        _withdrawable[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);
        if (!settlementToken.transfer(msg.sender, amount)) revert TransferFailed();
    }

    function withdrawReserve(address account, uint256 amount) external onlyOwner nonReentrant {
        if (account == address(0)) revert ZeroAccount();
        if (amount == 0) revert ZeroAmount();
        if (reserveBalance < amount) revert InsufficientReserve(reserveBalance, amount);
        reserveBalance -= amount;
        emit ReserveWithdrawn(account, amount);
        if (!settlementToken.transfer(account, amount)) revert TransferFailed();
    }

    function lockedByTask(bytes32 taskId) external view returns (uint256) {
        return _lockedByTask[taskId];
    }

    function withdrawable(address account) external view returns (uint256) {
        return _withdrawable[account];
    }

    function _decreaseLocked(bytes32 taskId, uint256 amount) private {
        if (taskId == bytes32(0)) revert ZeroTaskId();
        if (amount == 0) revert ZeroAmount();
        uint256 locked = _lockedByTask[taskId];
        if (locked < amount) revert InsufficientLocked(taskId, locked, amount);
        _lockedByTask[taskId] = locked - amount;
    }
}
