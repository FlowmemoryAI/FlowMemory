// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FlowMemoryAfterSwapHook} from "../contracts/FlowMemoryAfterSwapHook.sol";
import {FlowMemoryHookFlags} from "../contracts/FlowMemoryHookPlanner.sol";

interface HookDeployVm {
    function startBroadcast() external;
    function stopBroadcast() external;
    function envBytes32(string calldata key) external returns (bytes32 value);
    function envOr(string calldata key, address defaultValue) external returns (address value);
}

/// @title DeployFlowMemoryAfterSwapHook
/// @notice Base Sepolia CREATE2 deploy script for the real FlowMemory afterSwap hook candidate.
/// @dev This deploys only the hook contract. Pool initialization, liquidity, and swap proof
/// are separate operator steps because they depend on chosen testnet currencies.
contract DeployFlowMemoryAfterSwapHook {
    HookDeployVm private constant VM = HookDeployVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    address public constant BASE_SEPOLIA_POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address public constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    struct Deployment {
        uint256 chainId;
        address poolManager;
        address create2Deployer;
        bytes32 salt;
        bytes32 initCodeHash;
        address hookAddress;
        bool alreadyDeployed;
    }

    error UnexpectedChain(uint256 expected, uint256 actual);
    error UnexpectedPoolManager(address expected, address actual);
    error ZeroSalt();
    error HookAddressNotAfterSwapOnly(address hookAddress);
    error Create2DeploymentFailed(address deployer, bytes32 salt);
    error HookCodeMissing(address hookAddress);

    event FlowMemoryAfterSwapHookDeployed(
        address indexed hookAddress,
        address indexed poolManager,
        address indexed create2Deployer,
        bytes32 salt,
        bytes32 initCodeHash,
        bool alreadyDeployed
    );

    function run() external returns (Deployment memory deployment) {
        if (block.chainid != BASE_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(BASE_SEPOLIA_CHAIN_ID, block.chainid);
        }

        address poolManager = VM.envOr("BASE_SEPOLIA_POOL_MANAGER", BASE_SEPOLIA_POOL_MANAGER);
        if (poolManager != BASE_SEPOLIA_POOL_MANAGER) {
            revert UnexpectedPoolManager(BASE_SEPOLIA_POOL_MANAGER, poolManager);
        }

        bytes32 salt = VM.envBytes32("FLOWMEMORY_HOOK_SALT");
        if (salt == bytes32(0)) {
            revert ZeroSalt();
        }

        bytes memory initCode = abi.encodePacked(type(FlowMemoryAfterSwapHook).creationCode, abi.encode(poolManager));
        bytes32 initCodeHash = keccak256(initCode);
        address hookAddress = computeCreate2Address(CREATE2_DEPLOYER, salt, initCodeHash);
        if (!FlowMemoryHookFlags.hasOnlyFlowMemoryAfterSwapFlag(hookAddress)) {
            revert HookAddressNotAfterSwapOnly(hookAddress);
        }

        bool alreadyDeployed = hookAddress.code.length > 0;
        if (!alreadyDeployed) {
            VM.startBroadcast();
            (bool ok,) = CREATE2_DEPLOYER.call(bytes.concat(salt, initCode));
            VM.stopBroadcast();
            if (!ok) {
                revert Create2DeploymentFailed(CREATE2_DEPLOYER, salt);
            }
            if (hookAddress.code.length == 0) {
                revert HookCodeMissing(hookAddress);
            }
        }

        deployment = Deployment({
            chainId: BASE_SEPOLIA_CHAIN_ID,
            poolManager: poolManager,
            create2Deployer: CREATE2_DEPLOYER,
            salt: salt,
            initCodeHash: initCodeHash,
            hookAddress: hookAddress,
            alreadyDeployed: alreadyDeployed
        });

        emit FlowMemoryAfterSwapHookDeployed({
            hookAddress: hookAddress,
            poolManager: poolManager,
            create2Deployer: CREATE2_DEPLOYER,
            salt: salt,
            initCodeHash: initCodeHash,
            alreadyDeployed: alreadyDeployed
        });
    }

    function computeCreate2Address(address deployer, bytes32 salt, bytes32 initCodeHash)
        public
        pure
        returns (address hookAddress)
    {
        bytes32 digest = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash));
        hookAddress = address(uint160(uint256(digest)));
    }
}
