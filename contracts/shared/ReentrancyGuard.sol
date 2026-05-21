// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ReentrancyGuard
/// @notice Minimal non-upgradeable reentrancy guard for local/test public-network contracts.
abstract contract ReentrancyGuard {
    uint256 private _reentrancyState = 1;

    error ReentrantCall();

    modifier nonReentrant() {
        if (_reentrancyState != 1) revert ReentrantCall();
        _reentrancyState = 2;
        _;
        _reentrancyState = 1;
    }
}
