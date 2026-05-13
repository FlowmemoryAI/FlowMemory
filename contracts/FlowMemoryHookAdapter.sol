// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFlowMemoryHookAdapter} from "./interfaces/IFlowMemoryHookAdapter.sol";

/// @title FlowMemoryHookAdapter
/// @notice Dependency-light scaffold for future Uniswap v4 hook integration.
/// @dev This is not a production hook. It performs no custom accounting, no
/// dynamic fees, no token custody, and no external protocol calls. It cannot
/// know txHash or logIndex during execution; indexers derive receipt metadata.
contract FlowMemoryHookAdapter is IFlowMemoryHookAdapter {
    bytes4 public constant AFTER_SWAP_SELECTOR = bytes4(keccak256("afterSwap(address,bytes32,bytes32,bytes32,bytes)"));

    error ZeroSender();
    error ZeroPoolId();
    error ZeroRootfieldId();
    error ZeroCommitment();

    function afterSwap(address sender, bytes32 poolId, bytes32 rootfieldId, bytes32 commitment, bytes calldata hookData)
        external
        returns (bytes4 selector)
    {
        if (sender == address(0)) revert ZeroSender();
        if (poolId == bytes32(0)) revert ZeroPoolId();
        if (rootfieldId == bytes32(0)) revert ZeroRootfieldId();
        if (commitment == bytes32(0)) revert ZeroCommitment();

        emit AfterSwapObserved(msg.sender, sender, poolId, rootfieldId, commitment, keccak256(hookData));
        return AFTER_SWAP_SELECTOR;
    }
}
