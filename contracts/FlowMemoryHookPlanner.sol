// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Dependency-light Uniswap v4 hook flag helpers for FlowMemory.
/// @dev Constants mirror Uniswap v4 core Hooks flag positions without
/// vendoring v4-core into the current repository.
library FlowMemoryHookFlags {
    uint160 internal constant ALL_HOOK_MASK = uint160((1 << 14) - 1);

    uint160 internal constant BEFORE_INITIALIZE_FLAG = 1 << 13;
    uint160 internal constant AFTER_INITIALIZE_FLAG = 1 << 12;
    uint160 internal constant BEFORE_ADD_LIQUIDITY_FLAG = 1 << 11;
    uint160 internal constant AFTER_ADD_LIQUIDITY_FLAG = 1 << 10;
    uint160 internal constant BEFORE_REMOVE_LIQUIDITY_FLAG = 1 << 9;
    uint160 internal constant AFTER_REMOVE_LIQUIDITY_FLAG = 1 << 8;
    uint160 internal constant BEFORE_SWAP_FLAG = 1 << 7;
    uint160 internal constant AFTER_SWAP_FLAG = 1 << 6;
    uint160 internal constant BEFORE_DONATE_FLAG = 1 << 5;
    uint160 internal constant AFTER_DONATE_FLAG = 1 << 4;
    uint160 internal constant BEFORE_SWAP_RETURNS_DELTA_FLAG = 1 << 3;
    uint160 internal constant AFTER_SWAP_RETURNS_DELTA_FLAG = 1 << 2;
    uint160 internal constant AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 1;
    uint160 internal constant AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 0;

    uint160 internal constant FLOWMEMORY_AFTER_SWAP_FLAGS = AFTER_SWAP_FLAG;

    function hookBits(address hook) internal pure returns (uint160) {
        return uint160(hook) & ALL_HOOK_MASK;
    }

    function hasOnlyFlowMemoryAfterSwapFlag(address hook) internal pure returns (bool) {
        return hookBits(hook) == FLOWMEMORY_AFTER_SWAP_FLAGS;
    }
}

