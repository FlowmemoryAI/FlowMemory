// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FlowMemoryAfterSwapHook} from "../contracts/FlowMemoryAfterSwapHook.sol";
import {FlowMemoryHookFlags} from "../contracts/FlowMemoryHookPlanner.sol";
import {IFlowMemoryHookAdapter} from "../contracts/interfaces/IFlowMemoryHookAdapter.sol";

interface V4HookSwapProofVm {
    function startBroadcast() external;
    function stopBroadcast() external;
    function envAddress(string calldata key) external returns (address value);
    function envBytes32(string calldata key) external returns (bytes32 value);
    function envOr(string calldata key, address defaultValue) external returns (address value);
    function envOr(string calldata key, uint256 defaultValue) external returns (uint256 value);
}

interface IBaseSepoliaPoolManagerLike {
    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    function initialize(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24 tick);
}

interface IBaseSepoliaPoolModifyLiquidityTestLike {
    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }

    function modifyLiquidity(PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData)
        external
        payable
        returns (int256 delta);
}

interface IBaseSepoliaPoolSwapTestLike {
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

    struct TestSettings {
        bool takeClaims;
        bool settleUsingBurn;
    }

    function swap(
        PoolKey calldata key,
        SwapParams calldata params,
        TestSettings calldata testSettings,
        bytes calldata hookData
    ) external payable returns (int256 delta);
}

