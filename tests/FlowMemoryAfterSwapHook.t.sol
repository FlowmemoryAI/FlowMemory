// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FlowMemoryAfterSwapHook} from "../contracts/FlowMemoryAfterSwapHook.sol";
import {FlowMemoryHookPlanner} from "../contracts/FlowMemoryHookPlanner.sol";
import {IUniswapV4SwapHookLike} from "../contracts/interfaces/IUniswapV4SwapHookLike.sol";

interface FlowMemoryAfterSwapVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract FlowMemoryAfterSwapUnauthorizedCaller {
    function callAfterSwap(
        FlowMemoryAfterSwapHook hook,
        address sender,
        IUniswapV4SwapHookLike.PoolKey calldata key,
        IUniswapV4SwapHookLike.SwapParams calldata params,
        int256 swapDelta,
        bytes calldata hookData
    ) external returns (bytes4 selector, int128 hookDelta) {
        return hook.afterSwap(sender, key, params, swapDelta, hookData);
    }
}

contract FlowMemoryAfterSwapHookTest {
    FlowMemoryAfterSwapVm private constant vm =
        FlowMemoryAfterSwapVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FLOWPULSE_SIGNATURE =
        keccak256("FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)");
    bytes32 private constant AFTER_SWAP_OBSERVED_SIGNATURE =
        keccak256("AfterSwapObserved(address,address,bytes32,bytes32,bytes32,bytes32)");

    error AssertionFailed();

    function testPlannerDefinesAfterSwapOnlyPermissionTarget() public {
        FlowMemoryHookPlanner planner = new FlowMemoryHookPlanner();
        FlowMemoryHookPlanner.HookPermissions memory permissions = planner.targetPermissions();

        _assertTrue(planner.FLOWMEMORY_AFTER_SWAP_FLAGS() == planner.AFTER_SWAP_FLAG());
        _assertTrue(planner.FLOWMEMORY_AFTER_SWAP_FLAGS() == uint160(1 << 6));
        _assertTrue(permissions.afterSwap);
        _assertTrue(!permissions.beforeSwap);
        _assertTrue(!permissions.afterSwapReturnDelta);
        _assertTrue(!permissions.beforeSwapReturnDelta);
        _assertTrue(!permissions.afterAddLiquidity);
        _assertTrue(!permissions.afterRemoveLiquidity);
        _assertTrue(!permissions.beforeDonate);
        _assertTrue(!permissions.afterDonate);
    }

    function testPlannerRejectsCustomAccountingAndExtraHookFlags() public {
        FlowMemoryHookPlanner planner = new FlowMemoryHookPlanner();
        address afterSwapOnly = address(uint160(planner.AFTER_SWAP_FLAG()));
        address afterSwapWithReturnDelta =
            address(uint160(planner.AFTER_SWAP_FLAG() | planner.AFTER_SWAP_RETURNS_DELTA_FLAG()));
        address beforeAndAfterSwap = address(uint160(planner.BEFORE_SWAP_FLAG() | planner.AFTER_SWAP_FLAG()));

        _assertTrue(planner.hasOnlyAfterSwapFlag(afterSwapOnly));
        _assertTrue(!planner.hasOnlyAfterSwapFlag(afterSwapWithReturnDelta));
        _assertTrue(!planner.hasOnlyAfterSwapFlag(beforeAndAfterSwap));
    }

    function testPlannerMinesBaseSepoliaCreate2AddressWithTargetFlags() public {
        FlowMemoryHookPlanner planner = new FlowMemoryHookPlanner();
        bytes32 initCodeHash = _afterSwapHookInitCodeHash(planner.BASE_SEPOLIA_POOL_MANAGER());

        FlowMemoryHookPlanner.HookPlan memory plan = planner.planBaseSepolia(initCodeHash, 0, 100_000);

        _assertTrue(plan.chainId == planner.BASE_SEPOLIA_CHAIN_ID());
        _assertTrue(plan.poolManager == planner.BASE_SEPOLIA_POOL_MANAGER());
        _assertTrue(plan.create2Deployer == planner.CREATE2_DEPLOYER());
        _assertTrue(plan.targetFlags == planner.FLOWMEMORY_AFTER_SWAP_FLAGS());
        _assertTrue(plan.initCodeHash == initCodeHash);
        _assertTrue(planner.hasOnlyAfterSwapFlag(plan.hookAddress));
        _assertTrue(plan.hookAddress == planner.computeCreate2Address(plan.create2Deployer, plan.salt, initCodeHash));
    }

    function testAfterSwapHookEmitsFlowPulseAndReturnsZeroHookDelta() public {
        FlowMemoryAfterSwapHook hook = new FlowMemoryAfterSwapHook(address(this));
        bytes32 rootfieldId = keccak256("rootfield.true-hook");
        bytes32 commitment = keccak256("hook.commitment.true");
        bytes32 parentPulseId = keccak256("parent.pulse.true");
        IUniswapV4SwapHookLike.PoolKey memory key = _samplePoolKey(address(hook));
        IUniswapV4SwapHookLike.SwapParams memory params = _sampleSwapParams();
        bytes memory hookData =
            hook.encodeSwapHookData(rootfieldId, commitment, parentPulseId, "flowmemory://base-sepolia/after-swap");

        vm.recordLogs();
        (bytes4 selector, int128 hookDelta) = hook.afterSwap(address(this), key, params, int256(123), hookData);
        FlowMemoryAfterSwapVm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 poolId = keccak256(abi.encode(key.currency0, key.currency1, key.fee, key.tickSpacing, key.hooks));
        _assertTrue(selector == hook.UNISWAP_V4_AFTER_SWAP_SELECTOR());
        _assertTrue(hookDelta == 0);
        _assertTrue(logs.length == 2);
        _assertTrue(logs[0].topics[0] == AFTER_SWAP_OBSERVED_SIGNATURE);
        _assertTrue(logs[1].topics[0] == FLOWPULSE_SIGNATURE);
        _assertTrue(logs[1].topics[2] == rootfieldId);
        _assertTrue(logs[1].topics[3] == bytes32(uint256(uint160(address(this)))));
        _assertSwapPulseData(logs[1].data, poolId, commitment, parentPulseId, "flowmemory://base-sepolia/after-swap");
    }

    function testAfterSwapHookIsPoolManagerGated() public {
        FlowMemoryAfterSwapHook hook = new FlowMemoryAfterSwapHook(address(this));
        FlowMemoryAfterSwapUnauthorizedCaller caller = new FlowMemoryAfterSwapUnauthorizedCaller();
        IUniswapV4SwapHookLike.PoolKey memory key = _samplePoolKey(address(hook));
        IUniswapV4SwapHookLike.SwapParams memory params = _sampleSwapParams();
        bytes memory hookData =
            hook.encodeSwapHookData(keccak256("rootfield.gated"), keccak256("commitment.gated"), bytes32(0), "");

        vm.expectRevert(
            abi.encodeWithSelector(FlowMemoryAfterSwapHook.UnauthorizedPoolManager.selector, address(caller))
        );
        caller.callAfterSwap(hook, address(this), key, params, int256(0), hookData);
    }

    function testAfterSwapHookRejectsInvalidHookDataWithoutCustodyOrFeeState() public {
        FlowMemoryAfterSwapHook hook = new FlowMemoryAfterSwapHook(address(this));
        IUniswapV4SwapHookLike.PoolKey memory key = _samplePoolKey(address(hook));
        IUniswapV4SwapHookLike.SwapParams memory params = _sampleSwapParams();

        vm.expectRevert(FlowMemoryAfterSwapHook.EmptyHookData.selector);
        hook.afterSwap(address(this), key, params, int256(0), "");

        bytes memory zeroRootfieldData =
            hook.encodeSwapHookData(bytes32(0), keccak256("commitment.zero-rootfield"), bytes32(0), "");
        vm.expectRevert(FlowMemoryAfterSwapHook.ZeroRootfieldId.selector);
        hook.afterSwap(address(this), key, params, int256(0), zeroRootfieldData);

        bytes memory zeroCommitmentData =
            hook.encodeSwapHookData(keccak256("rootfield.zero-commitment"), bytes32(0), bytes32(0), "");
        vm.expectRevert(FlowMemoryAfterSwapHook.ZeroCommitment.selector);
        hook.afterSwap(address(this), key, params, int256(0), zeroCommitmentData);

        (bool success,) = address(hook).call("");
        _assertTrue(!success);
        _assertTrue(address(hook).balance == 0);
    }

    function testHookEventSchemasExcludeTxHashAndLogIndexAssumptions() public pure {
        bytes32 flowPulseWithReceiptMetadata = keccak256(
            "FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string,bytes32,uint256)"
        );
        bytes32 afterSwapObservedWithReceiptMetadata =
            keccak256("AfterSwapObserved(address,address,bytes32,bytes32,bytes32,bytes32,bytes32,uint256)");

        _assertTrue(FLOWPULSE_SIGNATURE != flowPulseWithReceiptMetadata);
        _assertTrue(AFTER_SWAP_OBSERVED_SIGNATURE != afterSwapObservedWithReceiptMetadata);
    }

    function _afterSwapHookInitCodeHash(address poolManager) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(FlowMemoryAfterSwapHook).creationCode, abi.encode(poolManager)));
    }

    function _samplePoolKey(address hooks) private pure returns (IUniswapV4SwapHookLike.PoolKey memory) {
        return IUniswapV4SwapHookLike.PoolKey({
            currency0: address(0x1000), currency1: address(0x2000), fee: 3000, tickSpacing: 60, hooks: hooks
        });
    }

    function _sampleSwapParams() private pure returns (IUniswapV4SwapHookLike.SwapParams memory) {
        return IUniswapV4SwapHookLike.SwapParams({zeroForOne: true, amountSpecified: -1 ether, sqrtPriceLimitX96: 42});
    }

    function _assertSwapPulseData(
        bytes memory data,
        bytes32 expectedSubject,
        bytes32 expectedCommitment,
        bytes32 expectedParentPulseId,
        string memory expectedUri
    ) private pure {
        (
            uint8 pulseType,
            bytes32 subject,
            bytes32 flowPulseCommitment,
            bytes32 decodedParentPulseId,
            uint64 sequence,
            uint64 occurredAt,
            string memory uri
        ) = abi.decode(data, (uint8, bytes32, bytes32, bytes32, uint64, uint64, string));

        _assertTrue(pulseType == 4);
        _assertTrue(subject == expectedSubject);
        _assertTrue(flowPulseCommitment == expectedCommitment);
        _assertTrue(decodedParentPulseId == expectedParentPulseId);
        _assertTrue(sequence == 1);
        _assertTrue(occurredAt > 0);
        _assertTrue(keccak256(bytes(uri)) == keccak256(bytes(expectedUri)));
    }

    function _assertTrue(bool condition) private pure {
        if (!condition) revert AssertionFailed();
    }
}