/// @title FlowMemoryHookPlanner
/// @notice Pure planner/miner helper for the Base Sepolia Uniswap v4 hook path.
/// @dev This helper performs no deployment and has no secrets. Use it to derive
/// a CREATE2 salt/address plan, then deploy only from a reviewed script or
/// operator runbook that records the exact inputs.
contract FlowMemoryHookPlanner {
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    address public constant BASE_SEPOLIA_POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address public constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    uint160 public constant ALL_HOOK_MASK = FlowMemoryHookFlags.ALL_HOOK_MASK;
    uint160 public constant BEFORE_INITIALIZE_FLAG = FlowMemoryHookFlags.BEFORE_INITIALIZE_FLAG;
    uint160 public constant AFTER_INITIALIZE_FLAG = FlowMemoryHookFlags.AFTER_INITIALIZE_FLAG;
    uint160 public constant BEFORE_ADD_LIQUIDITY_FLAG = FlowMemoryHookFlags.BEFORE_ADD_LIQUIDITY_FLAG;
    uint160 public constant AFTER_ADD_LIQUIDITY_FLAG = FlowMemoryHookFlags.AFTER_ADD_LIQUIDITY_FLAG;
    uint160 public constant BEFORE_REMOVE_LIQUIDITY_FLAG = FlowMemoryHookFlags.BEFORE_REMOVE_LIQUIDITY_FLAG;
    uint160 public constant AFTER_REMOVE_LIQUIDITY_FLAG = FlowMemoryHookFlags.AFTER_REMOVE_LIQUIDITY_FLAG;
    uint160 public constant BEFORE_SWAP_FLAG = FlowMemoryHookFlags.BEFORE_SWAP_FLAG;
    uint160 public constant AFTER_SWAP_FLAG = FlowMemoryHookFlags.AFTER_SWAP_FLAG;
    uint160 public constant BEFORE_DONATE_FLAG = FlowMemoryHookFlags.BEFORE_DONATE_FLAG;
    uint160 public constant AFTER_DONATE_FLAG = FlowMemoryHookFlags.AFTER_DONATE_FLAG;
    uint160 public constant BEFORE_SWAP_RETURNS_DELTA_FLAG = FlowMemoryHookFlags.BEFORE_SWAP_RETURNS_DELTA_FLAG;
    uint160 public constant AFTER_SWAP_RETURNS_DELTA_FLAG = FlowMemoryHookFlags.AFTER_SWAP_RETURNS_DELTA_FLAG;
    uint160 public constant AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG =
        FlowMemoryHookFlags.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG;
    uint160 public constant AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG =
        FlowMemoryHookFlags.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG;
    uint160 public constant FLOWMEMORY_AFTER_SWAP_FLAGS = FlowMemoryHookFlags.FLOWMEMORY_AFTER_SWAP_FLAGS;

    struct HookPermissions {
        bool beforeInitialize;
        bool afterInitialize;
        bool beforeAddLiquidity;
        bool afterAddLiquidity;
        bool beforeRemoveLiquidity;
        bool afterRemoveLiquidity;
        bool beforeSwap;
        bool afterSwap;
        bool beforeDonate;
        bool afterDonate;
        bool beforeSwapReturnDelta;
        bool afterSwapReturnDelta;
        bool afterAddLiquidityReturnDelta;
        bool afterRemoveLiquidityReturnDelta;
    }

    struct HookPlan {
        uint256 chainId;
        address poolManager;
        address create2Deployer;
        uint160 targetFlags;
        bytes32 initCodeHash;
        bytes32 salt;
        address hookAddress;
    }

    error ZeroCreate2Deployer();
    error ZeroInitCodeHash();
    error SaltNotFound(uint256 startSalt, uint256 maxIterations);

    function targetPermissions() external pure returns (HookPermissions memory permissions) {
        permissions.afterSwap = true;
    }

    function hookBits(address hook) public pure returns (uint160) {
        return FlowMemoryHookFlags.hookBits(hook);
    }

    function hasOnlyAfterSwapFlag(address hook) public pure returns (bool) {
        return FlowMemoryHookFlags.hasOnlyFlowMemoryAfterSwapFlag(hook);
    }

    function computeCreate2Address(address deployer, bytes32 salt, bytes32 initCodeHash)
        public
        pure
        returns (address hookAddress)
    {
        if (deployer == address(0)) revert ZeroCreate2Deployer();
        if (initCodeHash == bytes32(0)) revert ZeroInitCodeHash();

        bytes32 digest = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash));
        hookAddress = address(uint160(uint256(digest)));
    }

    function findSalt(address deployer, bytes32 initCodeHash, uint256 startSalt, uint256 maxIterations)
        public
        pure
        returns (bytes32 salt, address hookAddress)
    {
        for (uint256 i = 0; i < maxIterations; i++) {
            salt = bytes32(startSalt + i);
            hookAddress = computeCreate2Address(deployer, salt, initCodeHash);
            if (hasOnlyAfterSwapFlag(hookAddress)) {
                return (salt, hookAddress);
            }
        }

        revert SaltNotFound(startSalt, maxIterations);
    }

    function planBaseSepolia(bytes32 initCodeHash, uint256 startSalt, uint256 maxIterations)
        external
        pure
        returns (HookPlan memory plan)
    {
        (bytes32 salt, address hookAddress) = findSalt(CREATE2_DEPLOYER, initCodeHash, startSalt, maxIterations);

        plan = HookPlan({
            chainId: BASE_SEPOLIA_CHAIN_ID,
            poolManager: BASE_SEPOLIA_POOL_MANAGER,
            create2Deployer: CREATE2_DEPLOYER,
            targetFlags: FLOWMEMORY_AFTER_SWAP_FLAGS,
            initCodeHash: initCodeHash,
            salt: salt,
            hookAddress: hookAddress
        });
    }
}