/// @notice Minimal public-mint ERC-20 for Base Sepolia hook proof rehearsals only.
/// @dev Do not use for production value or token launch claims.
contract FlowMemoryHookProofToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function mint(address to, uint256 amount) external {
        require(to != address(0), "zero recipient");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 approved = allowance[from][msg.sender];
        require(approved >= amount, "allowance");
        if (approved != type(uint256).max) {
            allowance[from][msg.sender] = approved - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(to != address(0), "zero recipient");
        uint256 balance = balanceOf[from];
        require(balance >= amount, "balance");
        balanceOf[from] = balance - amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

/// @title RunBaseSepoliaV4HookSwapProof
/// @notice End-to-end Base Sepolia proof script for a hooked Uniswap v4 swap emitting FlowPulse.
/// @dev Deploys throwaway testnet tokens and should only be run with tiny testnet funds.
contract RunBaseSepoliaV4HookSwapProof {
    V4HookSwapProofVm private constant VM = V4HookSwapProofVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    address public constant BASE_SEPOLIA_POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address public constant BASE_SEPOLIA_POOL_SWAP_TEST = 0x8B5bcC363ddE2614281aD875bad385E0A785D3B9;
    address public constant BASE_SEPOLIA_POOL_MODIFY_LIQUIDITY_TEST = 0x37429cD17Cb1454C34E7F50b09725202Fd533039;
    address public constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    uint24 public constant FEE = 3000;
    int24 public constant TICK_SPACING = 60;
    int24 public constant TICK_LOWER = -887_220;
    int24 public constant TICK_UPPER = 887_220;
    uint160 public constant SQRT_PRICE_1_1_X96 = 79_228_162_514_264_337_593_543_950_336;
    uint160 public constant MIN_SWAP_SQRT_PRICE_LIMIT_X96 = 4_295_128_740;

    struct Proof {
        uint256 chainId;
        address operator;
        address hookAddress;
        address token0;
        address token1;
        bytes32 poolId;
        bytes32 rootfieldId;
        bytes32 commitment;
        bytes32 parentPulseId;
        bytes32 hookSalt;
        bytes32 initCodeHash;
        int256 liquidityDelta;
        int256 swapAmountSpecified;
    }

    error UnexpectedChain(uint256 expected, uint256 actual);
    error UnexpectedPoolManager(address expected, address actual);
    error ZeroOperator();
    error ZeroSalt();
    error HookAddressNotAfterSwapOnly(address hookAddress);
    error Create2DeploymentFailed(address deployer, bytes32 salt);
    error HookCodeMissing(address hookAddress);

    event FlowMemoryBaseSepoliaV4HookSwapProof(
        address indexed hookAddress,
        address indexed token0,
        address indexed token1,
        bytes32 poolId,
        bytes32 rootfieldId,
        bytes32 commitment,
        int256 liquidityDelta,
        int256 swapAmountSpecified
    );

    function run() external returns (Proof memory proof) {
        if (block.chainid != BASE_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(BASE_SEPOLIA_CHAIN_ID, block.chainid);
        }

        address poolManager = VM.envOr("BASE_SEPOLIA_POOL_MANAGER", BASE_SEPOLIA_POOL_MANAGER);
        if (poolManager != BASE_SEPOLIA_POOL_MANAGER) {
            revert UnexpectedPoolManager(BASE_SEPOLIA_POOL_MANAGER, poolManager);
        }

        proof.chainId = BASE_SEPOLIA_CHAIN_ID;
        proof.operator = VM.envAddress("FLOWMEMORY_HOOK_PROOF_OPERATOR");
        if (proof.operator == address(0)) {
            revert ZeroOperator();
        }

        proof.hookSalt = VM.envBytes32("FLOWMEMORY_HOOK_SALT");
        if (proof.hookSalt == bytes32(0)) {
            revert ZeroSalt();
        }

        proof.liquidityDelta = int256(VM.envOr("FLOWMEMORY_HOOK_PROOF_LIQUIDITY_DELTA", uint256(1 ether)));
        proof.swapAmountSpecified = -int256(VM.envOr("FLOWMEMORY_HOOK_PROOF_SWAP_AMOUNT", uint256(0.01 ether)));
        uint256 tokenMintAmount = VM.envOr("FLOWMEMORY_HOOK_PROOF_TOKEN_MINT", uint256(1_000 ether));

        proof.rootfieldId = keccak256("flowmemory.base-sepolia.v4-hook-proof.rootfield.v0");
        proof.commitment = keccak256("flowmemory.base-sepolia.v4-hook-proof.commitment.v0");
        proof.parentPulseId = bytes32(0);

        VM.startBroadcast();

        (proof.hookAddress, proof.initCodeHash) = _deployHook(poolManager, proof.hookSalt);
        (proof.token0, proof.token1) = _deployProofTokens(proof.operator, tokenMintAmount);
        _runPoolSwapProof(poolManager, proof);

        VM.stopBroadcast();

        proof.poolId = keccak256(abi.encode(proof.token0, proof.token1, FEE, TICK_SPACING, proof.hookAddress));

        emit FlowMemoryBaseSepoliaV4HookSwapProof({
            hookAddress: proof.hookAddress,
            token0: proof.token0,
            token1: proof.token1,
            poolId: proof.poolId,
            rootfieldId: proof.rootfieldId,
            commitment: proof.commitment,
            liquidityDelta: proof.liquidityDelta,
            swapAmountSpecified: proof.swapAmountSpecified
        });
    }

    function _deployHook(address poolManager, bytes32 hookSalt)
        private
        returns (address hookAddress, bytes32 initCodeHash)
    {
        bytes memory hookInitCode =
            abi.encodePacked(type(FlowMemoryAfterSwapHook).creationCode, abi.encode(poolManager));
        initCodeHash = keccak256(hookInitCode);
        hookAddress = computeCreate2Address(CREATE2_DEPLOYER, hookSalt, initCodeHash);
        if (!FlowMemoryHookFlags.hasOnlyFlowMemoryAfterSwapFlag(hookAddress)) {
            revert HookAddressNotAfterSwapOnly(hookAddress);
        }

        if (hookAddress.code.length == 0) {
            (bool ok,) = CREATE2_DEPLOYER.call(bytes.concat(hookSalt, hookInitCode));
            if (!ok) {
                revert Create2DeploymentFailed(CREATE2_DEPLOYER, hookSalt);
            }
            if (hookAddress.code.length == 0) {
                revert HookCodeMissing(hookAddress);
            }
        }
    }

    function _deployProofTokens(address operator, uint256 tokenMintAmount)
        private
        returns (address token0, address token1)
    {
        FlowMemoryHookProofToken tokenA = new FlowMemoryHookProofToken("FlowMemory Hook Proof A", "FMHPA");
        FlowMemoryHookProofToken tokenB = new FlowMemoryHookProofToken("FlowMemory Hook Proof B", "FMHPB");
        (token0, token1) = _sort(address(tokenA), address(tokenB));

        FlowMemoryHookProofToken(token0).mint(operator, tokenMintAmount);
        FlowMemoryHookProofToken(token1).mint(operator, tokenMintAmount);
        FlowMemoryHookProofToken(token0).approve(BASE_SEPOLIA_POOL_MODIFY_LIQUIDITY_TEST, type(uint256).max);
        FlowMemoryHookProofToken(token1).approve(BASE_SEPOLIA_POOL_MODIFY_LIQUIDITY_TEST, type(uint256).max);
        FlowMemoryHookProofToken(token0).approve(BASE_SEPOLIA_POOL_SWAP_TEST, type(uint256).max);
        FlowMemoryHookProofToken(token1).approve(BASE_SEPOLIA_POOL_SWAP_TEST, type(uint256).max);
    }

    function _runPoolSwapProof(address poolManager, Proof memory proof) private {
        IBaseSepoliaPoolManagerLike.PoolKey memory poolKey = IBaseSepoliaPoolManagerLike.PoolKey({
            currency0: proof.token0,
            currency1: proof.token1,
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: proof.hookAddress
        });
        IBaseSepoliaPoolManagerLike(poolManager).initialize(poolKey, SQRT_PRICE_1_1_X96);

        bytes memory hookData = abi.encode(
            IFlowMemoryHookAdapter.FlowMemorySwapHookData({
                rootfieldId: proof.rootfieldId,
                commitment: proof.commitment,
                parentPulseId: proof.parentPulseId,
                uri: "flowmemory://base-sepolia/v4-hook-proof"
            })
        );

        IBaseSepoliaPoolModifyLiquidityTestLike(BASE_SEPOLIA_POOL_MODIFY_LIQUIDITY_TEST)
            .modifyLiquidity(
                _liquidityPoolKey(poolKey),
                IBaseSepoliaPoolModifyLiquidityTestLike.ModifyLiquidityParams({
                tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: proof.liquidityDelta, salt: bytes32(0)
            }),
                hookData
            );

        IBaseSepoliaPoolSwapTestLike(BASE_SEPOLIA_POOL_SWAP_TEST)
            .swap(
                _swapPoolKey(poolKey),
                IBaseSepoliaPoolSwapTestLike.SwapParams({
                zeroForOne: true,
                amountSpecified: proof.swapAmountSpecified,
                sqrtPriceLimitX96: MIN_SWAP_SQRT_PRICE_LIMIT_X96
            }),
                IBaseSepoliaPoolSwapTestLike.TestSettings({takeClaims: false, settleUsingBurn: false}),
                hookData
            );
    }

    function computeCreate2Address(address deployer, bytes32 salt, bytes32 initCodeHash)
        public
        pure
        returns (address hookAddress)
    {
        bytes32 digest = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash));
        hookAddress = address(uint160(uint256(digest)));
    }

    function _sort(address tokenA, address tokenB) private pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _liquidityPoolKey(IBaseSepoliaPoolManagerLike.PoolKey memory key)
        private
        pure
        returns (IBaseSepoliaPoolModifyLiquidityTestLike.PoolKey memory poolKey)
    {
        poolKey = IBaseSepoliaPoolModifyLiquidityTestLike.PoolKey({
            currency0: key.currency0,
            currency1: key.currency1,
            fee: key.fee,
            tickSpacing: key.tickSpacing,
            hooks: key.hooks
        });
    }

    function _swapPoolKey(IBaseSepoliaPoolManagerLike.PoolKey memory key)
        private
        pure
        returns (IBaseSepoliaPoolSwapTestLike.PoolKey memory poolKey)
    {
        poolKey = IBaseSepoliaPoolSwapTestLike.PoolKey({
            currency0: key.currency0,
            currency1: key.currency1,
            fee: key.fee,
            tickSpacing: key.tickSpacing,
            hooks: key.hooks
        });
    }
}
