// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseOnchainAgentMemory} from "../contracts/BaseOnchainAgentMemory.sol";

interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// @title DeployBaseAgentMemoryScout
/// @notice Foundry deployment script for the Base On-Chain Agent Memory task-scout contract.
/// @dev This is a bounded Base Sepolia/local-test deployment surface only. It does not
/// configure production operators, verifier networks, tokenomics, or a public keeper layer.
contract DeployBaseAgentMemoryScout {
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

    error UnexpectedChain(uint256 expected, uint256 actual);

    struct Deployment {
        address baseOnchainAgentMemory;
    }

    event BaseAgentMemoryScoutDeployed(address indexed baseOnchainAgentMemory);

    function run() external returns (Deployment memory deployment) {
        if (block.chainid != BASE_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(BASE_SEPOLIA_CHAIN_ID, block.chainid);
        }

        VM.startBroadcast();
        deployment = Deployment({baseOnchainAgentMemory: address(new BaseOnchainAgentMemory())});
        emit BaseAgentMemoryScoutDeployed(deployment.baseOnchainAgentMemory);
        VM.stopBroadcast();
    }
}
