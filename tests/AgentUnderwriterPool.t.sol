// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentUnderwriterPool} from "../contracts/AgentUnderwriterPool.sol";
import {IUnderwriterPool} from "../contracts/interfaces/IUnderwriterPool.sol";

interface UnderwriterVm {
    function expectRevert(bytes calldata) external;
    function warp(uint256) external;
}

contract UnderwriterTestToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (balanceOf[msg.sender] < amount) return false;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (balanceOf[from] < amount || allowance[from][msg.sender] < amount) return false;
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract UnderwriterProviderActor {
    function approve(UnderwriterTestToken token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    function depositPool(AgentUnderwriterPool pool, uint256 amount) external {
        pool.deposit(amount);
    }

    function withdrawPool(AgentUnderwriterPool pool, uint256 shares) external {
        pool.withdraw(shares);
    }

    function requestWithdrawal(AgentUnderwriterPool pool) external {
        pool.requestWithdrawal();
    }
}

contract UnderwriterAllocatorActor {
    function lockCoverage(AgentUnderwriterPool pool, bytes32 taskId, uint256 amount) external {
        pool.lockCoverage(taskId, amount);
    }

    function releaseForTask(AgentUnderwriterPool pool, bytes32 taskId) external returns (uint256) {
        return pool.releaseForTask(taskId);
    }

    function payClaim(AgentUnderwriterPool pool, bytes32 taskId, address recipient, uint256 amount, bytes32 reason)
        external
        returns (uint256)
    {
        return pool.payClaim(taskId, recipient, amount, reason);
    }
}

contract AgentUnderwriterPoolTest {
    UnderwriterVm private constant vm = UnderwriterVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant USDC = 1_000_000;

    UnderwriterTestToken private token;
    AgentUnderwriterPool private pool;
    UnderwriterProviderActor private provider;
    UnderwriterAllocatorActor private allocator;

    function setUp() public {
        token = new UnderwriterTestToken();
        pool = new AgentUnderwriterPool(address(token), IUnderwriterPool.PoolType.UsdcRecoursePool, address(this), 100 * USDC, 3);
        provider = new UnderwriterProviderActor();
        allocator = new UnderwriterAllocatorActor();
        token.mint(address(provider), 1_000 * USDC);
        provider.approve(token, address(pool), type(uint256).max);
        pool.setAllocator(address(allocator), true);
        provider.depositPool(pool, 500 * USDC);
    }

    function testDepositLockReleaseAndWithdrawUnlockedLiquidity() public {
        require(pool.totalDeposited() == 500 * USDC, "deposit tracked");
        require(pool.availableCapacity() == 500 * USDC, "initial available capacity");

        allocator.lockCoverage(pool, bytes32(uint256(1)), 50 * USDC);
        require(pool.totalLocked() == 50 * USDC, "locked amount tracked");
        require(pool.availableCapacity() == 450 * USDC, "available reduced by lock");

        uint256 released = allocator.releaseForTask(pool, bytes32(uint256(1)));
        require(released == 50 * USDC, "release amount");
        require(pool.totalLocked() == 0, "all coverage released");
        require(pool.availableCapacity() == 500 * USDC, "capacity restored");

        provider.withdrawPool(pool, pool.sharesOf(address(provider)) / 2);
        require(token.balanceOf(address(provider)) > 500 * USDC, "provider withdrew unlocked liquidity");
    }

    function testClaimPaymentConsumesLockedCoverage() public {
        allocator.lockCoverage(pool, bytes32(uint256(2)), 80 * USDC);
        uint256 startingRecipient = token.balanceOf(address(this));
        uint256 paid = allocator.payClaim(pool, bytes32(uint256(2)), address(this), 50 * USDC, keccak256("claim"));
        require(paid == 50 * USDC, "paid requested amount");
        require(token.balanceOf(address(this)) == startingRecipient + 50 * USDC, "recipient paid");
        require(pool.totalLocked() == 0, "lock cleared after claim");
        require(pool.availableCapacity() == 450 * USDC, "claim reduced available capacity permanently");
    }

    function testCannotLockAboveAvailableOrWithoutAllocatorRole() public {
        vm.expectRevert(abi.encodeWithSelector(AgentUnderwriterPool.CoverageExceedsCap.selector, 200 * USDC, 100 * USDC));
        allocator.lockCoverage(pool, bytes32(uint256(3)), 200 * USDC);

        vm.expectRevert(abi.encodeWithSelector(AgentUnderwriterPool.NotAllocator.selector, address(this)));
        pool.lockCoverage(bytes32(uint256(4)), 10 * USDC);
    }

    function testEpochLossCapsLimitOpenCoverageAndClaims() public {
        pool.setPoolRiskControls(1 days, 120 * USDC, 0);
        allocator.lockCoverage(pool, bytes32(uint256(5)), 80 * USDC);
        require(pool.remainingEpochLossCapacity() == 40 * USDC, "open coverage consumes epoch capacity");

        vm.expectRevert(abi.encodeWithSelector(AgentUnderwriterPool.ClaimExceedsEpochCap.selector, 50 * USDC, 40 * USDC, block.timestamp / 1 days));
        allocator.lockCoverage(pool, bytes32(uint256(6)), 50 * USDC);

        allocator.payClaim(pool, bytes32(uint256(5)), address(this), 80 * USDC, keccak256("claim"));
        require(pool.lossPaidByEpoch(block.timestamp / 1 days) == 80 * USDC, "paid claim consumes epoch loss cap");
        require(pool.remainingEpochLossCapacity() == 40 * USDC, "remaining capacity reflects paid loss");

        vm.warp(block.timestamp + 1 days);
        require(pool.remainingEpochLossCapacity() == 120 * USDC, "new epoch resets loss capacity");
    }

    function testWithdrawalCooldownRequiresRequestAndDelay() public {
        pool.setPoolRiskControls(1 days, 200 * USDC, 2 days);
        uint256 halfShares = pool.sharesOf(address(provider)) / 2;

        vm.expectRevert(abi.encodeWithSelector(AgentUnderwriterPool.WithdrawalCooldownActive.selector, 0));
        provider.withdrawPool(pool, halfShares);

        provider.requestWithdrawal(pool);
        uint256 availableAt = block.timestamp + 2 days;
        require(pool.withdrawalAvailableAt(address(provider)) == availableAt, "withdrawal request timestamp");

        vm.expectRevert(abi.encodeWithSelector(AgentUnderwriterPool.WithdrawalCooldownActive.selector, availableAt));
        provider.withdrawPool(pool, halfShares);

        vm.warp(availableAt);
        provider.withdrawPool(pool, halfShares);
        require(pool.sharesOf(address(provider)) == halfShares, "shares burned after cooldown");
    }
}
