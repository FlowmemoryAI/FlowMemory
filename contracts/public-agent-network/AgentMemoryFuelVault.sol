// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20SettlementToken} from "../interfaces/IERC20SettlementToken.sol";
import {TwoStepOwnable} from "../shared/TwoStepOwnable.sol";
import {ReentrancyGuard} from "../shared/ReentrancyGuard.sol";

contract AgentMemoryFuelVault is TwoStepOwnable, ReentrancyGuard {
    struct FuelAccount {
        bytes32 agentId;
        address owner;
        bytes32 classId;
        address token;
        uint256 balance;
        uint256 reserved;
        uint64 updatedAt;
    }

    struct FuelPolicy {
        bytes32 classId;
        address token;
        uint256 minInitialFuel;
        uint256 unitPrice;
        uint256 maxDebitPerStep;
        bool sponsorAllowed;
        bool active;
    }

    mapping(bytes32 agentId => FuelAccount account) private _fuelAccounts;
    mapping(bytes32 classId => FuelPolicy policy) public classFuelPolicies;
    mapping(address token => bool approved) public approvedFuelToken;
    mapping(address meter => bool authorized) public isAuthorizedMeter;
    mapping(address registrar => bool authorized) public isAuthorizedRegistrar;
    mapping(bytes32 reservationId => uint256 amount) public reservedAmountByReservation;

    error ZeroAgentId();
    error ZeroOwnerAddress();
    error ZeroClassId();
    error ZeroToken();
    error ZeroRegistrar();
    error ZeroMeter();
    error FuelAccountAlreadyExists(bytes32 agentId);
    error FuelAccountNotFound(bytes32 agentId);
    error UnauthorizedRegistrar(address caller);
    error UnauthorizedMeter(address caller);
    error UnauthorizedAccountOwner(bytes32 agentId, address caller);
    error UnapprovedFuelToken(address token);
    error InactiveFuelPolicy(bytes32 classId);
    error InvalidFuelToken(bytes32 agentId, address expected, address provided);
    error InitialFuelBelowMinimum(uint256 amount, uint256 minimum);
    error ZeroAmount();
    error InsufficientAvailableFuel(bytes32 agentId, uint256 requested, uint256 available);
    error ReservationNotFound(bytes32 reservationId);
    error ReservationExceedsAvailable(bytes32 reservationId, uint256 requested, uint256 available);
    error MaxDebitPerStepExceeded(uint256 requested, uint256 maximum);
    error TransferFailed();

    event ApprovedFuelTokenSet(address indexed token, bool approved);
    event AuthorizedMeterSet(address indexed meter, bool authorized);
    event AuthorizedRegistrarSet(address indexed registrar, bool authorized);
    event FuelPolicyUpdated(
        bytes32 indexed classId,
        address token,
        uint256 minInitialFuel,
        uint256 unitPrice,
        uint256 maxDebitPerStep,
        bool sponsorAllowed,
        bool active
    );
    event FuelAccountRegistered(bytes32 indexed agentId, address indexed owner, bytes32 indexed classId, address token);
    event MemoryFuelDeposited(bytes32 indexed agentId, address indexed payer, address token, uint256 amount);
    event MemoryFuelReserved(bytes32 indexed agentId, address token, uint256 amount, bytes32 reservationRoot);
    event MemoryFuelConsumed(bytes32 indexed agentId, address token, uint256 amount, uint256 units, bytes32 receiptRoot);
    event MemoryFuelRefunded(bytes32 indexed agentId, address indexed recipient, address token, uint256 amount);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    modifier onlyAuthorizedRegistrar() {
        if (!isAuthorizedRegistrar[msg.sender]) revert UnauthorizedRegistrar(msg.sender);
        _;
    }

    modifier onlyAuthorizedMeter() {
        if (!isAuthorizedMeter[msg.sender]) revert UnauthorizedMeter(msg.sender);
        _;
    }

    function setApprovedFuelToken(address token, bool approved) external onlyOwner {
        if (token == address(0)) revert ZeroToken();
        approvedFuelToken[token] = approved;
        emit ApprovedFuelTokenSet(token, approved);
    }

    function setAuthorizedMeter(address meter, bool authorized) external onlyOwner {
        if (meter == address(0)) revert ZeroMeter();
        isAuthorizedMeter[meter] = authorized;
        emit AuthorizedMeterSet(meter, authorized);
    }

    function setAuthorizedRegistrar(address registrar, bool authorized) external onlyOwner {
        if (registrar == address(0)) revert ZeroRegistrar();
        isAuthorizedRegistrar[registrar] = authorized;
        emit AuthorizedRegistrarSet(registrar, authorized);
    }

    function setFuelPolicy(FuelPolicy calldata policy) external onlyOwner {
        if (policy.classId == bytes32(0)) revert ZeroClassId();
        if (policy.token == address(0)) revert ZeroToken();
        classFuelPolicies[policy.classId] = policy;
        emit FuelPolicyUpdated(
            policy.classId,
            policy.token,
            policy.minInitialFuel,
            policy.unitPrice,
            policy.maxDebitPerStep,
            policy.sponsorAllowed,
            policy.active
        );
    }

    function registerFuelAccount(bytes32 agentId, address owner_, bytes32 classId, address token) external onlyAuthorizedRegistrar {
        if (agentId == bytes32(0)) revert ZeroAgentId();
        if (owner_ == address(0)) revert ZeroOwnerAddress();
        if (classId == bytes32(0)) revert ZeroClassId();
        if (token == address(0)) revert ZeroToken();
        if (_fuelAccounts[agentId].agentId != bytes32(0)) revert FuelAccountAlreadyExists(agentId);
        if (!approvedFuelToken[token]) revert UnapprovedFuelToken(token);

        FuelPolicy memory policy = classFuelPolicies[classId];
        if (!policy.active) revert InactiveFuelPolicy(classId);
        if (policy.token != token) revert InvalidFuelToken(agentId, policy.token, token);

        _fuelAccounts[agentId] = FuelAccount({
            agentId: agentId,
            owner: owner_,
            classId: classId,
            token: token,
            balance: 0,
            reserved: 0,
            updatedAt: uint64(block.timestamp)
        });
        emit FuelAccountRegistered(agentId, owner_, classId, token);
    }

    function depositFuel(bytes32 agentId, address payer, address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        FuelAccount storage account = _fuelAccounts[agentId];
        if (account.agentId == bytes32(0)) revert FuelAccountNotFound(agentId);
        if (token != account.token) revert InvalidFuelToken(agentId, account.token, token);
        if (!approvedFuelToken[token]) revert UnapprovedFuelToken(token);

        account.balance += amount;
        account.updatedAt = uint64(block.timestamp);
        if (!IERC20SettlementToken(token).transferFrom(payer, address(this), amount)) revert TransferFailed();
        emit MemoryFuelDeposited(agentId, payer, token, amount);
    }

    function reserveFuel(bytes32 agentId, uint256 amount, bytes32 reservationRoot) external onlyAuthorizedMeter {
        if (amount == 0) revert ZeroAmount();
        FuelAccount storage account = _fuelAccounts[agentId];
        if (account.agentId == bytes32(0)) revert FuelAccountNotFound(agentId);
        uint256 available = account.balance - account.reserved;
        if (amount > available) revert InsufficientAvailableFuel(agentId, amount, available);
        account.reserved += amount;
        account.updatedAt = uint64(block.timestamp);
        reservedAmountByReservation[reservationRoot] = amount;
        emit MemoryFuelReserved(agentId, account.token, amount, reservationRoot);
    }

    function consumeFuel(bytes32 agentId, uint256 units, bytes32 receiptRoot) external onlyAuthorizedMeter {
        if (units == 0) revert ZeroAmount();
        FuelAccount storage account = _fuelAccounts[agentId];
        if (account.agentId == bytes32(0)) revert FuelAccountNotFound(agentId);
        FuelPolicy memory policy = classFuelPolicies[account.classId];
        uint256 amount = units * policy.unitPrice;
        if (policy.maxDebitPerStep != 0 && amount > policy.maxDebitPerStep) {
            revert MaxDebitPerStepExceeded(amount, policy.maxDebitPerStep);
        }
        uint256 available = account.balance - account.reserved;
        if (amount > available) revert InsufficientAvailableFuel(agentId, amount, available);
        account.balance -= amount;
        account.updatedAt = uint64(block.timestamp);
        emit MemoryFuelConsumed(agentId, account.token, amount, units, receiptRoot);
    }

    function releaseReservation(bytes32 agentId, bytes32 reservationRoot) external onlyAuthorizedMeter {
        FuelAccount storage account = _fuelAccounts[agentId];
        if (account.agentId == bytes32(0)) revert FuelAccountNotFound(agentId);
        uint256 reservedAmount = reservedAmountByReservation[reservationRoot];
        if (reservedAmount == 0) revert ReservationNotFound(reservationRoot);
        if (reservedAmount > account.reserved) revert ReservationExceedsAvailable(reservationRoot, reservedAmount, account.reserved);
        account.reserved -= reservedAmount;
        account.updatedAt = uint64(block.timestamp);
        delete reservedAmountByReservation[reservationRoot];
    }

    function refundFuel(bytes32 agentId, address recipient, uint256 amount) external nonReentrant {
        FuelAccount storage account = _fuelAccounts[agentId];
        if (account.agentId == bytes32(0)) revert FuelAccountNotFound(agentId);
        if (recipient == address(0)) revert ZeroOwnerAddress();
        if (msg.sender != account.owner && !isAuthorizedMeter[msg.sender]) {
            revert UnauthorizedAccountOwner(agentId, msg.sender);
        }
        uint256 available = account.balance - account.reserved;
        if (amount > available) revert InsufficientAvailableFuel(agentId, amount, available);
        account.balance -= amount;
        account.updatedAt = uint64(block.timestamp);
        if (!IERC20SettlementToken(account.token).transfer(recipient, amount)) revert TransferFailed();
        emit MemoryFuelRefunded(agentId, recipient, account.token, amount);
    }

    function getFuelAccount(bytes32 agentId) external view returns (FuelAccount memory) {
        FuelAccount memory account = _fuelAccounts[agentId];
        if (account.agentId == bytes32(0)) revert FuelAccountNotFound(agentId);
        return account;
    }
}
