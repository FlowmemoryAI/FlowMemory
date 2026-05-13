// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ArtifactRegistry} from "../contracts/ArtifactRegistry.sol";
import {CursorRegistry} from "../contracts/CursorRegistry.sol";
import {FlowMemoryHookAdapter} from "../contracts/FlowMemoryHookAdapter.sol";
import {ReceiptVerifier} from "../contracts/ReceiptVerifier.sol";
import {VerifierReportRegistry} from "../contracts/VerifierReportRegistry.sol";
import {VerifierRegistry} from "../contracts/VerifierRegistry.sol";
import {WorkerRegistry} from "../contracts/WorkerRegistry.sol";
import {WorkDebtScheduler} from "../contracts/WorkDebtScheduler.sol";
import {WorkReceiptRegistry} from "../contracts/WorkReceiptRegistry.sol";
import {IArtifactRegistry} from "../contracts/interfaces/IArtifactRegistry.sol";
import {IReceiptVerifier} from "../contracts/interfaces/IReceiptVerifier.sol";
import {IUniswapV4SwapHookLike} from "../contracts/interfaces/IUniswapV4SwapHookLike.sol";
import {IVerifierRegistry} from "../contracts/interfaces/IVerifierRegistry.sol";
import {IWorkDebtScheduler} from "../contracts/interfaces/IWorkDebtScheduler.sol";
import {IWorkerRegistry} from "../contracts/interfaces/IWorkerRegistry.sol";

interface LiveV0Vm {
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

contract CursorRegistryCaller {
    function advanceCursor(CursorRegistry registry, bytes32 cursorId, bytes32 positionCommitment) external {
        registry.advanceCursor(cursorId, positionCommitment, keccak256("metadata.v2"), "cursor://evidence");
    }
}

contract ArtifactRegistryCaller {
    function deprecateArtifact(ArtifactRegistry registry, bytes32 artifactId) external {
        registry.deprecateArtifact(artifactId, keccak256("artifact.deprecated"), "artifact://deprecated");
    }
}

contract WorkerRegistryCaller {
    function updateWorkerMetadata(WorkerRegistry registry) external {
        registry.updateWorkerMetadata(keccak256("worker.metadata.v2"), "worker://metadata-v2");
    }
}

contract VerifierRegistryCaller {
    function updateVerifierMetadata(VerifierRegistry registry) external {
        registry.updateVerifierMetadata(keccak256("verifier.metadata.v2"), "verifier://metadata-v2");
    }
}

contract WorkReceiptRegistryCaller {
    function setWorkerAuthorization(WorkReceiptRegistry registry, address worker, bool authorized) external {
        registry.setWorkerAuthorization(worker, authorized);
    }

    function submitWorkReceipt(WorkReceiptRegistry registry, bytes32 receiptId, uint8 lane) external {
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.alpha"),
            lane,
            keccak256("subject.alpha"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            "work://evidence"
        );
    }
}

contract VerifierReportRegistryCaller {
    function setVerifierAuthorization(VerifierReportRegistry registry, address verifier, bool authorized) external {
        registry.setVerifierAuthorization(verifier, authorized);
    }

    function submitVerifierReport(VerifierReportRegistry registry, bytes32 reportId, uint8 status) external {
        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.alpha"),
            keccak256("receipt.alpha"),
            status,
            keccak256("report.digest"),
            keccak256("evidence.commitment"),
            "verifier://evidence"
        );
    }
}

contract WorkDebtSchedulerCaller {
    function markWorkComplete(WorkDebtScheduler scheduler, bytes32 workId) external {
        scheduler.markWorkComplete(workId, keccak256("completion"), keccak256("metadata"), "work://evidence");
    }
}

