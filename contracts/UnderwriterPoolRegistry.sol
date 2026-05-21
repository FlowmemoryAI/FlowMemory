// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUnderwriterPool} from "./interfaces/IUnderwriterPool.sol";
import {TwoStepOwnable} from "./shared/TwoStepOwnable.sol";

contract UnderwriterPoolRegistry is TwoStepOwnable {
    struct PoolRecord {
        bool active;
        IUnderwriterPool.PoolType poolType;
        address asset;
        uint8 maxRiskTier;
    }

    mapping(address pool => PoolRecord record) private _pools;

    error ZeroPool();
    error PoolNotRegistered(address pool);
    error PoolAssetMismatch(address pool, address expected, address actual);

    event PoolRegistered(address indexed pool, IUnderwriterPool.PoolType poolType, address asset, uint8 maxRiskTier);
    event PoolStatusSet(address indexed pool, bool active);

    constructor(address initialOwner) TwoStepOwnable(initialOwner) {}

    function registerPool(address pool, IUnderwriterPool.PoolType poolType, address asset, uint8 maxRiskTier) external onlyOwner {
        if (pool == address(0)) revert ZeroPool();
        _pools[pool] = PoolRecord({active: true, poolType: poolType, asset: asset, maxRiskTier: maxRiskTier});
        emit PoolRegistered(pool, poolType, asset, maxRiskTier);
    }

    function setPoolStatus(address pool, bool active) external onlyOwner {
        if (_pools[pool].asset == address(0)) revert PoolNotRegistered(pool);
        _pools[pool].active = active;
        emit PoolStatusSet(pool, active);
    }

    function isPoolApproved(address pool) external view returns (bool) {
        return _pools[pool].active;
    }

    function getPool(address pool) external view returns (PoolRecord memory) {
        PoolRecord memory record = _pools[pool];
        if (record.asset == address(0)) revert PoolNotRegistered(pool);
        return record;
    }

    function requirePoolAsset(address pool, address expectedAsset) external view returns (PoolRecord memory record) {
        record = _pools[pool];
        if (record.asset == address(0)) revert PoolNotRegistered(pool);
        if (record.asset != expectedAsset) revert PoolAssetMismatch(pool, expectedAsset, record.asset);
    }
}
