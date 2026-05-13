// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title BaseBridgeLockbox
/// @notice Test-only Base-side lockbox for the FlowChain bridge POC.
/// @dev This contract is intentionally small and non-upgradeable. It is not a
/// production bridge, not audited, and does not prove FlowChain finality.
contract BaseBridgeLockbox {
    struct TokenConfig {
        bool allowed;
        uint256 perDepositCap;
        uint256 totalCap;
        uint256 totalLocked;
    }

    address public constant NATIVE_TOKEN = address(0);

    address public owner;
    bool public paused;
    uint256 public nextNonce = 1;

    mapping(address token => TokenConfig config) public tokenConfigs;
    mapping(bytes32 depositId => bool seen) public deposits;
    mapping(bytes32 releaseId => bool seen) public releases;

    error NotOwner(address caller);
    error Paused();
    error ZeroOwner();
    error ZeroRecipient();
    error ZeroToken();
    error ZeroAmount();
    error TokenNotAllowed(address token);
    error PerDepositCapExceeded(address token, uint256 amount, uint256 cap);
    error TotalCapExceeded(address token, uint256 nextTotal, uint256 cap);
    error TransferFailed();
    error ReleaseAlreadyProcessed(bytes32 releaseId);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PausedSet(bool paused);
    event TokenConfigured(address indexed token, bool allowed, uint256 perDepositCap, uint256 totalCap);
    event BridgeDeposit(
        bytes32 indexed depositId,
        uint256 indexed sourceChainId,
        address indexed sender,
        address token,
        uint256 amount,
        bytes32 flowchainRecipient,
        uint256 nonce,
        bytes32 metadataHash
    );
    event BridgeRelease(
        bytes32 indexed releaseId,
        bytes32 indexed depositId,
        address indexed recipient,
        address token,
        uint256 amount,
        bytes32 evidenceHash
    );

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert Paused();
        }
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert ZeroOwner();
        }
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    receive() external payable {
        revert ZeroRecipient();
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert ZeroOwner();
        }
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function setPaused(bool value) external onlyOwner {
        paused = value;
        emit PausedSet(value);
    }

    function configureToken(address token, bool allowed, uint256 perDepositCap, uint256 totalCap) external onlyOwner {
        if (token != NATIVE_TOKEN && token == address(0)) {
            revert ZeroToken();
        }
        if (allowed && perDepositCap == 0) {
            revert ZeroAmount();
        }
        if (allowed && totalCap != 0 && totalCap < tokenConfigs[token].totalLocked) {
            revert TotalCapExceeded(token, tokenConfigs[token].totalLocked, totalCap);
        }

        tokenConfigs[token].allowed = allowed;
        tokenConfigs[token].perDepositCap = perDepositCap;
        tokenConfigs[token].totalCap = totalCap;
        emit TokenConfigured(token, allowed, perDepositCap, totalCap);
    }

    function lockNative(bytes32 flowchainRecipient, bytes32 metadataHash)
        external
        payable
        whenNotPaused
        returns (bytes32 depositId)
    {
        depositId = _lock(NATIVE_TOKEN, msg.value, msg.sender, flowchainRecipient, metadataHash);
    }

    function lockERC20(address token, uint256 amount, bytes32 flowchainRecipient, bytes32 metadataHash)
        external
        whenNotPaused
        returns (bytes32 depositId)
    {
        if (token == NATIVE_TOKEN) {
            revert ZeroToken();
        }
        depositId = _lock(token, amount, msg.sender, flowchainRecipient, metadataHash);
        if (!IERC20Minimal(token).transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }
    }

    function releaseNative(bytes32 depositId, address payable recipient, uint256 amount, bytes32 evidenceHash)
        external
        onlyOwner
        returns (bytes32 releaseId)
    {
        releaseId = _recordRelease(depositId, recipient, NATIVE_TOKEN, amount, evidenceHash);
        (bool ok,) = recipient.call{value: amount}("");
        if (!ok) {
            revert TransferFailed();
        }
    }

    function releaseERC20(bytes32 depositId, address recipient, address token, uint256 amount, bytes32 evidenceHash)
        external
        onlyOwner
        returns (bytes32 releaseId)
    {
        if (token == NATIVE_TOKEN) {
            revert ZeroToken();
        }
        releaseId = _recordRelease(depositId, recipient, token, amount, evidenceHash);
        if (!IERC20Minimal(token).transfer(recipient, amount)) {
            revert TransferFailed();
        }
    }

    function _lock(address token, uint256 amount, address sender, bytes32 flowchainRecipient, bytes32 metadataHash)
        private
        returns (bytes32 depositId)
    {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (flowchainRecipient == bytes32(0)) {
            revert ZeroRecipient();
        }

        TokenConfig storage config = tokenConfigs[token];
        if (!config.allowed) {
            revert TokenNotAllowed(token);
        }
        if (amount > config.perDepositCap) {
            revert PerDepositCapExceeded(token, amount, config.perDepositCap);
        }

        uint256 nextTotal = config.totalLocked + amount;
        if (config.totalCap != 0 && nextTotal > config.totalCap) {
            revert TotalCapExceeded(token, nextTotal, config.totalCap);
        }

        uint256 nonce = nextNonce++;
        depositId = keccak256(abi.encode(block.chainid, address(this), sender, token, amount, flowchainRecipient, nonce));
        deposits[depositId] = true;
        config.totalLocked = nextTotal;

        emit BridgeDeposit({
            depositId: depositId,
            sourceChainId: block.chainid,
            sender: sender,
            token: token,
            amount: amount,
            flowchainRecipient: flowchainRecipient,
            nonce: nonce,
            metadataHash: metadataHash
        });
    }

    function _recordRelease(
        bytes32 depositId,
        address recipient,
        address token,
        uint256 amount,
        bytes32 evidenceHash
    ) private returns (bytes32 releaseId) {
        if (recipient == address(0)) {
            revert ZeroRecipient();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        releaseId = keccak256(abi.encode(block.chainid, address(this), depositId, recipient, token, amount, evidenceHash));
        if (releases[releaseId]) {
            revert ReleaseAlreadyProcessed(releaseId);
        }
        releases[releaseId] = true;

        TokenConfig storage config = tokenConfigs[token];
        if (config.totalLocked >= amount) {
            config.totalLocked -= amount;
        } else {
            config.totalLocked = 0;
        }

        emit BridgeRelease({
            releaseId: releaseId,
            depositId: depositId,
            recipient: recipient,
            token: token,
            amount: amount,
            evidenceHash: evidenceHash
        });
    }
}