contract LiveV0PackageTest {
    LiveV0Vm private constant vm = LiveV0Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FLOWPULSE_SIGNATURE =
        keccak256("FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)");

    error AssertionFailed();

    function testCursorRegistryRegistersAndAdvancesCommitments() public {
        CursorRegistry registry = new CursorRegistry();
        bytes32 cursorId = keccak256("cursor.alpha");
        bytes32 streamId = keccak256("stream.alpha");

        registry.registerCursor(cursorId, streamId, keccak256("position.1"), keccak256("metadata.1"), "cursor://meta");
        registry.advanceCursor(cursorId, keccak256("position.2"), keccak256("metadata.2"), "cursor://evidence");

        CursorRegistry.Cursor memory cursor = registry.getCursor(cursorId);
        _assertTrue(cursor.owner == address(this));
        _assertTrue(cursor.streamId == streamId);
        _assertTrue(cursor.positionCommitment == keccak256("position.2"));
        _assertTrue(cursor.metadataHash == keccak256("metadata.2"));
        _assertTrue(cursor.updateCount == 2);
        _assertTrue(cursor.active);
    }

    function testCursorRegistryRejectsZeroIdsAndCommitments() public {
        CursorRegistry registry = new CursorRegistry();

        vm.expectRevert(CursorRegistry.ZeroCursorId.selector);
        registry.registerCursor(
            bytes32(0), keccak256("stream.zero"), keccak256("position.1"), keccak256("metadata"), ""
        );

        vm.expectRevert(CursorRegistry.ZeroStreamId.selector);
        registry.registerCursor(
            keccak256("cursor.zero-stream"), bytes32(0), keccak256("position.1"), keccak256("metadata"), ""
        );

        vm.expectRevert(CursorRegistry.ZeroPositionCommitment.selector);
        registry.registerCursor(
            keccak256("cursor.zero-position"), keccak256("stream.zero-position"), bytes32(0), keccak256("metadata"), ""
        );

        bytes32 cursorId = keccak256("cursor.advance-zero");
        registry.registerCursor(cursorId, keccak256("stream.advance-zero"), keccak256("position.1"), bytes32(0), "");

        vm.expectRevert(CursorRegistry.ZeroPositionCommitment.selector);
        registry.advanceCursor(cursorId, bytes32(0), keccak256("metadata.2"), "");
    }

    function testCursorRegistryRejectsDuplicateAndNonOwnerAdvance() public {
        CursorRegistry registry = new CursorRegistry();
        bytes32 cursorId = keccak256("cursor.beta");
        registry.registerCursor(cursorId, keccak256("stream.beta"), keccak256("position.1"), keccak256("metadata"), "");

        vm.expectRevert(abi.encodeWithSelector(CursorRegistry.CursorAlreadyRegistered.selector, cursorId));
        registry.registerCursor(cursorId, keccak256("stream.beta"), keccak256("position.1"), keccak256("metadata"), "");

        CursorRegistryCaller caller = new CursorRegistryCaller();
        vm.expectRevert(abi.encodeWithSelector(CursorRegistry.NotCursorOwner.selector, cursorId, address(caller)));
        caller.advanceCursor(registry, cursorId, keccak256("position.2"));

        bytes32 missingCursorId = keccak256("cursor.missing");
        vm.expectRevert(abi.encodeWithSelector(CursorRegistry.CursorNotRegistered.selector, missingCursorId));
        registry.advanceCursor(missingCursorId, keccak256("position.2"), keccak256("metadata"), "");
    }

    function testWorkerAndVerifierRegistriesStoreSelfRegisteredMetadata() public {
        WorkerRegistry workers = new WorkerRegistry();
        VerifierRegistry verifiers = new VerifierRegistry();

        workers.registerWorker(
            keccak256("worker.operator"), keccak256("worker.role"), keccak256("worker.metadata"), "worker://meta"
        );
        verifiers.registerVerifier(
            keccak256("verifier.operator"),
            keccak256("verifier.role"),
            keccak256("verifier.metadata"),
            "verifier://meta"
        );

        WorkerRegistry.Worker memory worker = workers.getWorker(address(this));
        VerifierRegistry.Verifier memory verifier = verifiers.getVerifier(address(this));

        _assertTrue(worker.operatorId == keccak256("worker.operator"));
        _assertTrue(worker.role == keccak256("worker.role"));
        _assertTrue(worker.metadataHash == keccak256("worker.metadata"));
        _assertTrue(worker.status == IWorkerRegistry.WorkerStatus.Active);
        _assertTrue(worker.updateCount == 1);
        _assertTrue(worker.active);

        _assertTrue(verifier.operatorId == keccak256("verifier.operator"));
        _assertTrue(verifier.role == keccak256("verifier.role"));
        _assertTrue(verifier.metadataHash == keccak256("verifier.metadata"));
        _assertTrue(verifier.status == IVerifierRegistry.VerifierStatus.Active);
        _assertTrue(verifier.updateCount == 1);
        _assertTrue(verifier.active);
    }

    function testWorkerAndVerifierRegistriesRejectDuplicateAndZeroFields() public {
        WorkerRegistry workers = new WorkerRegistry();
        VerifierRegistry verifiers = new VerifierRegistry();

        vm.expectRevert(WorkerRegistry.ZeroOperatorId.selector);
        workers.registerWorker(bytes32(0), keccak256("worker.role"), keccak256("worker.metadata"), "");

        vm.expectRevert(WorkerRegistry.ZeroWorkerRole.selector);
        workers.registerWorker(keccak256("worker.operator"), bytes32(0), keccak256("worker.metadata"), "");

        vm.expectRevert(VerifierRegistry.ZeroOperatorId.selector);
        verifiers.registerVerifier(bytes32(0), keccak256("verifier.role"), keccak256("verifier.metadata"), "");

        vm.expectRevert(VerifierRegistry.ZeroVerifierRole.selector);
        verifiers.registerVerifier(keccak256("verifier.operator"), bytes32(0), keccak256("verifier.metadata"), "");

        workers.registerWorker(keccak256("worker.operator"), keccak256("worker.role"), keccak256("worker.metadata"), "");
        verifiers.registerVerifier(
            keccak256("verifier.operator"), keccak256("verifier.role"), keccak256("verifier.metadata"), ""
        );

        vm.expectRevert(abi.encodeWithSelector(WorkerRegistry.WorkerAlreadyRegistered.selector, address(this)));
        workers.registerWorker(
            keccak256("worker.operator.v2"), keccak256("worker.role.v2"), keccak256("worker.metadata.v2"), ""
        );

        vm.expectRevert(abi.encodeWithSelector(VerifierRegistry.VerifierAlreadyRegistered.selector, address(this)));
        verifiers.registerVerifier(
            keccak256("verifier.operator.v2"), keccak256("verifier.role.v2"), keccak256("verifier.metadata.v2"), ""
        );
    }

    function testWorkerAndVerifierRegistriesDeactivateAndRejectUnregisteredUpdates() public {
        WorkerRegistry workers = new WorkerRegistry();
        VerifierRegistry verifiers = new VerifierRegistry();
        WorkerRegistryCaller workerCaller = new WorkerRegistryCaller();
        VerifierRegistryCaller verifierCaller = new VerifierRegistryCaller();

        vm.expectRevert(abi.encodeWithSelector(WorkerRegistry.WorkerNotRegistered.selector, address(workerCaller)));
        workerCaller.updateWorkerMetadata(workers);

        vm.expectRevert(
            abi.encodeWithSelector(VerifierRegistry.VerifierNotRegistered.selector, address(verifierCaller))
        );
        verifierCaller.updateVerifierMetadata(verifiers);

        workers.registerWorker(
            keccak256("worker.operator"), keccak256("worker.role"), keccak256("worker.metadata"), "worker://meta"
        );
        verifiers.registerVerifier(
            keccak256("verifier.operator"),
            keccak256("verifier.role"),
            keccak256("verifier.metadata"),
            "verifier://meta"
        );

        workers.deactivateWorker(keccak256("worker.reason"), "worker://inactive");
        verifiers.deactivateVerifier(keccak256("verifier.reason"), "verifier://inactive");

        WorkerRegistry.Worker memory worker = workers.getWorker(address(this));
        VerifierRegistry.Verifier memory verifier = verifiers.getVerifier(address(this));

        _assertTrue(worker.status == IWorkerRegistry.WorkerStatus.Inactive);
        _assertTrue(!worker.active);
        _assertTrue(worker.updateCount == 2);
        _assertTrue(verifier.status == IVerifierRegistry.VerifierStatus.Inactive);
        _assertTrue(!verifier.active);
        _assertTrue(verifier.updateCount == 2);

        vm.expectRevert(abi.encodeWithSelector(WorkerRegistry.WorkerNotActive.selector, address(this)));
        workers.updateWorkerMetadata(keccak256("worker.metadata.v2"), "worker://metadata-v2");

        vm.expectRevert(abi.encodeWithSelector(VerifierRegistry.VerifierNotActive.selector, address(this)));
        verifiers.updateVerifierMetadata(keccak256("verifier.metadata.v2"), "verifier://metadata-v2");
    }

    function testArtifactRegistryStoresCommitmentAndEmitsAdvisoryUri() public {
        ArtifactRegistry registry = new ArtifactRegistry();
        bytes32 artifactId = keccak256("artifact.alpha");
        string memory artifactURI = "artifact://advisory-log-data";

        vm.recordLogs();
        registry.registerArtifact(
            artifactId,
            keccak256("rootfield.alpha"),
            keccak256("artifact.type"),
            keccak256("artifact.commitment"),
            keccak256("schema.hash"),
            keccak256("metadata.hash"),
            artifactURI
        );
        LiveV0Vm.Log[] memory logs = vm.getRecordedLogs();

        ArtifactRegistry.Artifact memory artifact = registry.getArtifact(artifactId);
        _assertTrue(artifact.owner == address(this));
        _assertTrue(artifact.submitter == address(this));
        _assertTrue(artifact.rootfieldId == keccak256("rootfield.alpha"));
        _assertTrue(artifact.artifactType == keccak256("artifact.type"));
        _assertTrue(artifact.commitmentHash == keccak256("artifact.commitment"));
        _assertTrue(artifact.status == IArtifactRegistry.ArtifactStatus.Active);
        _assertTrue(artifact.exists);
        _assertTrue(logs.length == 1);
        _assertTrue(logs[0].emitter == address(registry));
    }

    function testArtifactRegistryRejectsDuplicateAndInvalidCommitments() public {
        ArtifactRegistry registry = new ArtifactRegistry();
        bytes32 artifactId = keccak256("artifact.beta");

        vm.expectRevert(ArtifactRegistry.ZeroArtifactId.selector);
        registry.registerArtifact(
            bytes32(0),
            keccak256("rootfield.beta"),
            keccak256("artifact.type"),
            keccak256("artifact.commitment"),
            keccak256("schema.hash"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(ArtifactRegistry.ZeroRootfieldId.selector);
        registry.registerArtifact(
            artifactId,
            bytes32(0),
            keccak256("artifact.type"),
            keccak256("artifact.commitment"),
            keccak256("schema.hash"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(ArtifactRegistry.ZeroArtifactType.selector);
        registry.registerArtifact(
            artifactId,
            keccak256("rootfield.beta"),
            bytes32(0),
            keccak256("artifact.commitment"),
            keccak256("schema.hash"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(ArtifactRegistry.ZeroCommitmentHash.selector);
        registry.registerArtifact(
            artifactId,
            keccak256("rootfield.beta"),
            keccak256("artifact.type"),
            bytes32(0),
            keccak256("schema.hash"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(ArtifactRegistry.ZeroSchemaHash.selector);
        registry.registerArtifact(
            artifactId,
            keccak256("rootfield.beta"),
            keccak256("artifact.type"),
            keccak256("artifact.commitment"),
            bytes32(0),
            keccak256("metadata.hash"),
            ""
        );

        registry.registerArtifact(
            artifactId,
            keccak256("rootfield.beta"),
            keccak256("artifact.type"),
            keccak256("artifact.commitment"),
            keccak256("schema.hash"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(ArtifactRegistry.ArtifactAlreadyRegistered.selector, artifactId));
        registry.registerArtifact(
            artifactId,
            keccak256("rootfield.beta"),
            keccak256("artifact.type"),
            keccak256("artifact.commitment.v2"),
            keccak256("schema.hash"),
            keccak256("metadata.hash"),
            ""
        );
    }

    function testArtifactRegistryDeprecatesOnlyByOwner() public {
        ArtifactRegistry registry = new ArtifactRegistry();
        ArtifactRegistryCaller caller = new ArtifactRegistryCaller();
        bytes32 artifactId = keccak256("artifact.gamma");
        bytes32 missingArtifactId = keccak256("artifact.missing");

        vm.expectRevert(abi.encodeWithSelector(ArtifactRegistry.ArtifactNotRegistered.selector, missingArtifactId));
        registry.deprecateArtifact(missingArtifactId, keccak256("artifact.deprecated"), "");

        registry.registerArtifact(
            artifactId,
            keccak256("rootfield.gamma"),
            keccak256("artifact.type"),
            keccak256("artifact.commitment"),
            keccak256("schema.hash"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(ArtifactRegistry.NotArtifactOwner.selector, artifactId, address(caller)));
        caller.deprecateArtifact(registry, artifactId);

        registry.deprecateArtifact(artifactId, keccak256("artifact.deprecated"), "artifact://deprecated");
        ArtifactRegistry.Artifact memory artifact = registry.getArtifact(artifactId);
        _assertTrue(artifact.status == IArtifactRegistry.ArtifactStatus.Deprecated);
        _assertTrue(artifact.metadataHash == keccak256("artifact.deprecated"));

        vm.expectRevert(abi.encodeWithSelector(ArtifactRegistry.ArtifactNotActive.selector, artifactId));
        registry.deprecateArtifact(artifactId, keccak256("artifact.deprecated.again"), "");
    }

    function testReceiptVerifierStoresReportCommitmentWithoutReceiptMetadataClaims() public {
        ReceiptVerifier verifier = new ReceiptVerifier();
        bytes32 reportId = keccak256("report.alpha");

        verifier.submitReceiptReport(
            reportId,
            keccak256("observation.id"),
            keccak256("rootfield.alpha"),
            keccak256("receipt.commitment"),
            keccak256("report.hash"),
            "receipt://evidence"
        );

        ReceiptVerifier.ReceiptReport memory report = verifier.getReceiptReport(reportId);
        _assertTrue(report.reporter == address(this));
        _assertTrue(report.observationId == keccak256("observation.id"));
        _assertTrue(report.receiptCommitment == keccak256("receipt.commitment"));
        _assertTrue(report.status == IReceiptVerifier.ReceiptStatus.Submitted);

        bytes32 signatureWithReceiptMetadata =
            keccak256("ReceiptReportSubmitted(bytes32,address,bytes32,bytes32,bytes32,bytes32,string,bytes32,uint256)");
        bytes32 signatureWithoutReceiptMetadata =
            keccak256("ReceiptReportSubmitted(bytes32,address,bytes32,bytes32,bytes32,bytes32,string)");
        _assertTrue(signatureWithReceiptMetadata != signatureWithoutReceiptMetadata);
    }

    function testReceiptVerifierRejectsInvalidZeroFields() public {
        ReceiptVerifier verifier = new ReceiptVerifier();

        vm.expectRevert(ReceiptVerifier.ZeroReportId.selector);
        verifier.submitReceiptReport(
            bytes32(0),
            keccak256("observation.id"),
            keccak256("rootfield.alpha"),
            keccak256("receipt.commitment"),
            keccak256("report.hash"),
            ""
        );

        vm.expectRevert(ReceiptVerifier.ZeroObservationId.selector);
        verifier.submitReceiptReport(
            keccak256("report.zero-observation"),
            bytes32(0),
            keccak256("rootfield.alpha"),
            keccak256("receipt.commitment"),
            keccak256("report.hash"),
            ""
        );

        vm.expectRevert(ReceiptVerifier.ZeroRootfieldId.selector);
        verifier.submitReceiptReport(
            keccak256("report.zero-rootfield"),
            keccak256("observation.id"),
            bytes32(0),
            keccak256("receipt.commitment"),
            keccak256("report.hash"),
            ""
        );

        vm.expectRevert(ReceiptVerifier.ZeroReceiptCommitment.selector);
        verifier.submitReceiptReport(
            keccak256("report.zero-receipt"),
            keccak256("observation.id"),
            keccak256("rootfield.alpha"),
            bytes32(0),
            keccak256("report.hash"),
            ""
        );

        vm.expectRevert(ReceiptVerifier.ZeroReportHash.selector);
        verifier.submitReceiptReport(
            keccak256("report.zero-report-hash"),
            keccak256("observation.id"),
            keccak256("rootfield.alpha"),
            keccak256("receipt.commitment"),
            bytes32(0),
            ""
        );
    }

    function testReceiptVerifierRejectsDuplicateReport() public {
        ReceiptVerifier verifier = new ReceiptVerifier();
        bytes32 reportId = keccak256("report.dup");
        verifier.submitReceiptReport(
            reportId,
            keccak256("observation.id"),
            keccak256("rootfield.alpha"),
            keccak256("receipt.commitment"),
            keccak256("report.hash"),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(ReceiptVerifier.ReceiptReportAlreadySubmitted.selector, reportId));
        verifier.submitReceiptReport(
            reportId,
            keccak256("observation.id"),
            keccak256("rootfield.alpha"),
            keccak256("receipt.commitment"),
            keccak256("report.hash"),
            ""
        );
    }

    function testWorkDebtSchedulerSchedulesAndCompletesWithoutTokenMechanics() public {
        WorkDebtScheduler scheduler = new WorkDebtScheduler();
        bytes32 workId = keccak256("work.alpha");

        scheduler.scheduleWork(
            workId,
            address(this),
            keccak256("rootfield.alpha"),
            keccak256("work.commitment"),
            keccak256("metadata.hash"),
            "work://advisory"
        );
        scheduler.markWorkComplete(workId, keccak256("completion"), keccak256("metadata.done"), "work://evidence");

        WorkDebtScheduler.WorkItem memory item = scheduler.getWorkItem(workId);
        _assertTrue(item.scheduler == address(this));
        _assertTrue(item.worker == address(this));
        _assertTrue(item.workCommitment == keccak256("completion"));
        _assertTrue(item.metadataHash == keccak256("metadata.done"));
        _assertTrue(item.status == IWorkDebtScheduler.WorkStatus.Completed);
    }

    function testWorkDebtSchedulerRejectsZeroFieldsDuplicateAndCompletedTransition() public {
        WorkDebtScheduler scheduler = new WorkDebtScheduler();
        bytes32 workId = keccak256("work.invalid");

        vm.expectRevert(WorkDebtScheduler.ZeroWorkId.selector);
        scheduler.scheduleWork(
            bytes32(0),
            address(this),
            keccak256("rootfield.invalid"),
            keccak256("work.commitment"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(WorkDebtScheduler.ZeroWorker.selector);
        scheduler.scheduleWork(
            workId,
            address(0),
            keccak256("rootfield.invalid"),
            keccak256("work.commitment"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(WorkDebtScheduler.ZeroRootfieldId.selector);
        scheduler.scheduleWork(
            workId, address(this), bytes32(0), keccak256("work.commitment"), keccak256("metadata.hash"), ""
        );

        vm.expectRevert(WorkDebtScheduler.ZeroWorkCommitment.selector);
        scheduler.scheduleWork(
            workId, address(this), keccak256("rootfield.invalid"), bytes32(0), keccak256("metadata.hash"), ""
        );

        vm.expectRevert(abi.encodeWithSelector(WorkDebtScheduler.WorkNotScheduled.selector, workId));
        scheduler.markWorkComplete(workId, keccak256("completion"), keccak256("metadata.done"), "");

        scheduler.scheduleWork(
            workId,
            address(this),
            keccak256("rootfield.invalid"),
            keccak256("work.commitment"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(WorkDebtScheduler.WorkAlreadyScheduled.selector, workId));
        scheduler.scheduleWork(
            workId,
            address(this),
            keccak256("rootfield.invalid"),
            keccak256("work.commitment.v2"),
            keccak256("metadata.hash"),
            ""
        );

        vm.expectRevert(WorkDebtScheduler.ZeroCompletionCommitment.selector);
        scheduler.markWorkComplete(workId, bytes32(0), keccak256("metadata.done"), "");

        scheduler.markWorkComplete(workId, keccak256("completion"), keccak256("metadata.done"), "");

        vm.expectRevert(abi.encodeWithSelector(WorkDebtScheduler.WorkNotScheduledStatus.selector, workId));
        scheduler.markWorkComplete(workId, keccak256("completion.again"), keccak256("metadata.done.again"), "");
    }

    function testWorkDebtSchedulerRejectsNonParticipantCompletion() public {
        WorkDebtScheduler scheduler = new WorkDebtScheduler();
        bytes32 workId = keccak256("work.beta");
        address assignedWorker = address(0xBEEF);

        scheduler.scheduleWork(
            workId,
            assignedWorker,
            keccak256("rootfield.beta"),
            keccak256("work.commitment"),
            keccak256("metadata.hash"),
            ""
        );

        WorkDebtSchedulerCaller caller = new WorkDebtSchedulerCaller();
        vm.expectRevert(abi.encodeWithSelector(WorkDebtScheduler.NotWorkParticipant.selector, workId, address(caller)));
        caller.markWorkComplete(scheduler, workId);
    }

    function testWorkReceiptRegistryAuthorizesWorkerAndStoresLaneReceipt() public {
        WorkReceiptRegistry registry = new WorkReceiptRegistry();
        bytes32 receiptId = keccak256("receipt.alpha");
        uint8 lane = registry.MEMORY_REFRESH();

        registry.setWorkerAuthorization(address(this), true);
        _assertTrue(registry.isAuthorizedWorker(address(this)));

        vm.recordLogs();
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.alpha"),
            lane,
            keccak256("subject.alpha"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            "work://evidence"
        );
        LiveV0Vm.Log[] memory logs = vm.getRecordedLogs();

        WorkReceiptRegistry.WorkReceipt memory receipt = registry.getWorkReceipt(receiptId);
        _assertTrue(receipt.worker == address(this));
        _assertTrue(receipt.rootfieldId == keccak256("rootfield.alpha"));
        _assertTrue(receipt.lane == lane);
        _assertTrue(receipt.inputRoot == keccak256("input.root"));
        _assertTrue(receipt.outputRoot == keccak256("output.root"));
        _assertTrue(receipt.artifactCommitment == keccak256("artifact.commitment"));
        _assertTrue(receipt.exists);
        _assertTrue(logs.length == 1);
        _assertTrue(logs[0].emitter == address(registry));
    }

    function testWorkReceiptRegistryRejectsNonOwnerWorkerAuthorization() public {
        WorkReceiptRegistry registry = new WorkReceiptRegistry();
        WorkReceiptRegistryCaller caller = new WorkReceiptRegistryCaller();

        vm.expectRevert(abi.encodeWithSelector(WorkReceiptRegistry.NotOwner.selector, address(caller)));
        caller.setWorkerAuthorization(registry, address(this), true);

        vm.expectRevert(WorkReceiptRegistry.ZeroWorker.selector);
        registry.setWorkerAuthorization(address(0), true);
    }

    function testWorkReceiptRegistryBlocksRevokedWorker() public {
        WorkReceiptRegistry registry = new WorkReceiptRegistry();
        bytes32 receiptId = keccak256("receipt.revoked");
        uint8 lane = registry.MEMORY_REFRESH();

        registry.setWorkerAuthorization(address(this), true);
        _assertTrue(registry.isAuthorizedWorker(address(this)));

        registry.setWorkerAuthorization(address(this), false);
        _assertTrue(!registry.isAuthorizedWorker(address(this)));

        vm.expectRevert(abi.encodeWithSelector(WorkReceiptRegistry.WorkerNotAuthorized.selector, address(this)));
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.revoked"),
            lane,
            keccak256("subject.revoked"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );
    }

    function testWorkReceiptRegistryRejectsUnauthorizedInvalidLaneAndZeroRoots() public {
        WorkReceiptRegistry registry = new WorkReceiptRegistry();
        bytes32 receiptId = keccak256("receipt.beta");
        uint8 memoryRefreshLane = registry.MEMORY_REFRESH();
        uint8 failureDiscoveryLane = registry.FAILURE_DISCOVERY();

        vm.expectRevert(abi.encodeWithSelector(WorkReceiptRegistry.WorkerNotAuthorized.selector, address(this)));
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.beta"),
            memoryRefreshLane,
            keccak256("subject.beta"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );

        registry.setWorkerAuthorization(address(this), true);

        vm.expectRevert(WorkReceiptRegistry.ZeroReceiptId.selector);
        registry.submitWorkReceipt(
            bytes32(0),
            keccak256("rootfield.beta"),
            memoryRefreshLane,
            keccak256("subject.beta"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(WorkReceiptRegistry.ZeroRootfieldId.selector);
        registry.submitWorkReceipt(
            receiptId,
            bytes32(0),
            memoryRefreshLane,
            keccak256("subject.beta"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(WorkReceiptRegistry.InvalidWorkLane.selector, 0));
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.beta"),
            0,
            keccak256("subject.beta"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(WorkReceiptRegistry.InvalidWorkLane.selector, 9));
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.beta"),
            9,
            keccak256("subject.beta"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(WorkReceiptRegistry.ZeroInputRoot.selector);
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.beta"),
            failureDiscoveryLane,
            keccak256("subject.beta"),
            bytes32(0),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(WorkReceiptRegistry.ZeroOutputRoot.selector);
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.beta"),
            failureDiscoveryLane,
            keccak256("subject.beta"),
            keccak256("input.root"),
            bytes32(0),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(WorkReceiptRegistry.ZeroArtifactCommitment.selector);
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.beta"),
            failureDiscoveryLane,
            keccak256("subject.beta"),
            keccak256("input.root"),
            keccak256("output.root"),
            bytes32(0),
            bytes32(0),
            ""
        );
    }

    function testWorkReceiptRegistryRejectsDuplicateReceipt() public {
        WorkReceiptRegistry registry = new WorkReceiptRegistry();
        bytes32 receiptId = keccak256("receipt.dup");
        uint8 lane = registry.CHECKPOINT_STORAGE();

        registry.setWorkerAuthorization(address(this), true);
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.dup"),
            lane,
            keccak256("subject.dup"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(WorkReceiptRegistry.WorkReceiptAlreadySubmitted.selector, receiptId));
        registry.submitWorkReceipt(
            receiptId,
            keccak256("rootfield.dup"),
            lane,
            keccak256("subject.dup"),
            keccak256("input.root"),
            keccak256("output.root"),
            keccak256("artifact.commitment"),
            bytes32(0),
            ""
        );
    }

    function testVerifierReportRegistryAuthorizesVerifierAndStoresReport() public {
        VerifierReportRegistry registry = new VerifierReportRegistry();
        bytes32 reportId = keccak256("verifier.report.alpha");
        uint8 status = registry.VALID();

        registry.setVerifierAuthorization(address(this), true);
        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.alpha"),
            keccak256("receipt.alpha"),
            status,
            keccak256("report.digest"),
            keccak256("evidence.commitment"),
            "verifier://evidence"
        );

        VerifierReportRegistry.VerifierReport memory report = registry.getVerifierReport(reportId);
        _assertTrue(report.verifier == address(this));
        _assertTrue(report.rootfieldId == keccak256("rootfield.alpha"));
        _assertTrue(report.receiptId == keccak256("receipt.alpha"));
        _assertTrue(report.status == status);
        _assertTrue(report.reportDigest == keccak256("report.digest"));
        _assertTrue(report.evidenceCommitment == keccak256("evidence.commitment"));
        _assertTrue(report.exists);
    }

    function testVerifierReportRegistryAcceptsAllV0StatusesAsAdvisoryReports() public {
        VerifierReportRegistry registry = new VerifierReportRegistry();
        uint8[5] memory statuses =
            [registry.VALID(), registry.INVALID(), registry.UNRESOLVED(), registry.UNSUPPORTED(), registry.REORGED()];

        registry.setVerifierAuthorization(address(this), true);

        for (uint256 i = 0; i < statuses.length; i++) {
            bytes32 reportId = keccak256(abi.encode("verifier.report.status", i));
            registry.submitVerifierReport(
                reportId,
                keccak256("rootfield.status"),
                keccak256(abi.encode("receipt.status", i)),
                statuses[i],
                keccak256(abi.encode("report.digest", i)),
                keccak256(abi.encode("evidence.commitment", i)),
                ""
            );

            VerifierReportRegistry.VerifierReport memory report = registry.getVerifierReport(reportId);
            _assertTrue(report.status == statuses[i]);
            _assertTrue(report.exists);
        }
    }

    function testVerifierReportRegistryRejectsNonOwnerVerifierAuthorization() public {
        VerifierReportRegistry registry = new VerifierReportRegistry();
        VerifierReportRegistryCaller caller = new VerifierReportRegistryCaller();

        vm.expectRevert(abi.encodeWithSelector(VerifierReportRegistry.NotOwner.selector, address(caller)));
        caller.setVerifierAuthorization(registry, address(this), true);

        vm.expectRevert(VerifierReportRegistry.ZeroVerifier.selector);
        registry.setVerifierAuthorization(address(0), true);
    }

    function testVerifierReportRegistryBlocksRevokedVerifier() public {
        VerifierReportRegistry registry = new VerifierReportRegistry();
        bytes32 reportId = keccak256("verifier.report.revoked");
        uint8 status = registry.VALID();

        registry.setVerifierAuthorization(address(this), true);
        _assertTrue(registry.isAuthorizedVerifier(address(this)));

        registry.setVerifierAuthorization(address(this), false);
        _assertTrue(!registry.isAuthorizedVerifier(address(this)));

        vm.expectRevert(abi.encodeWithSelector(VerifierReportRegistry.VerifierNotAuthorized.selector, address(this)));
        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.revoked"),
            keccak256("receipt.revoked"),
            status,
            keccak256("report.digest"),
            keccak256("evidence.commitment"),
            ""
        );
    }

    function testVerifierReportRegistryRejectsUnauthorizedInvalidStatusAndDuplicates() public {
        VerifierReportRegistry registry = new VerifierReportRegistry();
        bytes32 reportId = keccak256("verifier.report.beta");
        uint8 validStatus = registry.VALID();
        uint8 unresolvedStatus = registry.UNRESOLVED();
        uint8 reorgedStatus = registry.REORGED();
        uint8 statusAfterReorged = reorgedStatus + 1;

        vm.expectRevert(abi.encodeWithSelector(VerifierReportRegistry.VerifierNotAuthorized.selector, address(this)));
        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.beta"),
            keccak256("receipt.beta"),
            validStatus,
            keccak256("report.digest"),
            keccak256("evidence.commitment"),
            ""
        );

        registry.setVerifierAuthorization(address(this), true);

        vm.expectRevert(VerifierReportRegistry.ZeroReportId.selector);
        registry.submitVerifierReport(
            bytes32(0),
            keccak256("rootfield.beta"),
            keccak256("receipt.beta"),
            validStatus,
            keccak256("report.digest"),
            keccak256("evidence.commitment"),
            ""
        );

        vm.expectRevert(VerifierReportRegistry.ZeroReportTarget.selector);
        registry.submitVerifierReport(
            reportId,
            bytes32(0),
            bytes32(0),
            validStatus,
            keccak256("report.digest"),
            keccak256("evidence.commitment"),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(VerifierReportRegistry.InvalidReportStatus.selector, 0));
        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.beta"),
            keccak256("receipt.beta"),
            0,
            keccak256("report.digest"),
            keccak256("evidence.commitment"),
            ""
        );

        vm.expectRevert(abi.encodeWithSelector(VerifierReportRegistry.InvalidReportStatus.selector, statusAfterReorged));
        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.beta"),
            keccak256("receipt.beta"),
            statusAfterReorged,
            keccak256("report.digest"),
            keccak256("evidence.commitment"),
            ""
        );

        vm.expectRevert(VerifierReportRegistry.ZeroReportDigest.selector);
        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.beta"),
            keccak256("receipt.beta"),
            validStatus,
            bytes32(0),
            keccak256("evidence.commitment"),
            ""
        );

        vm.expectRevert(VerifierReportRegistry.ZeroEvidenceCommitment.selector);
        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.beta"),
            keccak256("receipt.beta"),
            validStatus,
            keccak256("report.digest"),
            bytes32(0),
            ""
        );

        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.beta"),
            keccak256("receipt.beta"),
            unresolvedStatus,
            keccak256("report.digest"),
            keccak256("evidence.commitment"),
            ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(VerifierReportRegistry.VerifierReportAlreadySubmitted.selector, reportId)
        );
        registry.submitVerifierReport(
            reportId,
            keccak256("rootfield.beta"),
            keccak256("receipt.beta"),
            reorgedStatus,
            keccak256("report.digest.2"),
            keccak256("evidence.commitment.2"),
            ""
        );
    }

    function testFlowMemoryHookAdapterEmitsObservationAndReturnsSelector() public {
        FlowMemoryHookAdapter adapter = new FlowMemoryHookAdapter();
        bytes memory hookData = abi.encode(keccak256("artifact.commitment"));
        bytes32 poolId = keccak256("pool.alpha");
        bytes32 rootfieldId = keccak256("rootfield.alpha");
        bytes32 commitment = keccak256("hook.commitment");

        vm.recordLogs();
        bytes4 selector = adapter.afterSwap(address(this), poolId, rootfieldId, commitment, hookData);
        LiveV0Vm.Log[] memory logs = vm.getRecordedLogs();

        _assertTrue(selector == adapter.AFTER_SWAP_SELECTOR());
        _assertTrue(logs.length == 2);
        _assertTrue(logs[0].emitter == address(adapter));
        _assertTrue(logs[1].emitter == address(adapter));
        _assertTrue(logs[1].topics.length == 4);
        _assertTrue(logs[1].topics[0] == FLOWPULSE_SIGNATURE);
        _assertTrue(logs[1].topics[2] == rootfieldId);
        _assertTrue(logs[1].topics[3] == bytes32(uint256(uint160(address(this)))));

        (
            uint8 pulseType,
            bytes32 subject,
            bytes32 flowPulseCommitment,
            bytes32 parentPulseId,
            uint64 sequence,
            uint64 occurredAt,
            string memory uri
        ) = abi.decode(logs[1].data, (uint8, bytes32, bytes32, bytes32, uint64, uint64, string));

        _assertTrue(pulseType == 4);
        _assertTrue(subject == poolId);
        _assertTrue(flowPulseCommitment == commitment);
        _assertTrue(parentPulseId == bytes32(0));
        _assertTrue(sequence == 1);
        _assertTrue(occurredAt > 0);
        _assertTrue(keccak256(bytes(uri)) == keccak256("flowmemory://uniswap-v4/after-swap"));
    }

    function testFlowMemoryHookAdapterExposesUniswapV4AfterSwapShape() public {
        FlowMemoryHookAdapter adapter = new FlowMemoryHookAdapter();
        bytes32 rootfieldId = keccak256("rootfield.v4");
        bytes32 commitment = keccak256("hook.commitment.v4");
        bytes32 parentPulseId = keccak256("parent.pulse");
        IUniswapV4SwapHookLike.PoolKey memory key = _samplePoolKey(address(adapter));
        IUniswapV4SwapHookLike.SwapParams memory params = _sampleSwapParams();
        bytes memory hookData = adapter.encodeSwapHookData(
            rootfieldId, commitment, parentPulseId, "flowmemory://uniswap-v4/canary-after-swap"
        );

        vm.recordLogs();
        (bytes4 selector, int128 hookDelta) = adapter.afterSwap(address(this), key, params, int256(123), hookData);
        LiveV0Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 poolId = keccak256(abi.encode(key.currency0, key.currency1, key.fee, key.tickSpacing, key.hooks));
        _assertTrue(selector == adapter.UNISWAP_V4_AFTER_SWAP_SELECTOR());
        _assertTrue(hookDelta == 0);
        _assertTrue(logs.length == 2);
        _assertTrue(logs[1].topics[0] == FLOWPULSE_SIGNATURE);
        _assertTrue(logs[1].topics[2] == rootfieldId);
        _assertTrue(logs[1].topics[3] == bytes32(uint256(uint160(address(this)))));
        _assertSwapPulseData(
            logs[1].data, poolId, commitment, parentPulseId, "flowmemory://uniswap-v4/canary-after-swap"
        );
    }

    function testFlowMemoryHookAdapterUsesDefaultUriForEmptyUniswapV4HookUri() public {
        FlowMemoryHookAdapter adapter = new FlowMemoryHookAdapter();
        bytes32 rootfieldId = keccak256("rootfield.v4.default-uri");
        bytes32 commitment = keccak256("hook.commitment.v4.default-uri");
        IUniswapV4SwapHookLike.PoolKey memory key = _samplePoolKey(address(adapter));
        IUniswapV4SwapHookLike.SwapParams memory params = _sampleSwapParams();
        bytes memory hookData = adapter.encodeSwapHookData(rootfieldId, commitment, bytes32(0), "");

        vm.recordLogs();
        adapter.afterSwap(address(this), key, params, int256(123), hookData);
        LiveV0Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 poolId = keccak256(abi.encode(key.currency0, key.currency1, key.fee, key.tickSpacing, key.hooks));
        _assertSwapPulseData(logs[1].data, poolId, commitment, bytes32(0), "flowmemory://uniswap-v4/after-swap");
    }

    function testFlowMemoryHookAdapterRejectsZeroCommitment() public {
        FlowMemoryHookAdapter adapter = new FlowMemoryHookAdapter();

        vm.expectRevert(FlowMemoryHookAdapter.ZeroCommitment.selector);
        adapter.afterSwap(address(this), keccak256("pool.alpha"), keccak256("rootfield.alpha"), bytes32(0), "");
    }

    function testFlowMemoryHookAdapterRejectsZeroSwapInputs() public {
        FlowMemoryHookAdapter adapter = new FlowMemoryHookAdapter();

        vm.expectRevert(FlowMemoryHookAdapter.ZeroSender.selector);
        adapter.afterSwap(
            address(0), keccak256("pool.alpha"), keccak256("rootfield.alpha"), keccak256("commitment"), ""
        );

        vm.expectRevert(FlowMemoryHookAdapter.ZeroPoolId.selector);
        adapter.afterSwap(address(this), bytes32(0), keccak256("rootfield.alpha"), keccak256("commitment"), "");

        vm.expectRevert(FlowMemoryHookAdapter.ZeroRootfieldId.selector);
        adapter.afterSwap(address(this), keccak256("pool.alpha"), bytes32(0), keccak256("commitment"), "");
    }

    function testFlowMemoryHookAdapterRejectsEmptyUniswapV4HookData() public {
        FlowMemoryHookAdapter adapter = new FlowMemoryHookAdapter();
        IUniswapV4SwapHookLike.PoolKey memory key = _samplePoolKey(address(adapter));
        IUniswapV4SwapHookLike.SwapParams memory params = _sampleSwapParams();

        vm.expectRevert(FlowMemoryHookAdapter.EmptyHookData.selector);
        adapter.afterSwap(address(this), key, params, int256(0), "");
    }

    function testFlowMemoryHookAdapterRejectsInvalidUniswapV4HookInputs() public {
        FlowMemoryHookAdapter adapter = new FlowMemoryHookAdapter();
        IUniswapV4SwapHookLike.PoolKey memory key = _samplePoolKey(address(adapter));
        IUniswapV4SwapHookLike.SwapParams memory params = _sampleSwapParams();
        bytes memory validHookData =
            adapter.encodeSwapHookData(keccak256("rootfield.v4"), keccak256("commitment.v4"), bytes32(0), "");

        vm.expectRevert(FlowMemoryHookAdapter.ZeroSender.selector);
        adapter.afterSwap(address(0), key, params, int256(0), validHookData);

        bytes memory zeroRootfieldData =
            adapter.encodeSwapHookData(bytes32(0), keccak256("commitment.v4"), bytes32(0), "");
        vm.expectRevert(FlowMemoryHookAdapter.ZeroRootfieldId.selector);
        adapter.afterSwap(address(this), key, params, int256(0), zeroRootfieldData);

        bytes memory zeroCommitmentData =
            adapter.encodeSwapHookData(keccak256("rootfield.v4"), bytes32(0), bytes32(0), "");
        vm.expectRevert(FlowMemoryHookAdapter.ZeroCommitment.selector);
        adapter.afterSwap(address(this), key, params, int256(0), zeroCommitmentData);
    }

    function _assertTrue(bool condition) private pure {
        if (!condition) revert AssertionFailed();
    }

    function _samplePoolKey(address hooks) private pure returns (IUniswapV4SwapHookLike.PoolKey memory) {
        return IUniswapV4SwapHookLike.PoolKey({
            currency0: address(0x1000), currency1: address(0x2000), fee: 3000, tickSpacing: 60, hooks: hooks
        });
    }

    function _sampleSwapParams() private pure returns (IUniswapV4SwapHookLike.SwapParams memory) {
        return IUniswapV4SwapHookLike.SwapParams({zeroForOne: true, amountSpecified: -1 ether, sqrtPriceLimitX96: 42});
    }

    function _assertSwapPulseData(
        bytes memory data,
        bytes32 expectedSubject,
        bytes32 expectedCommitment,
        bytes32 expectedParentPulseId,
        string memory expectedUri
    ) private pure {
        (
            uint8 pulseType,
            bytes32 subject,
            bytes32 flowPulseCommitment,
            bytes32 decodedParentPulseId,
            uint64 sequence,
            uint64 occurredAt,
            string memory uri
        ) = abi.decode(data, (uint8, bytes32, bytes32, bytes32, uint64, uint64, string));

        _assertTrue(pulseType == 4);
        _assertTrue(subject == expectedSubject);
        _assertTrue(flowPulseCommitment == expectedCommitment);
        _assertTrue(decodedParentPulseId == expectedParentPulseId);
        _assertTrue(sequence == 1);
        _assertTrue(occurredAt > 0);
        _assertTrue(keccak256(bytes(uri)) == keccak256(bytes(expectedUri)));
    }
}
