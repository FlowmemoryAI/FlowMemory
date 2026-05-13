// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FlowChainSettlementSpine} from "../contracts/FlowChainSettlementSpine.sol";

interface SettlementVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract SettlementSubmitter {
    function commitObject(
        FlowChainSettlementSpine spine,
        bytes32 objectType,
        bytes32 objectId,
        bytes32 rootfieldId,
        bytes32 commitment,
        bytes32 parentObjectId,
        string calldata evidenceURI
    ) external returns (uint64) {
        return spine.commitObject(objectType, objectId, rootfieldId, commitment, parentObjectId, evidenceURI);
    }

    function setSubmitterAuthorization(FlowChainSettlementSpine spine, address submitter, bool authorized) external {
        spine.setSubmitterAuthorization(submitter, authorized);
    }
}

contract FlowChainSettlementSpineTest {
    SettlementVm private constant vm = SettlementVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant OBJECT_COMMITTED_SIGNATURE =
        keccak256("FlowChainObjectCommitted(bytes32,bytes32,bytes32,address,bytes32,bytes32,uint64,uint64,string)");

    FlowChainSettlementSpine private spine;
    SettlementSubmitter private submitter;

    error AssertionFailed();

    function setUp() public {
        spine = new FlowChainSettlementSpine(address(this));
        submitter = new SettlementSubmitter();
    }

    function testConstructorRequiresOwnerAndAuthorizesOwner() public {
        vm.expectRevert(FlowChainSettlementSpine.ZeroOwner.selector);
        new FlowChainSettlementSpine(address(0));

        _assertTrue(spine.owner() == address(this));
        _assertTrue(spine.authorizedSubmitters(address(this)));
    }

    function testOwnerCanAuthorizeSubmitterAndTransferOwnership() public {
        spine.setSubmitterAuthorization(address(submitter), true);
        _assertTrue(spine.authorizedSubmitters(address(submitter)));

        spine.transferOwnership(address(submitter));
        _assertTrue(spine.owner() == address(submitter));
    }

    function testNonOwnerCannotAuthorizeSubmitter() public {
        vm.expectRevert(abi.encodeWithSelector(FlowChainSettlementSpine.NotOwner.selector, address(submitter)));
        submitter.setSubmitterAuthorization(spine, address(submitter), true);
    }

    function testCommitBridgeDepositObjectEmitsStableEventAndStoresRecord() public {
        bytes32 objectType = spine.BRIDGE_DEPOSIT_OBJECT();
        bytes32 objectId = keccak256("bridge.deposit.1");
        bytes32 rootfieldId = keccak256("rootfield.bridge");
        bytes32 commitment = keccak256("bridge.deposit.commitment");
        bytes32 parentObjectId = keccak256("parent.bridge.deposit");

        vm.recordLogs();
        uint64 sequence =
            spine.commitObject(objectType, objectId, rootfieldId, commitment, parentObjectId, "bridge://evidence/1");
        SettlementVm.Log[] memory logs = vm.getRecordedLogs();

        _assertTrue(sequence == 1);
        _assertTrue(spine.nextSequence() == 2);
        _assertTrue(spine.isObjectCommitted(objectId));

        FlowChainSettlementSpine.ObjectCommitment memory record = spine.getObjectCommitment(objectId);
        _assertTrue(record.submitter == address(this));
        _assertTrue(record.objectType == objectType);
        _assertTrue(record.rootfieldId == rootfieldId);
        _assertTrue(record.commitment == commitment);
        _assertTrue(record.parentObjectId == parentObjectId);
        _assertTrue(record.sequence == 1);
        _assertTrue(record.committedAt > 0);
        _assertTrue(record.exists);

        _assertObjectCommittedLog(
            logs[logs.length - 1], objectId, rootfieldId, objectType, commitment, parentObjectId, sequence
        );
    }

    function testAuthorizedSubmitterCanCommitAndRevocationBlocksFutureCommits() public {
        bytes32 bridgeDepositObject = spine.BRIDGE_DEPOSIT_OBJECT();
        bytes32 objectId = keccak256("bridge.deposit.authorized");
        spine.setSubmitterAuthorization(address(submitter), true);

        uint64 sequence = submitter.commitObject(
            spine,
            bridgeDepositObject,
            objectId,
            keccak256("rootfield.bridge"),
            keccak256("commitment"),
            bytes32(0),
            ""
        );
        _assertTrue(sequence == 1);

        spine.setSubmitterAuthorization(address(submitter), false);
        vm.expectRevert(
            abi.encodeWithSelector(FlowChainSettlementSpine.SubmitterNotAuthorized.selector, address(submitter))
        );
        submitter.commitObject(
            spine,
            bridgeDepositObject,
            keccak256("bridge.deposit.revoked"),
            keccak256("rootfield.bridge"),
            keccak256("commitment.2"),
            bytes32(0),
            ""
        );
    }

    function testCommitRejectsUnauthorizedZeroFieldsAndDuplicates() public {
        bytes32 bridgeDepositObject = spine.BRIDGE_DEPOSIT_OBJECT();

        vm.expectRevert(
            abi.encodeWithSelector(FlowChainSettlementSpine.SubmitterNotAuthorized.selector, address(submitter))
        );
        submitter.commitObject(
            spine,
            bridgeDepositObject,
            keccak256("bridge.deposit.unauthorized"),
            keccak256("rootfield.bridge"),
            keccak256("commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(FlowChainSettlementSpine.ZeroObjectType.selector);
        spine.commitObject(
            bytes32(0),
            keccak256("bridge.deposit.zero-type"),
            keccak256("rootfield.bridge"),
            keccak256("commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(FlowChainSettlementSpine.ZeroObjectId.selector);
        spine.commitObject(
            bridgeDepositObject,
            bytes32(0),
            keccak256("rootfield.bridge"),
            keccak256("commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(FlowChainSettlementSpine.ZeroRootfieldId.selector);
        spine.commitObject(
            bridgeDepositObject,
            keccak256("bridge.deposit.zero-rootfield"),
            bytes32(0),
            keccak256("commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(FlowChainSettlementSpine.ZeroCommitment.selector);
        spine.commitObject(
            bridgeDepositObject,
            keccak256("bridge.deposit.zero-commitment"),
            keccak256("rootfield.bridge"),
            bytes32(0),
            bytes32(0),
            ""
        );

        bytes32 objectId = keccak256("bridge.deposit.duplicate");
        spine.commitObject(
            bridgeDepositObject,
            objectId,
            keccak256("rootfield.bridge"),
            keccak256("commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(FlowChainSettlementSpine.ObjectAlreadyCommitted.selector, objectId));
        spine.commitObject(
            bridgeDepositObject,
            objectId,
            keccak256("rootfield.bridge"),
            keccak256("commitment.2"),
            bytes32(0),
            ""
        );
    }

    function testMissingObjectLookupReverts() public {
        bytes32 objectId = keccak256("missing.object");

        _assertTrue(!spine.isObjectCommitted(objectId));
        vm.expectRevert(abi.encodeWithSelector(FlowChainSettlementSpine.ObjectNotCommitted.selector, objectId));
        spine.getObjectCommitment(objectId);
    }

    function _assertObjectCommittedLog(
        SettlementVm.Log memory log,
        bytes32 objectId,
        bytes32 rootfieldId,
        bytes32 objectType,
        bytes32 commitment,
        bytes32 parentObjectId,
        uint64 sequence
    ) private view {
        _assertTrue(log.emitter == address(spine));
        _assertTrue(log.topics[0] == OBJECT_COMMITTED_SIGNATURE);
        _assertTrue(log.topics[1] == objectId);
        _assertTrue(log.topics[2] == rootfieldId);
        _assertTrue(log.topics[3] == objectType);

        (
            address decodedSubmitter,
            bytes32 decodedCommitment,
            bytes32 decodedParentObjectId,
            uint64 decodedSequence,
            uint64 committedAt,
            string memory evidenceURI
        ) = abi.decode(log.data, (address, bytes32, bytes32, uint64, uint64, string));

        _assertTrue(decodedSubmitter == address(this));
        _assertTrue(decodedCommitment == commitment);
        _assertTrue(decodedParentObjectId == parentObjectId);
        _assertTrue(decodedSequence == sequence);
        _assertTrue(committedAt > 0);
        _assertTrue(keccak256(bytes(evidenceURI)) == keccak256("bridge://evidence/1"));
    }

    function _assertTrue(bool value) private pure {
        if (!value) {
            revert AssertionFailed();
        }
    }
}
