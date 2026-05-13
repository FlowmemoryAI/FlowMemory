// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFlowMemoryHookAdapter} from "./interfaces/IFlowMemoryHookAdapter.sol";
import {IFlowPulse, FlowPulseTypes} from "./FlowPulse.sol";

/// @title FlowMemoryHookAdapter
/// @notice Dependency-light scaffold for future Uniswap v4 hook integration.
/// @dev This is not a production hook. It performs no custom accounting, no
/// dynamic fees, no token custody, and no external protocol calls. It cannot
/// know txHash or logIndex during execution; indexers derive receipt metadata.
contract FlowMemoryHookAdapter is IFlowMemoryHookAdapter, IFlowPulse {
    bytes4 public constant AFTER_SWAP_SELECTOR = bytes4(keccak256("afterSwap(address,bytes32,bytes32,bytes32,bytes)"));

    mapping(bytes32 rootfieldId => uint64 sequence) private _rootfieldSequences;

    error ZeroSender();
    error ZeroPoolId();
    error ZeroRootfieldId();
    error ZeroCommitment();
    error TimestampOverflow(uint256 timestamp);

    function afterSwap(address sender, bytes32 poolId, bytes32 rootfieldId, bytes32 commitment, bytes calldata hookData)
        external
        returns (bytes4 selector)
    {
        if (sender == address(0)) revert ZeroSender();
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
                msg.sender,
                sender,
                poolId,
                rootfieldId,
                commitment,
                hookDataHash,
                sequence
            )
        );

        emit AfterSwapObserved(msg.sender, sender, poolId, rootfieldId, commitment, hookDataHash);
        emit FlowPulse(
            pulseId,
            rootfieldId,
            sender,
            FlowPulseTypes.SWAP_MEMORY_SIGNAL,
            poolId,
            commitment,
            bytes32(0),
            sequence,
            occurredAt,
            "flowmemory://uniswap-v4/after-swap"
        );
        return AFTER_SWAP_SELECTOR;
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
