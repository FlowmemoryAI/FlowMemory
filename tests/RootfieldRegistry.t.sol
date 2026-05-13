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
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
}

contract RootfieldRegistryCaller {
    function submitRoot(RootfieldRegistry registry, bytes32 rootfieldId, bytes32 root) external {
        registry.submitRoot(rootfieldId, root, keccak256("artifact"), bytes32(0), "");
    }

    function deactivateRootfield(RootfieldRegistry registry, bytes32 rootfieldId) external {
        registry.deactivateRootfield(rootfieldId, bytes32(0), "rootfield://deactivate");
    }
}

contract RootfieldRegistryTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FLOWPULSE_SIGNATURE =
        keccak256("FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)");
    bytes32 private constant OWNERSHIP_TRANSFERRED_SIGNATURE =
        keccak256("RootfieldOwnershipTransferred(bytes32,address,address,string)");

    RootfieldRegistry private registry;

    error AssertionFailed();

    function setUp() public {
        registry = new RootfieldRegistry();
    }

    function testRegisterRootfieldStoresCommitmentMetadata() public {
        bytes32 rootfieldId = keccak256("rootfield.alpha");
        bytes32 schemaHash = keccak256("schema.v0");
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
        bytes32 rootfieldId = keccak256("rootfield.beta");
        bytes32 schemaHash = keccak256("schema.v0");
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

    function testRegistrationUriIsArbitraryAdvisoryLogData() public {
        bytes32 rootfieldId = keccak256("rootfield.uri");
        string memory arbitraryURI = "not-a-short-pointer:raw caller supplied advisory string";

        vm.recordLogs();
        registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), arbitraryURI);
        Vm.Log[] memory logs = vm.getRecordedLogs();

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
        _assertTrue(commitment == keccak256(abi.encode(keccak256("schema.v0"), keccak256("metadata"))));
        _assertTrue(parentPulseId == bytes32(0));
        _assertTrue(sequence == 1);
        _assertTrue(occurredAt > 0);
        _assertTrue(keccak256(bytes(uri)) == keccak256(bytes(arbitraryURI)));
    }

    function testSubmitRootEmitsFlowPulseSchemaWithoutReceiptMetadata() public {
        bytes32 rootfieldId = keccak256("rootfield.submit");
        bytes32 schemaHash = keccak256("schema.v0");
        bytes32 metadataHash = keccak256("metadata");
        bytes32 root = keccak256("root");
        bytes32 artifactCommitment = keccak256("artifact");
        bytes32 registrationPulseId =
            registry.registerRootfield(rootfieldId, schemaHash, metadataHash, "ipfs://metadata");

        vm.recordLogs();
        bytes32 pulseId =
            registry.submitRoot(rootfieldId, root, artifactCommitment, registrationPulseId, "ipfs://evidence");
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

        _assertTrue(pulseType == 2);
        _assertTrue(subject == root);
        _assertTrue(commitment == keccak256(abi.encode(root, artifactCommitment)));
        _assertTrue(parentPulseId == registrationPulseId);
        _assertTrue(sequence == 2);
        _assertTrue(occurredAt > 0);
        _assertTrue(keccak256(bytes(uri)) == keccak256("ipfs://evidence"));
    }

    function testFlowPulseSignatureExcludesReceiptMetadata() public pure {
        bytes32 signatureWithReceiptMetadata = keccak256(
            "FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string,bytes32,uint256)"
        );

        _assertTrue(FLOWPULSE_SIGNATURE != signatureWithReceiptMetadata);
    }

    function testCannotRegisterZeroRootfieldId() public {
        vm.expectRevert(RootfieldRegistry.ZeroRootfieldId.selector);
        registry.registerRootfield(bytes32(0), keccak256("schema.v0"), keccak256("metadata"), "");
    }

    function testCannotRegisterDuplicateRootfieldId() public {
        bytes32 rootfieldId = keccak256("rootfield.gamma");
        registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");

        vm.expectRevert(abi.encodeWithSelector(RootfieldRegistry.RootfieldAlreadyRegistered.selector, rootfieldId));
        registry.registerRootfield(rootfieldId, keccak256("schema.v1"), keccak256("metadata2"), "");
    }

    function testSubmitRootStoresLatestRootAndIncrementsCounts() public {
        bytes32 rootfieldId = keccak256("rootfield.delta");
        bytes32 root = keccak256("root");

        bytes32 registrationPulseId =
            registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");
        registry.submitRoot(rootfieldId, root, keccak256("artifact"), registrationPulseId, "ipfs://evidence");

        RootfieldRegistry.Rootfield memory rootfield = registry.getRootfield(rootfieldId);
        _assertTrue(rootfield.latestRoot == root);
        _assertTrue(rootfield.pulseCount == 2);
        _assertTrue(rootfield.rootCount == 1);
    }

    function testCannotSubmitZeroRoot() public {
        bytes32 rootfieldId = keccak256("rootfield.zero-root");
        registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");

        vm.expectRevert(RootfieldRegistry.ZeroRoot.selector);
        registry.submitRoot(rootfieldId, bytes32(0), keccak256("artifact"), bytes32(0), "");
    }

    function testCannotSubmitUnregisteredRootfield() public {
        bytes32 rootfieldId = keccak256("rootfield.missing");

        vm.expectRevert(abi.encodeWithSelector(RootfieldRegistry.RootfieldNotRegistered.selector, rootfieldId));
        registry.submitRoot(rootfieldId, keccak256("root"), keccak256("artifact"), bytes32(0), "");
    }

    function testOnlyRootfieldOwnerCanSubmitRoot() public {
        bytes32 rootfieldId = keccak256("rootfield.epsilon");
        registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");

        RootfieldRegistryCaller caller = new RootfieldRegistryCaller();
        vm.expectRevert(
            abi.encodeWithSelector(RootfieldRegistry.NotRootfieldOwner.selector, rootfieldId, address(caller))
        );
        caller.submitRoot(registry, rootfieldId, keccak256("root"));
    }

    function testDeactivateRootfieldEmitsStatusPulseAndBlocksRoots() public {
        bytes32 rootfieldId = keccak256("rootfield.deactivate");
        bytes32 registrationPulseId =
            registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");

        vm.recordLogs();
        bytes32 pulseId = registry.deactivateRootfield(rootfieldId, registrationPulseId, "rootfield://deactivate");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        _assertTrue(logs.length == 2);
        _assertTrue(logs[0].emitter == address(registry));
        _assertTrue(logs[0].topics[0] == FLOWPULSE_SIGNATURE);
        _assertTrue(logs[0].topics[1] == pulseId);

        (
            uint8 pulseType,
            bytes32 subject,
            bytes32 commitment,
            bytes32 parentPulseId,
            uint64 sequence,
            uint64 occurredAt,
            string memory uri
        ) = abi.decode(logs[0].data, (uint8, bytes32, bytes32, bytes32, uint64, uint64, string));

        _assertTrue(pulseType == 3);
        _assertTrue(subject == rootfieldId);
        _assertTrue(commitment == keccak256(abi.encode(rootfieldId, false)));
        _assertTrue(parentPulseId == registrationPulseId);
        _assertTrue(sequence == 2);
        _assertTrue(occurredAt > 0);
        _assertTrue(keccak256(bytes(uri)) == keccak256("rootfield://deactivate"));

        RootfieldRegistry.Rootfield memory rootfield = registry.getRootfield(rootfieldId);
        _assertTrue(!rootfield.active);
        _assertTrue(rootfield.pulseCount == 2);

        vm.expectRevert(abi.encodeWithSelector(RootfieldRegistry.RootfieldInactive.selector, rootfieldId));
        registry.submitRoot(rootfieldId, keccak256("root"), keccak256("artifact"), pulseId, "");
    }

    function testOnlyRootfieldOwnerCanDeactivateRootfield() public {
        bytes32 rootfieldId = keccak256("rootfield.deactivate.owner");
        registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");

        RootfieldRegistryCaller caller = new RootfieldRegistryCaller();
        vm.expectRevert(
            abi.encodeWithSelector(RootfieldRegistry.NotRootfieldOwner.selector, rootfieldId, address(caller))
        );
        caller.deactivateRootfield(registry, rootfieldId);
    }

    function testTransferRootfieldOwnershipAllowsNewOwnerOnly() public {
        bytes32 rootfieldId = keccak256("rootfield.transfer");
        RootfieldRegistryCaller newOwner = new RootfieldRegistryCaller();
        registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");

        registry.transferRootfieldOwnership(rootfieldId, address(newOwner), "rootfield://transfer");

        RootfieldRegistry.Rootfield memory rootfield = registry.getRootfield(rootfieldId);
        _assertTrue(rootfield.owner == address(newOwner));
        _assertTrue(rootfield.pulseCount == 2);

        vm.expectRevert(
            abi.encodeWithSelector(RootfieldRegistry.NotRootfieldOwner.selector, rootfieldId, address(this))
        );
        registry.submitRoot(rootfieldId, keccak256("root.old-owner"), keccak256("artifact"), bytes32(0), "");

        newOwner.submitRoot(registry, rootfieldId, keccak256("root.new-owner"));
        rootfield = registry.getRootfield(rootfieldId);
        _assertTrue(rootfield.latestRoot == keccak256("root.new-owner"));
        _assertTrue(rootfield.rootCount == 1);
        _assertTrue(rootfield.pulseCount == 3);
    }

    function testTransferRootfieldOwnershipEmitsStatusPulseAndOwnershipEvent() public {
        bytes32 rootfieldId = keccak256("rootfield.transfer.events");
        RootfieldRegistryCaller newOwner = new RootfieldRegistryCaller();
        registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");

        vm.recordLogs();
        bytes32 pulseId = registry.transferRootfieldOwnership(rootfieldId, address(newOwner), "rootfield://transfer");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        _assertTrue(logs.length == 2);
        _assertTrue(logs[0].emitter == address(registry));
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

        _assertTrue(pulseType == 3);
        _assertTrue(subject == rootfieldId);
        _assertTrue(commitment == keccak256(abi.encode(address(this), address(newOwner))));
        _assertTrue(parentPulseId == bytes32(0));
        _assertTrue(sequence == 2);
        _assertTrue(occurredAt > 0);
        _assertTrue(keccak256(bytes(uri)) == keccak256("rootfield://transfer"));

        _assertTrue(logs[1].emitter == address(registry));
        _assertTrue(logs[1].topics[0] == OWNERSHIP_TRANSFERRED_SIGNATURE);
        _assertTrue(logs[1].topics[1] == rootfieldId);
        _assertTrue(logs[1].topics[2] == bytes32(uint256(uint160(address(this)))));
        _assertTrue(logs[1].topics[3] == bytes32(uint256(uint160(address(newOwner)))));

        string memory evidenceURI = abi.decode(logs[1].data, (string));
        _assertTrue(keccak256(bytes(evidenceURI)) == keccak256("rootfield://transfer"));
    }

    function testCannotTransferRootfieldToZeroOwner() public {
        bytes32 rootfieldId = keccak256("rootfield.transfer.zero");
        registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");

        vm.expectRevert(RootfieldRegistry.ZeroRootfieldOwner.selector);
        registry.transferRootfieldOwnership(rootfieldId, address(0), "");
    }

    function testCannotTransferInactiveRootfieldOwnership() public {
        bytes32 rootfieldId = keccak256("rootfield.transfer.inactive");
        bytes32 registrationPulseId =
            registry.registerRootfield(rootfieldId, keccak256("schema.v0"), keccak256("metadata"), "");
        registry.deactivateRootfield(rootfieldId, registrationPulseId, "rootfield://deactivate");
        RootfieldRegistryCaller newOwner = new RootfieldRegistryCaller();

        vm.expectRevert(abi.encodeWithSelector(RootfieldRegistry.RootfieldInactive.selector, rootfieldId));
        registry.transferRootfieldOwnership(rootfieldId, address(newOwner), "");
    }

    function _assertTrue(bool condition) private pure {
        if (!condition) {
            revert AssertionFailed();
        }
    }
}
