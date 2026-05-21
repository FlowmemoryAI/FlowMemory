// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20SettlementToken} from "./interfaces/IERC20SettlementToken.sol";
import {TwoStepOwnable} from "./shared/TwoStepOwnable.sol";

/// @title AgentStakeRegistry
/// @notice Stake-token eligibility and capacity accounting for Agent Bonds v1 local/test and capped pilot flows.
contract AgentStakeRegistry is TwoStepOwnable {
    IERC20SettlementToken public immutable stakeToken;
    address public slashAuthority;
    address public slashReceiver;

    uint256 public minAgentStake;
    uint256 public minVerifierStake;
    uint256 public capacityUnit;
    uint256 public capacityBondUnit;

    mapping(address account => uint256 amount) private _stakeOf;
    mapping(address agent => uint256 amount) private _openBondExposure;
    mapping(address account => uint256 amount) private _slashedStake;

    bool private _entered;

    error NotSlashAuthority(address caller);
    error ZeroToken();
    error ZeroAccount();
    error ZeroAmount();
    error ZeroCapacityUnit();
    error ReentrantCall();
    error InsufficientStake(address account, uint256 available, uint256 requested);
    error OpenExposure(address account, uint256 exposure);
    error TransferFailed();

    event ParametersSet(uint256 minAgentStake, uint256 minVerifierStake, uint256 capacityUnit, uint256 capacityBondUnit);
    event SlashAuthoritySet(address indexed previousAuthority, address indexed newAuthority);
    event SlashReceiverSet(address indexed previousReceiver, address indexed newReceiver);
    event StakeDeposited(address indexed account, uint256 amount, uint256 newStake);
    event StakeWithdrawn(address indexed account, uint256 amount, uint256 newStake);
    event OpenBondExposureIncreased(address indexed agent, uint256 amount, uint256 newExposure);
    event OpenBondExposureDecreased(address indexed agent, uint256 amount, uint256 newExposure);
    event StakeSlashed(address indexed account, address indexed receiver, uint256 amount, uint256 remainingStake);

    modifier onlySlashAuthority() {
        if (msg.sender != slashAuthority) revert NotSlashAuthority(msg.sender);
        _;
    }

    modifier nonReentrant() {
        if (_entered) revert ReentrantCall();
        _entered = true;
        _;
        _entered = false;
    }

    constructor(
        address stakeToken_,
        address initialOwner,
        uint256 minAgentStake_,
        uint256 minVerifierStake_,
        uint256 capacityUnit_,
        uint256 capacityBondUnit_
    ) TwoStepOwnable(initialOwner) {
        if (stakeToken_ == address(0)) revert ZeroToken();
        if (initialOwner == address(0)) revert ZeroAccount();
        if (capacityUnit_ == 0 || capacityBondUnit_ == 0) revert ZeroCapacityUnit();
        stakeToken = IERC20SettlementToken(stakeToken_);
        slashReceiver = initialOwner;
        _setParameters(minAgentStake_, minVerifierStake_, capacityUnit_, capacityBondUnit_);
    }

    function setParameters(
        uint256 minAgentStake_,
        uint256 minVerifierStake_,
        uint256 capacityUnit_,
        uint256 capacityBondUnit_
    ) external onlyOwner {
        _setParameters(minAgentStake_, minVerifierStake_, capacityUnit_, capacityBondUnit_);
    }

    function setSlashAuthority(address authority) external onlyOwner {
        if (authority == address(0)) revert ZeroAccount();
        address previousAuthority = slashAuthority;
        slashAuthority = authority;
        emit SlashAuthoritySet(previousAuthority, authority);
    }

    function setSlashReceiver(address receiver) external onlyOwner {
        if (receiver == address(0)) revert ZeroAccount();
        address previousReceiver = slashReceiver;
        slashReceiver = receiver;
        emit SlashReceiverSet(previousReceiver, receiver);
    }

    function depositStake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _stakeOf[msg.sender] += amount;
        emit StakeDeposited(msg.sender, amount, _stakeOf[msg.sender]);
        if (!stakeToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function withdrawStake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 stake = _stakeOf[msg.sender];
        if (stake < amount) revert InsufficientStake(msg.sender, stake, amount);
        uint256 remaining = stake - amount;
        uint256 exposure = _openBondExposure[msg.sender];
        if (exposure > 0 && remaining < minAgentStake) revert OpenExposure(msg.sender, exposure);
        _stakeOf[msg.sender] = remaining;
        emit StakeWithdrawn(msg.sender, amount, remaining);
        if (!stakeToken.transfer(msg.sender, amount)) revert TransferFailed();
    }

    function recordOpenBond(address agent, uint256 amount) external onlySlashAuthority {
        if (agent == address(0)) revert ZeroAccount();
        if (amount == 0) revert ZeroAmount();
        _openBondExposure[agent] += amount;
        emit OpenBondExposureIncreased(agent, amount, _openBondExposure[agent]);
    }

    function recordClosedBond(address agent, uint256 amount) external onlySlashAuthority {
        if (agent == address(0)) revert ZeroAccount();
        if (amount == 0) revert ZeroAmount();
        uint256 exposure = _openBondExposure[agent];
        if (exposure < amount) revert InsufficientStake(agent, exposure, amount);
        _openBondExposure[agent] = exposure - amount;
        emit OpenBondExposureDecreased(agent, amount, _openBondExposure[agent]);
    }

    function slashStake(address account, uint256 amount) external onlySlashAuthority nonReentrant {
        if (account == address(0)) revert ZeroAccount();
        if (amount == 0) revert ZeroAmount();
        uint256 stake = _stakeOf[account];
        if (stake < amount) revert InsufficientStake(account, stake, amount);
        _stakeOf[account] = stake - amount;
        _slashedStake[account] += amount;
        emit StakeSlashed(account, slashReceiver, amount, _stakeOf[account]);
        if (!stakeToken.transfer(slashReceiver, amount)) revert TransferFailed();
    }

    function isAgentEligible(address agent) public view returns (bool) {
        return _stakeOf[agent] >= minAgentStake;
    }

    function isVerifierEligible(address verifier) public view returns (bool) {
        return _stakeOf[verifier] >= minVerifierStake;
    }

    function canOpenAgentBond(address agent, uint256 additionalBond) external view returns (bool) {
        if (!isAgentEligible(agent)) {
            return false;
        }
        return _openBondExposure[agent] + additionalBond <= maxOpenBond(agent);
    }

    function capacityUnits(address agent) public view returns (uint256) {
        return _sqrt(_stakeOf[agent] / capacityUnit);
    }

    function maxOpenBond(address agent) public view returns (uint256) {
        uint256 units = capacityUnits(agent);
        if (units == 0) {
            return 0;
        }
        return capacityBondUnit * units * units;
    }

    function stakeOf(address account) external view returns (uint256) {
        return _stakeOf[account];
    }

    function openBondExposure(address agent) external view returns (uint256) {
        return _openBondExposure[agent];
    }

    function slashedStake(address account) external view returns (uint256) {
        return _slashedStake[account];
    }

    function _setParameters(
        uint256 minAgentStake_,
        uint256 minVerifierStake_,
        uint256 capacityUnit_,
        uint256 capacityBondUnit_
    ) private {
        if (capacityUnit_ == 0 || capacityBondUnit_ == 0) revert ZeroCapacityUnit();
        minAgentStake = minAgentStake_;
        minVerifierStake = minVerifierStake_;
        capacityUnit = capacityUnit_;
        capacityBondUnit = capacityBondUnit_;
        emit ParametersSet(minAgentStake_, minVerifierStake_, capacityUnit_, capacityBondUnit_);
    }

    function _sqrt(uint256 value) private pure returns (uint256 result) {
        if (value == 0) {
            return 0;
        }
        uint256 x = value;
        result = 1;
        if (x >= 2 ** 128) {
            x >>= 128;
            result <<= 64;
        }
        if (x >= 2 ** 64) {
            x >>= 64;
            result <<= 32;
        }
        if (x >= 2 ** 32) {
            x >>= 32;
            result <<= 16;
        }
        if (x >= 2 ** 16) {
            x >>= 16;
            result <<= 8;
        }
        if (x >= 2 ** 8) {
            x >>= 8;
            result <<= 4;
        }
        if (x >= 2 ** 4) {
            x >>= 4;
            result <<= 2;
        }
        if (x >= 2 ** 2) {
            result <<= 1;
        }
        for (uint256 i = 0; i < 5; i += 1) {
            result = (result + value / result) >> 1;
        }
        uint256 rounded = value / result;
        return result < rounded ? result : rounded;
    }
}
