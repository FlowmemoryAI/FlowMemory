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

    struct DepositRecord {
        address sender;
        address token;
        uint256 amount;
        uint256 released;
        bytes32 flowchainRecipient;
        uint256 nonce;
        bytes32 metadataHash;
        bool exists;
    }

    address public constant NATIVE_TOKEN = address(0);
    bytes32 public constant BRIDGE_DEPOSIT_SCHEMA_ID = keccak256("flowmemory.bridge.deposit.v0");
    bytes32 public constant BRIDGE_RELEASE_SCHEMA_ID = keccak256("flowmemory.bridge.release.v0");

    address public owner;
    address public releaseAuthority;
    bool public paused;
    uint256 public nextNonce = 1;

    mapping(address token => TokenConfig config) public tokenConfigs;
    mapping(bytes32 depositId => bool seen) public deposits;
    mapping(bytes32 depositId => DepositRecord record) public depositRecords;
    mapping(bytes32 releaseId => bool seen) public releases;

    bool private _entered;

    error NotOwner(address caller);
    error NotReleaseAuthority(address caller);
    error Paused();
    error ReentrantCall();
    error ZeroOwner();
    error ZeroReleaseAuthority();
    error ZeroRecipient();
    error ZeroToken();
    error ZeroAmount();
    error ZeroEvidenceHash();
    error TokenNotAllowed(address token);
    error PerDepositCapExceeded(address token, uint256 amount, uint256 cap);
    error TotalCapExceeded(address token, uint256 nextTotal, uint256 cap);
    error TransferFailed();
    error DepositAlreadyRecorded(bytes32 depositId);
    error DepositNotRecorded(bytes32 depositId);
    error ReleaseTokenMismatch(bytes32 depositId, address expectedToken, address actualToken);
    error ReleaseAmountExceeded(bytes32 depositId, uint256 requested, uint256 available);
    error ReleaseAlreadyProcessed(bytes32 releaseId);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ReleaseAuthoritySet(address indexed previousAuthority, address indexed newAuthority);
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

    modifier onlyReleaseAuthority() {
        if (msg.sender != releaseAuthority) {
            revert NotReleaseAuthority(msg.sender);
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert Paused();
        }
        _;
    }

    modifier nonReentrant() {
        if (_entered) {
            revert ReentrantCall();
        }
        _entered = true;
        _;
        _entered = false;
    }

    constructor(address initialOwner, address initialReleaseAuthority) {
        if (initialOwner == address(0)) {
            revert ZeroOwner();
        }
        if (initialReleaseAuthority == address(0)) {
            revert ZeroReleaseAuthority();
        }
        owner = initialOwner;
        releaseAuthority = initialReleaseAuthority;
        emit OwnershipTransferred(address(0), initialOwner);
        emit ReleaseAuthoritySet(address(0), initialReleaseAuthority);
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

    function setReleaseAuthority(address newAuthority) external onlyOwner {
        if (newAuthority == address(0)) {
            revert ZeroReleaseAuthority();
        }
        address previousAuthority = releaseAuthority;
        releaseAuthority = newAuthority;
        emit ReleaseAuthoritySet(previousAuthority, newAuthority);
    }

    function setPaused(bool value) external onlyOwner {
        paused = value;
        emit PausedSet(value);
    }

    function configureToken(address token, bool allowed, uint256 perDepositCap, uint256 totalCap) external onlyOwner {
        TokenConfig storage config = tokenConfigs[token];
        if (allowed && perDepositCap == 0) {
            revert ZeroAmount();
        }
        if (allowed && totalCap != 0 && totalCap < config.totalLocked) {
            revert TotalCapExceeded(token, config.totalLocked, totalCap);
        }

        config.allowed = allowed;
        config.perDepositCap = perDepositCap;
        config.totalCap = totalCap;
        emit TokenConfigured(token, allowed, perDepositCap, totalCap);
    }

    function lockNative(bytes32 flowchainRecipient, bytes32 metadataHash)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (bytes32 depositId)
    {
        depositId = _lock(NATIVE_TOKEN, msg.value, msg.sender, flowchainRecipient, metadataHash);
    }

    function lockERC20(address token, uint256 amount, bytes32 flowchainRecipient, bytes32 metadataHash)
        external
        whenNotPaused
        nonReentrant
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
        onlyReleaseAuthority
        nonReentrant
        returns (bytes32 releaseId)
    {
        if (recipient == address(0)) {
            revert ZeroRecipient();
        }
        releaseId = _recordRelease(depositId, recipient, NATIVE_TOKEN, amount, evidenceHash);
        recipient.transfer(amount);
    }

    function releaseERC20(bytes32 depositId, address recipient, address token, uint256 amount, bytes32 evidenceHash)
        external
        onlyReleaseAuthority
        nonReentrant
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

    function remainingDepositAmount(bytes32 depositId) external view returns (uint256) {
        DepositRecord storage record = depositRecords[depositId];
        if (!record.exists) {
            return 0;
        }
        return record.amount - record.released;
    }

    function getDepositRecord(bytes32 depositId) external view returns (DepositRecord memory) {
        return depositRecords[depositId];
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
        depositId = keccak256(
            abi.encode(
                BRIDGE_DEPOSIT_SCHEMA_ID,
                block.chainid,
                address(this),
                sender,
                token,
                amount,
                flowchainRecipient,
                nonce,
                metadataHash
            )
        );
        if (deposits[depositId]) {
            revert DepositAlreadyRecorded(depositId);
        }

        deposits[depositId] = true;
        depositRecords[depositId] = DepositRecord({
            sender: sender,
            token: token,
            amount: amount,
            released: 0,
            flowchainRecipient: flowchainRecipient,
            nonce: nonce,
            metadataHash: metadataHash,
            exists: true
        });
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

    function _recordRelease(bytes32 depositId, address recipient, address token, uint256 amount, bytes32 evidenceHash)
        private
        returns (bytes32 releaseId)
    {
        if (recipient == address(0)) {
            revert ZeroRecipient();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (evidenceHash == bytes32(0)) {
            revert ZeroEvidenceHash();
        }

        DepositRecord storage record = depositRecords[depositId];
        if (!record.exists) {
            revert DepositNotRecorded(depositId);
        }
        if (record.token != token) {
            revert ReleaseTokenMismatch(depositId, record.token, token);
        }

        releaseId = keccak256(
            abi.encode(
                BRIDGE_RELEASE_SCHEMA_ID,
                block.chainid,
                address(this),
                depositId,
                recipient,
                token,
                amount,
                evidenceHash
            )
        );
        if (releases[releaseId]) {
            revert ReleaseAlreadyProcessed(releaseId);
        }

        uint256 available = record.amount - record.released;
        if (amount > available) {
            revert ReleaseAmountExceeded(depositId, amount, available);
        }

        releases[releaseId] = true;
        record.released += amount;

        TokenConfig storage config = tokenConfigs[token];
        config.totalLocked -= amount;

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
