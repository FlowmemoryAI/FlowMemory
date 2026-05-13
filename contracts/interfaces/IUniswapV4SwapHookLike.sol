// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal ABI-compatible Uniswap v4 swap hook surface used by
/// FlowMemory without vendoring v4-core into the V0 repository.
/// @dev This mirrors the public afterSwap callback shape documented by
/// Uniswap v4. Currency, IHooks, and BalanceDelta are represented by their
/// ABI-compatible primitive forms so this interface remains dependency-light.
interface IUniswapV4SwapHookLike {
    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        int256 swapDelta,
        bytes calldata hookData
    ) external returns (bytes4 selector, int128 hookDelta);
}
