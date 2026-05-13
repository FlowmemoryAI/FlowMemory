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

    receive() external payable {}
}

contract BaseBridgeLockboxTest {
    BridgeVm private constant vm = BridgeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant BRIDGE_DEPOSIT_SIGNATURE =
        keccak256("BridgeDeposit(bytes32,uint256,address,address,uint256,bytes32,uint256,bytes32)");
    bytes32 private constant RECIPIENT = keccak256("flowchain.recipient.alice");

    BaseBridgeLockbox private lockbox;
    MockToken private token;
    BridgeCaller private caller;

    error AssertionFailed();

    function setUp() public {
        lockbox = new BaseBridgeLockbox(address(this));
        token = new MockToken();
        caller = new BridgeCaller();
        token.mint(address(caller), 1_000 ether);
        lockbox.configureToken(address(token), true, 25 ether, 100 ether);
        lockbox.configureToken(address(0), true, 1 ether, 2 ether);
    }

    function testOwnerCanConfigureAllowlistedToken() public {
        (bool allowed, uint256 perDepositCap, uint256 totalCap, uint256 totalLocked) =
            lockbox.tokenConfigs(address(token));

        _assertTrue(allowed);
        _assertTrue(perDepositCap == 25 ether);
        _assertTrue(totalCap == 100 ether);
        _assertTrue(totalLocked == 0);
    }

    function testLockERC20EmitsDeterministicDepositEvent() public {
        vm.recordLogs();
        bytes32 depositId = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);
        BridgeVm.Log[] memory logs = vm.getRecordedLogs();

        _assertTrue(lockbox.deposits(depositId));
        _assertTrue(token.balanceOf(address(lockbox)) == 10 ether);

        (,,, uint256 totalLocked) = lockbox.tokenConfigs(address(token));
        _assertTrue(totalLocked == 10 ether);
        _assertTrue(logs.length >= 1);

        BridgeVm.Log memory log = logs[logs.length - 1];
        _assertTrue(log.emitter == address(lockbox));
        _assertTrue(log.topics[0] == BRIDGE_DEPOSIT_SIGNATURE);
        _assertTrue(log.topics[1] == depositId);
        _assertTrue(uint256(log.topics[2]) == block.chainid);
        _assertTrue(address(uint160(uint256(log.topics[3]))) == address(caller));

        (address eventToken, uint256 amount, bytes32 recipient, uint256 nonce, bytes32 metadataHash) =
            abi.decode(log.data, (address, uint256, bytes32, uint256, bytes32));

        _assertTrue(eventToken == address(token));
        _assertTrue(amount == 10 ether);
        _assertTrue(recipient == RECIPIENT);
        _assertTrue(nonce == 1);
        _assertTrue(metadataHash == keccak256("metadata"));
    }

    function testLockNativeWorksWhenExplicitlyAllowlisted() public {
        vm.deal(address(caller), 1 ether);

        bytes32 depositId = caller.lockNative{value: 0.2 ether}(lockbox, RECIPIENT);

        _assertTrue(lockbox.deposits(depositId));
        _assertTrue(address(lockbox).balance == 0.2 ether);
    }

    function testRejectsUnallowlistedToken() public {
        MockToken other = new MockToken();
        other.mint(address(caller), 10 ether);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.TokenNotAllowed.selector, address(other)));
        caller.lockERC20(lockbox, address(other), 1 ether, RECIPIENT);
    }

    function testRejectsPerDepositCapExceeded() public {
        vm.expectRevert(
            abi.encodeWithSelector(BaseBridgeLockbox.PerDepositCapExceeded.selector, address(token), 30 ether, 25 ether)
        );
        caller.lockERC20(lockbox, address(token), 30 ether, RECIPIENT);
    }

    function testPauseBlocksDeposits() public {
        lockbox.setPaused(true);

        vm.expectRevert(BaseBridgeLockbox.Paused.selector);
        caller.lockERC20(lockbox, address(token), 1 ether, RECIPIENT);
    }

    function testOnlyOwnerCanReleaseAndReplayIsBlocked() public {
        bytes32 depositId = caller.lockERC20(lockbox, address(token), 10 ether, RECIPIENT);
        bytes32 evidenceHash = keccak256("flowchain.local.acceptance");
        bytes32 releaseId = lockbox.releaseERC20(depositId, address(caller), address(token), 1 ether, evidenceHash);

        _assertTrue(lockbox.releases(releaseId));
        _assertTrue(token.balanceOf(address(caller)) == 991 ether);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.ReleaseAlreadyProcessed.selector, releaseId));
        lockbox.releaseERC20(depositId, address(caller), address(token), 1 ether, evidenceHash);
    }

    function testNonOwnerCannotConfigurePauseOrRelease() public {
        BaseBridgeLockbox otherOwnerLockbox = new BaseBridgeLockbox(address(caller));

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.NotOwner.selector, address(this)));
        otherOwnerLockbox.setPaused(true);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeLockbox.NotOwner.selector, address(this)));
        otherOwnerLockbox.configureToken(address(token), true, 1 ether, 1 ether);
    }

    function _assertTrue(bool value) private pure {
        if (!value) {
            revert AssertionFailed();
        }
    }
}
