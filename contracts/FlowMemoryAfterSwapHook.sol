// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFlowMemoryHookAdapter} from "./interfaces/IFlowMemoryHookAdapter.sol";
import {IUniswapV4SwapHookLike} from "./interfaces/IUniswapV4SwapHookLike.sol";
import {IFlowPulse, FlowPulseTypes} from "./FlowPulse.sol";
import {FlowMemoryHookFlags} from "./FlowMemoryHookPlanner.sol";

/// @title FlowMemoryAfterSwapHook
/// @notice Production-shaped Uniswap v4 afterSwap hook path for Base Sepolia planning.
/// @dev This is still not a production deployment. It is PoolManager-gated,
/// returns zero hook delta, takes no token custody, exposes no fee override
/// path, and cannot know txHash or logIndex during execution.
contract FlowMemoryAfterSwapHook is IUniswapV4SwapHookLike, IFlowPulse {
    bytes4 public constant UNISWAP_V4_AFTER_SWAP_SELECTOR = IUniswapV4SwapHookLike.afterSwap.selector;
    uint160 public constant HOOK_PERMISSION_FLAGS = FlowMemoryHookFlags.FLOWMEMORY_AFTER_SWAP_FLAGS;
    string public constant DEFAULT_AFTER_SWAP_URI = "flowmemory://uniswap-v4/after-swap";

    address public immutable poolManager;

    mapping(bytes32 rootfieldId => uint64 sequence) private _rootfieldSequences;

    error ZeroPoolManager();
    error UnauthorizedPoolManager(address caller);
    error ZeroSender();
    error ZeroRootfieldId();
    error ZeroCommitment();
    error EmptyHookData();
    error TimestampOverflow(uint256 timestamp);

    constructor(address poolManager_) {
        if (poolManager_ == address(0)) revert ZeroPoolManager();
        poolManager = poolManager_;
    }

    event AfterSwapObserved(
        address indexed caller,
        address indexed sender,
        bytes32 indexed poolId,
        bytes32 rootfieldId,
        bytes32 commitment,
        bytes32 hookDataHash
    );

    function afterSwap(
        address sender,
        IUniswapV4SwapHookLike.PoolKey calldata key,
        IUniswapV4SwapHookLike.SwapParams calldata params,
        int256 swapDelta,
        bytes calldata hookData
    ) external returns (bytes4 selector, int128 hookDelta) {
        if (msg.sender != poolManager) revert UnauthorizedPoolManager(msg.sender);
        if (sender == address(0)) revert ZeroSender();
        if (hookData.length == 0) revert EmptyHookData();

        IFlowMemoryHookAdapter.FlowMemorySwapHookData memory decoded =
            abi.decode(hookData, (IFlowMemoryHookAdapter.FlowMemorySwapHookData));
        bytes32 poolId = _poolIdFor(key);
        bytes memory pulseContext =
            abi.encode(params.zeroForOne, params.amountSpecified, params.sqrtPriceLimitX96, swapDelta, hookData);

        _emitSwapMemorySignal(
            sender,
            poolId,
            decoded.rootfieldId,
            decoded.commitment,
            decoded.parentPulseId,
            pulseContext,
            bytes(decoded.uri).length == 0 ? DEFAULT_AFTER_SWAP_URI : decoded.uri
        );

        return (UNISWAP_V4_AFTER_SWAP_SELECTOR, 0);
    }

    function encodeSwapHookData(bytes32 rootfieldId, bytes32 commitment, bytes32 parentPulseId, string calldata uri)
        external
        pure
        returns (bytes memory hookData)
    {
        return abi.encode(
            IFlowMemoryHookAdapter.FlowMemorySwapHookData({
                rootfieldId: rootfieldId, commitment: commitment, parentPulseId: parentPulseId, uri: uri
            })
        );
    }

    function hasPermissionedHookAddress() external view returns (bool) {
        return FlowMemoryHookFlags.hasOnlyFlowMemoryAfterSwapFlag(address(this));
    }

    function _emitSwapMemorySignal(
        address sender,
        bytes32 poolId,
        bytes32 rootfieldId,
        bytes32 commitment,
        bytes32 parentPulseId,
        bytes memory hookData,
        string memory uri
    ) private {
        if (rootfieldId == bytes32(0)) revert ZeroRootfieldId();
        if (commitment == bytes32(0)) revert ZeroCommitment();

        bytes32 hookDataHash = keccak256(hookData);
        uint64 sequence = _nextSequence(rootfieldId);
        uint64 occurredAt = _blockTimestamp();
        bytes32 pulseId = keccak256(
            abi.encode(
                FlowPulseTypes.SCHEMA_ID,
                block.chainid,
                address(this),
                poolManager,
                sender,
                poolId,
                rootfieldId,
                commitment,
                parentPulseId,
                hookDataHash,
                sequence
            )
        );

        emit AfterSwapObserved(poolManager, sender, poolId, rootfieldId, commitment, hookDataHash);
        emit FlowPulse(
            pulseId,
            rootfieldId,
            sender,
            FlowPulseTypes.SWAP_MEMORY_SIGNAL,
            poolId,
            commitment,
            parentPulseId,
            sequence,
            occurredAt,
            uri
        );
    }

    function _poolIdFor(IUniswapV4SwapHookLike.PoolKey calldata key) private pure returns (bytes32) {
        return keccak256(abi.encode(key.currency0, key.currency1, key.fee, key.tickSpacing, key.hooks));
    }

    function _nextSequence(bytes32 rootfieldId) private returns (uint64 sequence) {
        sequence = _rootfieldSequences[rootfieldId] + 1;
        _rootfieldSequences[rootfieldId] = sequence;
    }

    function _blockTimestamp() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert TimestampOverflow(block.timestamp);
        return uint64(block.timestamp);
    }
}
