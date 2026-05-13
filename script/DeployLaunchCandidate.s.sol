// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ArtifactRegistry} from "../contracts/ArtifactRegistry.sol";
import {CursorRegistry} from "../contracts/CursorRegistry.sol";
import {FlowMemoryHookAdapter} from "../contracts/FlowMemoryHookAdapter.sol";
import {ReceiptVerifier} from "../contracts/ReceiptVerifier.sol";
import {RootfieldRegistry} from "../contracts/RootfieldRegistry.sol";
import {VerifierRegistry} from "../contracts/VerifierRegistry.sol";
import {VerifierReportRegistry} from "../contracts/VerifierReportRegistry.sol";
import {WorkerRegistry} from "../contracts/WorkerRegistry.sol";
import {WorkDebtScheduler} from "../contracts/WorkDebtScheduler.sol";
import {WorkReceiptRegistry} from "../contracts/WorkReceiptRegistry.sol";

interface Vm {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// @title DeployLaunchCandidate
/// @notice Foundry deployment script for the current FlowMemory V0 testnet surface.
/// @dev This deploys independent V0 contracts only. It does not configure a production
/// protocol, proxy upgrade path, token, custody system, or verifier network.
contract DeployLaunchCandidate {
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;

    error UnexpectedChain(uint256 expected, uint256 actual);

    struct Deployment {
        address rootfieldRegistry;
        address flowMemoryHookAdapter;
        address artifactRegistry;
        address cursorRegistry;
        address receiptVerifier;
        address workerRegistry;
        address verifierRegistry;
        address workReceiptRegistry;
        address verifierReportRegistry;
        address workDebtScheduler;
    }

    event FlowMemoryLaunchCandidateDeployed(
        address indexed rootfieldRegistry,
        address indexed flowMemoryHookAdapter,
        address artifactRegistry,
        address cursorRegistry,
        address receiptVerifier,
        address workerRegistry,
        address verifierRegistry,
        address workReceiptRegistry,
        address verifierReportRegistry,
        address workDebtScheduler
    );

    function run() external returns (Deployment memory deployment) {
        if (block.chainid != BASE_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(BASE_SEPOLIA_CHAIN_ID, block.chainid);
        }

        VM.startBroadcast();

        deployment = Deployment({
            rootfieldRegistry: address(new RootfieldRegistry()),
            flowMemoryHookAdapter: address(new FlowMemoryHookAdapter()),
            artifactRegistry: address(new ArtifactRegistry()),
            cursorRegistry: address(new CursorRegistry()),
            receiptVerifier: address(new ReceiptVerifier()),
            workerRegistry: address(new WorkerRegistry()),
            verifierRegistry: address(new VerifierRegistry()),
            workReceiptRegistry: address(new WorkReceiptRegistry()),
            verifierReportRegistry: address(new VerifierReportRegistry()),
            workDebtScheduler: address(new WorkDebtScheduler())
        });

        emit FlowMemoryLaunchCandidateDeployed(
            deployment.rootfieldRegistry,
            deployment.flowMemoryHookAdapter,
            deployment.artifactRegistry,
            deployment.cursorRegistry,
            deployment.receiptVerifier,
            deployment.workerRegistry,
            deployment.verifierRegistry,
            deployment.workReceiptRegistry,
            deployment.verifierReportRegistry,
            deployment.workDebtScheduler
        );

        VM.stopBroadcast();
    }
}
