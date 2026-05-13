// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseBridgeLockbox} from "../contracts/bridge/BaseBridgeLockbox.sol";
import {FlowChainSettlementSpine} from "../contracts/FlowChainSettlementSpine.sol";

interface BridgeSpineVm {
    function startBroadcast(address signer) external;
    function stopBroadcast() external;
    function envAddress(string calldata key) external returns (address value);
    function envBool(string calldata key) external returns (bool value);
    function envUint(string calldata key) external returns (uint256 value);
}

/// @title DeployBridgeSpine
/// @notice Foundry script for local Anvil and Base Sepolia bridge-spine testing.
/// @dev Dry-run with `forge script` by default. Add `--broadcast` only after
/// setting explicit test environment variables.
contract DeployBridgeSpine {
    BridgeSpineVm private constant VM = BridgeSpineVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Deployment {
        address lockbox;
        address settlementSpine;
        address owner;
        address releaseAuthority;
        address settlementSubmitter;
        address erc20Token;
        bool allowNative;
        bool allowErc20;
    }

    struct Config {
        address owner;
        address releaseAuthority;
        address settlementSubmitter;
        address erc20Token;
        bool allowNative;
        bool allowErc20;
        uint256 nativePerDepositCap;
        uint256 nativeTotalCap;
        uint256 erc20PerDepositCap;
        uint256 erc20TotalCap;
    }

    error Erc20TokenRequired();

    event FlowChainBridgeSpineDeployed(
        address indexed lockbox,
        address indexed settlementSpine,
        address indexed owner,
        address releaseAuthority,
        address settlementSubmitter,
        address erc20Token,
        bool allowNative,
        bool allowErc20
    );

    function run() external returns (Deployment memory deployment) {
        Config memory config = _readConfig();

        if (config.allowErc20 && config.erc20Token == address(0)) {
            revert Erc20TokenRequired();
        }

        VM.startBroadcast(config.owner);

        BaseBridgeLockbox lockbox = new BaseBridgeLockbox(config.owner, config.releaseAuthority);
        FlowChainSettlementSpine settlementSpine = new FlowChainSettlementSpine(config.owner);

        if (config.allowNative) {
            lockbox.configureToken(address(0), true, config.nativePerDepositCap, config.nativeTotalCap);
        }
        if (config.allowErc20) {
            lockbox.configureToken(config.erc20Token, true, config.erc20PerDepositCap, config.erc20TotalCap);
        }
        if (config.settlementSubmitter != config.owner) {
            settlementSpine.setSubmitterAuthorization(config.settlementSubmitter, true);
        }

        deployment = Deployment({
            lockbox: address(lockbox),
            settlementSpine: address(settlementSpine),
            owner: config.owner,
            releaseAuthority: config.releaseAuthority,
            settlementSubmitter: config.settlementSubmitter,
            erc20Token: config.erc20Token,
            allowNative: config.allowNative,
            allowErc20: config.allowErc20
        });

        emit FlowChainBridgeSpineDeployed(
            address(lockbox),
            address(settlementSpine),
            config.owner,
            config.releaseAuthority,
            config.settlementSubmitter,
            config.erc20Token,
            config.allowNative,
            config.allowErc20
        );

        VM.stopBroadcast();
    }

    function _readConfig() private returns (Config memory config) {
        config = Config({
            owner: VM.envAddress("FLOWCHAIN_BRIDGE_OWNER"),
            releaseAuthority: VM.envAddress("FLOWCHAIN_BRIDGE_RELEASE_AUTHORITY"),
            settlementSubmitter: VM.envAddress("FLOWCHAIN_SETTLEMENT_SUBMITTER"),
            erc20Token: VM.envAddress("FLOWCHAIN_BRIDGE_ERC20_TOKEN"),
            allowNative: VM.envBool("FLOWCHAIN_BRIDGE_ALLOW_NATIVE"),
            allowErc20: VM.envBool("FLOWCHAIN_BRIDGE_ALLOW_ERC20"),
            nativePerDepositCap: VM.envUint("FLOWCHAIN_BRIDGE_NATIVE_PER_DEPOSIT_CAP"),
            nativeTotalCap: VM.envUint("FLOWCHAIN_BRIDGE_NATIVE_TOTAL_CAP"),
            erc20PerDepositCap: VM.envUint("FLOWCHAIN_BRIDGE_ERC20_PER_DEPOSIT_CAP"),
            erc20TotalCap: VM.envUint("FLOWCHAIN_BRIDGE_ERC20_TOTAL_CAP")
        });
    }
}
