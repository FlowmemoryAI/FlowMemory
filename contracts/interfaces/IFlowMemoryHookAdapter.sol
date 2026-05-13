// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFlowMemoryHookAdapter {
    event AfterSwapObserved(
        address indexed caller,
        address indexed sender,
        bytes32 indexed poolId,
        bytes32 rootfieldId,
        bytes32 commitment,
        bytes32 hookDataHash
    );

    function afterSwap(address sender, bytes32 poolId, bytes32 rootfieldId, bytes32 commitment, bytes calldata hookData)
        external
        returns (bytes4 selector);
}
