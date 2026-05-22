// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseBridgeLockbox} from "../contracts/bridge/BaseBridgeLockbox.sol";
import {FlowMemorySettlementSpine} from "../contracts/FlowMemorySettlementSpine.sol";

interface BridgeSpineVm {
    function startBroadcast(address signer) external;
    function stopBroadcast() external;
    function envAddress(string calldata key) external returns (address value);
    function envBool(string calldata key) external returns (bool value);
    function envOr(string calldata key, bool defaultValue) external returns (bool value);
    function envUint(string calldata key) external returns (uint256 value);
}

/// @title DeployBridgeSpine
/// @notice Foundry script for local Anvil, Base Sepolia, and capped Base 8453 pilot bridge-spine deployment.
/// @dev Dry-run with `forge script` by default. Add `--broadcast` only after
/// setting explicit environment variables and the Base 8453 pilot ack when applicable.
contract DeployBridgeSpine {
    BridgeSpineVm private constant VM = BridgeSpineVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant NATIVE_TOKEN = address(0);
    uint256 internal constant LOCAL_ANVIL_CHAIN_ID = 31_337;
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint256 internal constant BASE_MAINNET_CHAIN_ID = 8_453;

    struct Deployment {
        address lockbox;
        address settlementSpine;
        uint256 chainId;
        address owner;
        address releaseAuthority;
        address settlementSubmitter;
        address erc20Token;
        bool allowNative;
        bool allowErc20;
        bool base8453PilotAck;
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
        bool base8453PilotAck;
    }

    error Erc20TokenRequired();
    error NoBridgeAssetAllowed();
    error UnsupportedBridgeSpineDeploymentChain(uint256 chainId);
    error Base8453PilotAckRequired();
    error PilotTotalCapRequired(address token);

    event FlowMemoryBridgeSpineDeployed(
        address indexed lockbox,
        address indexed settlementSpine,
        uint256 indexed chainId,
        address owner,
        address releaseAuthority,
        address settlementSubmitter,
        address erc20Token,
        bool allowNative,
        bool allowErc20,
        bool base8453PilotAck
    );

    function run() external returns (Deployment memory deployment) {
        Config memory config = _readConfig();
        uint256 chainId = _enforceDeploymentGate(config);
        _validateConfig(config, chainId);

        VM.startBroadcast(config.owner);

        BaseBridgeLockbox lockbox = new BaseBridgeLockbox(config.owner, config.releaseAuthority);
        FlowMemorySettlementSpine settlementSpine = new FlowMemorySettlementSpine(config.owner);

        if (config.allowNative) {
            lockbox.configureToken(NATIVE_TOKEN, true, config.nativePerDepositCap, config.nativeTotalCap);
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
            chainId: chainId,
            owner: config.owner,
            releaseAuthority: config.releaseAuthority,
            settlementSubmitter: config.settlementSubmitter,
            erc20Token: config.erc20Token,
            allowNative: config.allowNative,
            allowErc20: config.allowErc20,
            base8453PilotAck: config.base8453PilotAck
        });

        emit FlowMemoryBridgeSpineDeployed(
            address(lockbox),
            address(settlementSpine),
            chainId,
            config.owner,
            config.releaseAuthority,
            config.settlementSubmitter,
            config.erc20Token,
            config.allowNative,
            config.allowErc20,
            config.base8453PilotAck
        );

        VM.stopBroadcast();
    }

    function _readConfig() private returns (Config memory config) {
        config = Config({
            owner: VM.envAddress("FLOWMEMORY_BRIDGE_OWNER"),
            releaseAuthority: VM.envAddress("FLOWMEMORY_BRIDGE_RELEASE_AUTHORITY"),
            settlementSubmitter: VM.envAddress("FLOWMEMORY_SETTLEMENT_SUBMITTER"),
            erc20Token: VM.envAddress("FLOWMEMORY_BRIDGE_ERC20_TOKEN"),
            allowNative: VM.envBool("FLOWMEMORY_BRIDGE_ALLOW_NATIVE"),
            allowErc20: VM.envBool("FLOWMEMORY_BRIDGE_ALLOW_ERC20"),
            nativePerDepositCap: VM.envUint("FLOWMEMORY_BRIDGE_NATIVE_PER_DEPOSIT_CAP"),
            nativeTotalCap: VM.envUint("FLOWMEMORY_BRIDGE_NATIVE_TOTAL_CAP"),
            erc20PerDepositCap: VM.envUint("FLOWMEMORY_BRIDGE_ERC20_PER_DEPOSIT_CAP"),
            erc20TotalCap: VM.envUint("FLOWMEMORY_BRIDGE_ERC20_TOTAL_CAP"),
            base8453PilotAck: VM.envOr("FLOWMEMORY_BASE8453_PILOT_ACK", false)
        });
    }

    function _enforceDeploymentGate(Config memory config) private view returns (uint256 chainId) {
        chainId = block.chainid;
        if (chainId != LOCAL_ANVIL_CHAIN_ID && chainId != BASE_SEPOLIA_CHAIN_ID && chainId != BASE_MAINNET_CHAIN_ID) {
            revert UnsupportedBridgeSpineDeploymentChain(chainId);
        }
        if (chainId == BASE_MAINNET_CHAIN_ID && !config.base8453PilotAck) {
            revert Base8453PilotAckRequired();
        }
    }

    function _validateConfig(Config memory config, uint256 chainId) private pure {
        if (!config.allowNative && !config.allowErc20) {
            revert NoBridgeAssetAllowed();
        }
        if (config.allowErc20 && config.erc20Token == address(0)) {
            revert Erc20TokenRequired();
        }
        if (chainId == BASE_MAINNET_CHAIN_ID) {
            if (config.allowNative && config.nativeTotalCap == 0) {
                revert PilotTotalCapRequired(NATIVE_TOKEN);
            }
            if (config.allowErc20 && config.erc20TotalCap == 0) {
                revert PilotTotalCapRequired(config.erc20Token);
            }
        }
    }
}
