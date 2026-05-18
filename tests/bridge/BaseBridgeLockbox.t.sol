// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseBridgeLockbox} from "../../contracts/bridge/BaseBridgeLockbox.sol";

interface BridgeVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function deal(address who, uint256 newBalance) external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract MockToken {
    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (balanceOf[msg.sender] < amount) {
            return false;
        }
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (balanceOf[from] < amount || allowance[from][msg.sender] < amount) {
            return false;
        }
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract BridgeCaller {
    function lockERC20(BaseBridgeLockbox lockbox, address token, uint256 amount, bytes32 recipient)
        external
        returns (bytes32)
    {
        MockToken(token).approve(address(lockbox), amount);
        return lockbox.lockERC20(token, amount, recipient, keccak256("metadata"));
    }

    function lockNative(BaseBridgeLockbox lockbox, bytes32 recipient) external payable returns (bytes32) {
        return lockbox.lockNative{value: msg.value}(recipient, keccak256("metadata"));
    }

    function setPaused(BaseBridgeLockbox lockbox, bool paused) external {
        lockbox.setPaused(paused);
    }

    function configureToken(
        BaseBridgeLockbox lockbox,
        address token,
        bool allowed,
        uint256 perDepositCap,
        uint256 totalCap
    ) external {
        lockbox.configureToken(token, allowed, perDepositCap, totalCap);
    }

    function setReleaseAuthority(BaseBridgeLockbox lockbox, address authority) external {
        lockbox.setReleaseAuthority(authority);
    }

    function releaseERC20(
        BaseBridgeLockbox lockbox,
        bytes32 depositId,
        address recipient,
        address token,
        uint256 amount,
        bytes32 evidenceHash
    ) external returns (bytes32) {
        return lockbox.releaseERC20(depositId, recipient, token, amount, evidenceHash);
    }

    function releaseNative(
        BaseBridgeLockbox lockbox,
        bytes32 depositId,
        address payable recipient,
        uint256 amount,
        bytes32 evidenceHash
    ) external returns (bytes32) {
        return lockbox.releaseNative(depositId, recipient, amount, evidenceHash);
    }

    receive() external payable {}
}

contract BaseBridgeLockboxTest {
    BridgeVm private constant vm = BridgeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant BRIDGE_DEPOSIT_SIGNATURE =
        keccak256("BridgeDeposit(bytes32,uint256,address,address,uint256,bytes32,uint256,bytes32)");
    bytes32 private constant BRIDGE_RELEASE_SIGNATURE =
        keccak256("BridgeRelease(bytes32,bytes32,address,address,uint256,bytes32)");
    bytes32 private constant RECIPIENT = keccak256("flowchain.recipient.alice");
    bytes32 private constant EVIDENCE_HASH = keccak256("flowchain.local.acceptance");

    BaseBridgeLockbox private lockbox;
    MockToken private token;
    BridgeCaller private caller;

    error AssertionFailed();

    function setUp() public {
        lockbox = new BaseBridgeLockbox(address(this), address(this));
        token = new MockToken();
        caller = new BridgeCaller();
        token.mint(address(caller), 1_000 ether);
        lockbox.configureToken(address(token), true, 25 ether, 100 ether);
        lockbox.configureToken(address(0), true, 1 ether, 2 ether);
    }

    function testConstructorRequiresExplicitOwnerAndReleaseAuthority() public {
        vm.expectRevert(BaseBridgeLockbox.ZeroOwner.selector);
        new BaseBridgeLockbox(address(0), address(this));

        vm.expectRevert(BaseBridgeLockbox.ZeroReleaseAuthority.selector);
        new BaseBridgeLockbox(address(this), address(0));
    }

    function testOwnerCanConfigureAllowlistedTokenAndReleaseAuthority() public {
        (bool allowed, uint256 perDepositCap, uint256 totalCap, uint256 totalLocked) =
            lockbox.tokenConfigs(address(token));

        _assertTrue(allowed);
        _assertTrue(perDepositCap == 25 ether);
        _assertTrue(totalCap == 100 ether);
        _assertTrue(totalLocked == 0);

        lockbox.setReleaseAuthority(address(caller));
        _assertTrue(lockbox.releaseAuthority() == address(caller));
    }

    function testNonOwnerCannotConfigurePauseOrSetReleaseAuthority() public {
        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.NotOwner.selector, address(caller)));
        caller.setPaused(lockbox, true);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.NotOwner.selector, address(caller)));
        caller.configureToken(lockbox, address(token), true, 1 ether, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.NotOwner.selector, address(caller)));
        caller.setReleaseAuthority(lockbox, address(caller));
    }

    function testLockERC20EmitsStableDeterministicDepositEventAndRecord() public {
        vm.recordLogs();
        bytes32 depositId = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);
        BridgeVm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 expectedDepositId = keccak256(
            abi.encode(
                lockbox.BRIDGE_DEPOSIT_SCHEMA_ID(),
                block.chainid,
                address(lockbox),
                address(caller),
                address(token),
                10 ether,
                RECIPIENT,
                uint256(1),
                keccak256("metadata")
            )
        );
        _assertTrue(depositId == expectedDepositId);
        _assertTrue(lockbox.deposits(depositId));
        _assertTrue(token.balanceOf(address(lockbox)) == 10 ether);
        _assertTrue(lockbox.remainingDepositAmount(depositId) == 10 ether);

        BaseBridgeLockbox.DepositRecord memory record = lockbox.getDepositRecord(depositId);
        _assertTrue(record.sender == address(caller));
        _assertTrue(record.token == address(token));
        _assertTrue(record.amount == 10 ether);
        _assertTrue(record.released == 0);
        _assertTrue(record.flowchainRecipient == RECIPIENT);
        _assertTrue(record.nonce == 1);
        _assertTrue(record.metadataHash == keccak256("metadata"));
        _assertTrue(record.exists);

        (,,, uint256 totalLocked) = lockbox.tokenConfigs(address(token));
        _assertTrue(totalLocked == 10 ether);
        _assertBridgeDepositLog(logs[logs.length - 1], depositId, address(token), 10 ether, 1);
    }

    function testRepeatedDepositsUseNonceReplayProtection() public {
        bytes32 firstDeposit = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);
        bytes32 secondDeposit = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);

        _assertTrue(firstDeposit != secondDeposit);
        _assertTrue(lockbox.deposits(firstDeposit));
        _assertTrue(lockbox.deposits(secondDeposit));
        _assertTrue(lockbox.nextNonce() == 3);
    }

    function testLockNativeWorksWhenExplicitlyAllowlisted() public {
        vm.deal(address(caller), 1 ether);

        bytes32 depositId = caller.lockNative{value: 0.2 ether}(lockbox, RECIPIENT);

        _assertTrue(lockbox.deposits(depositId));
        _assertTrue(address(lockbox).balance == 0.2 ether);
        _assertTrue(lockbox.remainingDepositAmount(depositId) == 0.2 ether);
    }

    function testRejectsUnallowlistedDisabledAndZeroTokenDeposits() public {
        MockToken other = new MockToken();
        other.mint(address(caller), 10 ether);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.TokenNotAllowed.selector, address(other)));
        caller.lockERC20(lockbox, address(other), 1 ether, RECIPIENT);

        lockbox.configureToken(address(token), false, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.TokenNotAllowed.selector, address(token)));
        caller.lockERC20(lockbox, address(token), 1 ether, RECIPIENT);

        vm.expectRevert(BaseBridgeLockbox.ZeroToken.selector);
        lockbox.lockERC20(address(0), 1 ether, RECIPIENT, keccak256("metadata"));
    }

    function testRejectsZeroAmountRecipientAndDirectNativeTransfers() public {
        vm.expectRevert(BaseBridgeLockbox.ZeroAmount.selector);
        caller.lockERC20(lockbox, address(token), 0, RECIPIENT);

        vm.expectRevert(BaseBridgeLockbox.ZeroRecipient.selector);
        caller.lockERC20(lockbox, address(token), 1 ether, bytes32(0));

        (bool ok,) = address(lockbox).call{value: 1 wei}("");
        _assertTrue(!ok);
    }

    function testRejectsPerDepositAndTotalCapExceeded() public {
        vm.expectRevert(
            abi.encodeWithSelector(BaseBridgeLockbox.PerDepositCapExceeded.selector, address(token), 30 ether, 25 ether)
        );
        caller.lockERC20(lockbox, address(token), 30 ether, RECIPIENT);

        caller.lockERC20(lockbox, address(token), 25 ether, RECIPIENT);
        caller.lockERC20(lockbox, address(token), 25 ether, RECIPIENT);
        caller.lockERC20(lockbox, address(token), 25 ether, RECIPIENT);
        caller.lockERC20(lockbox, address(token), 25 ether, RECIPIENT);

        vm.expectRevert(
            abi.encodeWithSelector(BaseBridgeLockbox.TotalCapExceeded.selector, address(token), 101 ether, 100 ether)
        );
        caller.lockERC20(lockbox, address(token), 1 ether, RECIPIENT);
    }

    function testCannotLowerTotalCapBelowCurrentlyLockedAmount() public {
        caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);

        vm.expectRevert(
            abi.encodeWithSelector(BaseBridgeLockbox.TotalCapExceeded.selector, address(token), 10 ether, 9 ether)
        );
        lockbox.configureToken(address(token), true, 25 ether, 9 ether);
    }

    function testPauseBlocksDepositsButNotAuthorizedRelease() public {
        bytes32 depositId = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);
        lockbox.setPaused(true);

        vm.expectRevert(BaseBridgeLockbox.Paused.selector);
        caller.lockERC20(lockbox, address(token), 1 ether, RECIPIENT);

        lockbox.releaseERC20(depositId, address(caller), address(token), 1 ether, EVIDENCE_HASH);
        _assertTrue(lockbox.remainingDepositAmount(depositId) == 9 ether);
    }

    function testReleaseERC20RequiresExplicitAuthorityAndKnownDeposit() public {
        bytes32 depositId = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);
        lockbox.setReleaseAuthority(address(caller));

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.NotReleaseAuthority.selector, address(this)));
        lockbox.releaseERC20(depositId, address(caller), address(token), 1 ether, EVIDENCE_HASH);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.DepositNotRecorded.selector, keccak256("missing")));
        caller.releaseERC20(lockbox, keccak256("missing"), address(caller), address(token), 1 ether, EVIDENCE_HASH);

        bytes32 releaseId =
            caller.releaseERC20(lockbox, depositId, address(caller), address(token), 1 ether, EVIDENCE_HASH);
        _assertTrue(lockbox.releases(releaseId));
        _assertTrue(lockbox.remainingDepositAmount(depositId) == 9 ether);
        _assertTrue(token.balanceOf(address(caller)) == 991 ether);
    }

    function testReleaseERC20EmitsStableSchemaAndBlocksReplay() public {
        bytes32 depositId = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);

        vm.recordLogs();
        bytes32 releaseId = lockbox.releaseERC20(depositId, address(caller), address(token), 1 ether, EVIDENCE_HASH);
        BridgeVm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 expectedReleaseId = keccak256(
            abi.encode(
                lockbox.BRIDGE_RELEASE_SCHEMA_ID(),
                block.chainid,
                address(lockbox),
                depositId,
                address(caller),
                address(token),
                1 ether,
                EVIDENCE_HASH
            )
        );
        _assertTrue(releaseId == expectedReleaseId);
        _assertBridgeReleaseLog(logs[logs.length - 1], releaseId, depositId, address(caller), address(token), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.ReleaseAlreadyProcessed.selector, releaseId));
        lockbox.releaseERC20(depositId, address(caller), address(token), 1 ether, EVIDENCE_HASH);
    }

    function testReleaseERC20CanReleaseInPartsWithDistinctEvidenceUntilExhausted() public {
        bytes32 depositId = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);
        bytes32 firstEvidenceHash = keccak256("flowchain.local.release.1");
        bytes32 secondEvidenceHash = keccak256("flowchain.local.release.2");

        bytes32 firstRelease =
            lockbox.releaseERC20(depositId, address(caller), address(token), 4 ether, firstEvidenceHash);
        bytes32 secondRelease =
            lockbox.releaseERC20(depositId, address(caller), address(token), 6 ether, secondEvidenceHash);

        _assertTrue(firstRelease != secondRelease);
        _assertTrue(lockbox.releases(firstRelease));
        _assertTrue(lockbox.releases(secondRelease));
        _assertTrue(lockbox.remainingDepositAmount(depositId) == 0);
        _assertTrue(token.balanceOf(address(caller)) == 1_000 ether);

        (,,, uint256 totalLocked) = lockbox.tokenConfigs(address(token));
        _assertTrue(totalLocked == 0);

        vm.expectRevert(
            abi.encodeWithSelector(BaseBridgeLockbox.ReleaseAmountExceeded.selector, depositId, 1 wei, 0)
        );
        lockbox.releaseERC20(depositId, address(caller), address(token), 1 wei, keccak256("flowchain.local.release.3"));
    }

    function testReleaseRejectsZeroRecipientAndZeroAmount() public {
        bytes32 depositId = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);

        vm.expectRevert(BaseBridgeLockbox.ZeroRecipient.selector);
        lockbox.releaseERC20(depositId, address(0), address(token), 1 ether, EVIDENCE_HASH);

        vm.expectRevert(BaseBridgeLockbox.ZeroAmount.selector);
        lockbox.releaseERC20(depositId, address(caller), address(token), 0, EVIDENCE_HASH);
    }

    function testReleaseBlocksTokenMismatchOverReleaseAndZeroEvidence() public {
        bytes32 depositId = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);

        vm.expectRevert(
            abi.encodeWithSelector(
                BaseBridgeLockbox.ReleaseTokenMismatch.selector, depositId, address(token), address(0)
            )
        );
        lockbox.releaseNative(depositId, payable(address(caller)), 1 ether, EVIDENCE_HASH);

        vm.expectRevert(
            abi.encodeWithSelector(BaseBridgeLockbox.ReleaseAmountExceeded.selector, depositId, 11 ether, 10 ether)
        );
        lockbox.releaseERC20(depositId, address(caller), address(token), 11 ether, EVIDENCE_HASH);

        vm.expectRevert(BaseBridgeLockbox.ZeroEvidenceHash.selector);
        lockbox.releaseERC20(depositId, address(caller), address(token), 1 ether, bytes32(0));
    }

    function testReleaseNativeWorksThroughExplicitAuthorityWhilePaused() public {
        vm.deal(address(caller), 0);
        bytes32 depositId = caller.lockNative{value: 0.5 ether}(lockbox, RECIPIENT);
        lockbox.setReleaseAuthority(address(caller));
        lockbox.setPaused(true);

        bytes32 releaseId = caller.releaseNative(lockbox, depositId, payable(address(caller)), 0.2 ether, EVIDENCE_HASH);

        _assertTrue(lockbox.releases(releaseId));
        _assertTrue(lockbox.remainingDepositAmount(depositId) == 0.3 ether);
        _assertTrue(address(lockbox).balance == 0.3 ether);
        _assertTrue(address(caller).balance == 0.2 ether);
    }

    function _assertBridgeDepositLog(
        BridgeVm.Log memory log,
        bytes32 depositId,
        address expectedToken,
        uint256 expectedAmount,
        uint256 expectedNonce
    ) private view {
        _assertTrue(log.emitter == address(lockbox));
        _assertTrue(log.topics[0] == BRIDGE_DEPOSIT_SIGNATURE);
        _assertTrue(log.topics[1] == depositId);
        _assertTrue(uint256(log.topics[2]) == block.chainid);
        _assertTrue(address(uint160(uint256(log.topics[3]))) == address(caller));

        (address eventToken, uint256 amount, bytes32 recipient, uint256 nonce, bytes32 metadataHash) =
            abi.decode(log.data, (address, uint256, bytes32, uint256, bytes32));

        _assertTrue(eventToken == expectedToken);
        _assertTrue(amount == expectedAmount);
        _assertTrue(recipient == RECIPIENT);
        _assertTrue(nonce == expectedNonce);
        _assertTrue(metadataHash == keccak256("metadata"));
    }

    function _assertBridgeReleaseLog(
        BridgeVm.Log memory log,
        bytes32 releaseId,
        bytes32 depositId,
        address recipient,
        address expectedToken,
        uint256 expectedAmount
    ) private view {
        _assertTrue(log.emitter == address(lockbox));
        _assertTrue(log.topics[0] == BRIDGE_RELEASE_SIGNATURE);
        _assertTrue(log.topics[1] == releaseId);
        _assertTrue(log.topics[2] == depositId);
        _assertTrue(address(uint160(uint256(log.topics[3]))) == recipient);

        (address eventToken, uint256 amount, bytes32 evidenceHash) = abi.decode(log.data, (address, uint256, bytes32));

        _assertTrue(eventToken == expectedToken);
        _assertTrue(amount == expectedAmount);
        _assertTrue(evidenceHash == EVIDENCE_HASH);
    }

    function _assertTrue(bool value) private pure {
        if (!value) {
            revert AssertionFailed();
        }
    }
}
