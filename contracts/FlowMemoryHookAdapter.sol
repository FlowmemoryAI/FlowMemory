// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFlowMemoryHookAdapter} from "./interfaces/IFlowMemoryHookAdapter.sol";
import {IUniswapV4SwapHookLike} from "./interfaces/IUniswapV4SwapHookLike.sol";
import {IFlowPulse, FlowPulseTypes} from "./FlowPulse.sol";

/// @title FlowMemoryHookAdapter
/// @notice Dependency-light scaffold for future Uniswap v4 hook integration.
/// @dev This is not a production hook. It performs no custom accounting, no
/// dynamic fees, no token custody, and no external protocol calls. It cannot
/// know txHash or logIndex during execution; indexers derive receipt metadata.
contract FlowMemoryHookAdapter is IFlowMemoryHookAdapter, IUniswapV4SwapHookLike, IFlowPulse {
    bytes4 public constant AFTER_SWAP_SELECTOR = bytes4(keccak256("afterSwap(address,bytes32,bytes32,bytes32,bytes)"));
    bytes4 public constant UNISWAP_V4_AFTER_SWAP_SELECTOR = IUniswapV4SwapHookLike.afterSwap.selector;

    mapping(bytes32 rootfieldId => uint64 sequence) private _rootfieldSequences;

    error ZeroSender();
    error ZeroPoolId();
    error ZeroRootfieldId();
    error ZeroCommitment();
    error EmptyHookData();
    error TimestampOverflow(uint256 timestamp);

    function afterSwap(address sender, bytes32 poolId, bytes32 rootfieldId, bytes32 commitment, bytes calldata hookData)
        external
        returns (bytes4 selector)
    {
        if (sender == address(0)) revert ZeroSender();
        if (poolId == bytes32(0)) revert ZeroPoolId();
        if (rootfieldId == bytes32(0)) revert ZeroRootfieldId();
        if (commitment == bytes32(0)) revert ZeroCommitment();

        _emitSwapMemorySignal(
            sender,
            poolId,
            rootfieldId,
            commitment,
            bytes32(0),
            hookData,
            msg.sender,
            "flowmemory://uniswap-v4/after-swap"
        );
        return AFTER_SWAP_SELECTOR;
    }

    function afterSwap(
        address sender,
        IUniswapV4SwapHookLike.PoolKey calldata key,
        IUniswapV4SwapHookLike.SwapParams calldata params,
        int256 swapDelta,
        bytes calldata hookData
    ) external returns (bytes4 selector, int128 hookDelta) {
        if (sender == address(0)) revert ZeroSender();
        if (hookData.length == 0) revert EmptyHookData();

        FlowMemorySwapHookData memory decoded = abi.decode(hookData, (FlowMemorySwapHookData));
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
            msg.sender,
            bytes(decoded.uri).length == 0 ? "flowmemory://uniswap-v4/after-swap" : decoded.uri
        );

        return (UNISWAP_V4_AFTER_SWAP_SELECTOR, 0);
    }

    function encodeSwapHookData(bytes32 rootfieldId, bytes32 commitment, bytes32 parentPulseId, string calldata uri)
        external
        pure
        returns (bytes memory hookData)
    {
        return abi.encode(
            FlowMemorySwapHookData({
                rootfieldId: rootfieldId, commitment: commitment, parentPulseId: parentPulseId, uri: uri
            })
        );
    }

    function _emitSwapMemorySignal(
        address sender,
        bytes32 poolId,
        bytes32 rootfieldId,
        bytes32 commitment,
        bytes32 parentPulseId,
        bytes memory hookData,
        address caller,
        string memory uri
    ) private {
        if (poolId == bytes32(0)) revert ZeroPoolId();
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
                caller,
                sender,
                poolId,
                rootfieldId,
                commitment,
                parentPulseId,
                hookDataHash,
                sequence
            )
        );

        emit AfterSwapObserved(caller, sender, poolId, rootfieldId, commitment, hookDataHash);
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
