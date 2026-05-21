// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IUnderwriterPool {
    enum PoolType {
        StakeCapacityPool,
        UsdcRecoursePool
    }

    function poolType() external view returns (PoolType);
    function asset() external view returns (address);
    function totalDeposited() external view returns (uint256);
    function totalAllocated() external view returns (uint256);
    function totalLocked() external view returns (uint256);
    function availableCapacity() external view returns (uint256);
    function maxCoveragePerTask() external view returns (uint256);

    function canBackTask(bytes32 taskClass, uint256 payout, uint8 riskTier) external view returns (bool);
    function lockCoverage(bytes32 taskId, uint256 amount) external;
    function releaseForTask(bytes32 taskId) external returns (uint256 released);
    function payClaim(bytes32 taskId, address recipient, uint256 amount, bytes32 reason) external returns (uint256 paid);
}
