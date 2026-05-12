// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RootfieldRegistry} from "../contracts/RootfieldRegistry.sol";

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract RootfieldRegistryCaller {
    function submitRoot(RootfieldRegistry registry, bytes32 rootfieldId, bytes32 root) external {
        registry.submitRoot(rootfieldId, root, bytes32("artifact"), bytes32(0), "");
    }
}

contract RootfieldRegistryTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FLOWPULSE_SIGNATURE = keccak256(
        "FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)"
    );

    RootfieldRegistry private registry;

    error AssertionFailed();
    error ExpectedRevert();

    function setUp() public {
        registry = new RootfieldRegistry();
    }

    function testRegisterRootfieldStoresCommitmentMetadata() public {
        bytes32 rootfieldId = bytes32("rootfield.alpha");
        bytes32 schemaHash = bytes32("schema.v0");
        bytes32 metadataHash = keccak256("metadata");

        registry.registerRootfield(rootfieldId, schemaHash, metadataHash, "ipfs://metadata");

        RootfieldRegistry.Rootfield memory rootfield = registry.getRootfield(rootfieldId);
        _assertTrue(rootfield.owner == address(this));
        _assertTrue(rootfield.schemaHash == schemaHash);
        _assertTrue(rootfield.metadataHash == metadataHash);
        _assertTrue(rootfield.latestRoot == bytes32(0));
        _assertTrue(rootfield.pulseCount == 1);
        _assertTrue(rootfield.rootCount == 0);
        _assertTrue(rootfield.active);
        _assertTrue(registry.isRegistered(rootfieldId));
    }

    function testRegisterRootfieldEmitsFlowPulseSchema() public {
        bytes32 rootfieldId = bytes32("rootfield.beta");
        bytes32 schemaHash = bytes32("schema.v0");
        bytes32 metadataHash = keccak256("metadata");

        vm.recordLogs();
        bytes32 pulseId = registry.registerRootfield(rootfieldId, schemaHash, metadataHash, "ipfs://metadata");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        _assertTrue(logs.length == 1);
        _assertTrue(logs[0].emitter == address(registry));
        _assertTrue(logs[0].topics.length == 4);
        _assertTrue(logs[0].topics[0] == FLOWPULSE_SIGNATURE);
        _assertTrue(logs[0].topics[1] == pulseId);
        _assertTrue(logs[0].topics[2] == rootfieldId);
        _assertTrue(logs[0].topics[3] == bytes32(uint256(uint160(address(this)))));

        (
            uint8 pulseType,
            bytes32 subject,
            bytes32 commitment,
            bytes32 parentPulseId,
            uint64 sequence,
            uint64 occurredAt,
            string memory uri
        ) = abi.decode(logs[0].data, (uint8, bytes32, bytes32, bytes32, uint64, uint64, string));

        _assertTrue(pulseType == 1);
        _assertTrue(subject == rootfieldId);
        _assertTrue(commitment == keccak256(abi.encode(schemaHash, metadataHash)));
        _assertTrue(parentPulseId == bytes32(0));
        _assertTrue(sequence == 1);
        _assertTrue(occurredAt > 0);
        _assertTrue(keccak256(bytes(uri)) == keccak256("ipfs://metadata"));
    }

    function testCannotRegisterZeroRootfieldId() public {
        try registry.registerRootfield(bytes32(0), bytes32("schema.v0"), bytes32("metadata"), "") {
            revert ExpectedRevert();
        } catch {}
    }

    function testCannotRegisterDuplicateRootfieldId() public {
        bytes32 rootfieldId = bytes32("rootfield.gamma");
        registry.registerRootfield(rootfieldId, bytes32("schema.v0"), bytes32("metadata"), "");

        try registry.registerRootfield(rootfieldId, bytes32("schema.v1"), bytes32("metadata2"), "") {
            revert ExpectedRevert();
        } catch {}
    }

    function testSubmitRootStoresLatestRootAndIncrementsCounts() public {
        bytes32 rootfieldId = bytes32("rootfield.delta");
        bytes32 root = keccak256("root");

        bytes32 registrationPulseId = registry.registerRootfield(rootfieldId, bytes32("schema.v0"), bytes32("metadata"), "");
        registry.submitRoot(rootfieldId, root, bytes32("artifact"), registrationPulseId, "ipfs://evidence");

        RootfieldRegistry.Rootfield memory rootfield = registry.getRootfield(rootfieldId);
        _assertTrue(rootfield.latestRoot == root);
        _assertTrue(rootfield.pulseCount == 2);
        _assertTrue(rootfield.rootCount == 1);
    }

    function testOnlyRootfieldOwnerCanSubmitRoot() public {
        bytes32 rootfieldId = bytes32("rootfield.epsilon");
        registry.registerRootfield(rootfieldId, bytes32("schema.v0"), bytes32("metadata"), "");

        RootfieldRegistryCaller caller = new RootfieldRegistryCaller();
        try caller.submitRoot(registry, rootfieldId, keccak256("root")) {
            revert ExpectedRevert();
        } catch {}
    }

    function _assertTrue(bool condition) private pure {
        if (!condition) {
            revert AssertionFailed();
        }
    }
}
