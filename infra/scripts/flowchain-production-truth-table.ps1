param(
    [string] $ReportPath = "docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json",
    [string] $MarkdownPath = "docs/agent-runs/live-product-infra-rpc/PRODUCTION_TRUTH_TABLE.md",
    [int] $MaxReportAgeHours = 24,
    [switch] $AllowBlocked
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\flowchain-common.ps1"
. "$PSScriptRoot\flowchain-live-env-common.ps1"

$repoRoot = Set-FlowChainRepoRoot
$reportFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $ReportPath)
$markdownFullPath = Assert-FlowChainPathInsideRepo -RepoRoot $repoRoot -Path (Resolve-FlowChainPath -RepoRoot $repoRoot -Path $MarkdownPath)

$requiredOwnerInputs = @(
    "FLOWCHAIN_RPC_PUBLIC_URL",
    "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
    "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
    "FLOWCHAIN_RPC_TLS_TERMINATED",
    "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
    "FLOWCHAIN_TESTER_WRITE_ENABLED",
    "FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256",
    "FLOWCHAIN_TESTER_MAX_SEND_UNITS",
    "FLOWCHAIN_PILOT_OPERATOR_ACK",
    "FLOWCHAIN_BASE8453_RPC_URL",
    "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
    "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
    "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)
$optionalOwnerInputs = @(
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK"
)
$knownOwnerInputs = @($requiredOwnerInputs + $optionalOwnerInputs)

$definitions = @(
    [ordered]@{
        id = "service-status"
        requirement = "Private FlowChain node and control-plane services are running and readable."
        path = "docs/agent-runs/live-product-infra-rpc/service-status-report.json"
        command = "npm run flowchain:service:status"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "nodeRunning",
            "nodeCommandLineMatched",
            "controlPlaneRunning",
            "controlPlaneCommandLineMatched",
            "controlPlanePortPrivate",
            "stateFileReadable",
            "latestHeightNumeric",
            "finalizedHeightNumeric",
            "latestHeightPositive",
            "stateFileFresh",
            "serviceProfileLive",
            "serviceProfileUnbounded",
            "boundedLiveModeRejectedFalse",
            "relayerLoopStoppedOrHealthy",
            "problemsEmpty",
            "failedProblemsEmpty",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "problems",
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "bind.localDefaultPrivate" = $true
            "serviceProfile.liveProfile" = $true
            "serviceProfile.maxBlocks" = 0
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "service-monitor"
        requirement = "Block production advances over multiple samples."
        path = "docs/agent-runs/live-product-infra-rpc/service-monitor-report.json"
        command = "npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "sampleCountSufficient",
            "serviceStatusSamplesPassed",
            "nodeRunningEverySample",
            "controlPlaneRunningEverySample",
            "heightsReadable",
            "heightNeverRegressed",
            "stateFreshEverySample",
            "heightAdvanced",
            "issuesEmpty",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "issues",
            "issueCodes",
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredMinimums = [ordered]@{
            sampleCount = 2
        }
        requiredReportProperties = [ordered]@{
            "heightAdvanced" = $true
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "operator-doctor"
        requirement = "Operator doctor reports host tools, package scripts, state path, disk, service evidence, ports, owner-input groups, and owner env-file status without printing owner values."
        path = "docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json"
        command = "npm run flowchain:doctor -- -ReportPath docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "service-supervisor-validation"
        requirement = "Service supervisor validation proves crashed local node, control-plane, and bridge relayer loop services can be recovered under the live profile without deleting chain state."
        path = "docs/agent-runs/live-product-infra-rpc/service-supervisor-validation-report.json"
        command = "npm run flowchain:service:supervisor:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "preCleanStopCommandPassed",
            "startIsolatedLiveServiceCommandPassed",
            "beforeStatusCommandPassed",
            "beforeStatusPassed",
            "beforeControlPlanePidRecorded",
            "crashStatusCommandPassed",
            "crashStatusDetected",
            "supervisorOnceRecoveryCommandPassed",
            "restartAttemptsExactlyOne",
            "afterStatusCommandPassed",
            "afterRecoveryStatusPassed",
            "afterRecoveryNodeRunning",
            "afterRecoveryControlPlaneRunning",
            "afterRecoveryHeightNumeric",
            "afterRecoveryLiveProfile",
            "afterRecoveryMaxBlocksUnbounded",
            "beforeNodeCrashPidRecorded",
            "nodeCrashStatusCommandPassed",
            "nodeCrashDetected",
            "supervisorNodeRecoveryCommandPassed",
            "nodeRestartAttemptsExactlyOne",
            "afterNodeRecoveryStatusCommandPassed",
            "afterNodeRecoveryStatusPassed",
            "afterNodeRecoveryNodeRunning",
            "afterNodeRecoveryControlPlaneRunning",
            "afterNodeRecoveryHeightNumeric",
            "afterNodeRecoveryLiveProfile",
            "afterNodeRecoveryMaxBlocksUnbounded",
            "restartWithRelayerLoopCommandPassed",
            "beforeRelayerCrashStatusCommandPassed",
            "beforeRelayerCrashStatusPassed",
            "beforeRelayerCrashPidRecorded",
            "beforeRelayerCrashRunning",
            "beforeRelayerCrashCommandLineMatched",
            "beforeRelayerCrashReportHealthy",
            "relayerCrashStatusCommandPassed",
            "relayerCrashDetected",
            "supervisorRelayerRecoveryCommandPassed",
            "relayerRestartAttemptsExactlyOne",
            "afterRelayerRecoveryStatusCommandPassed",
            "afterRelayerRecoveryStatusPassed",
            "afterRelayerRecoveryNodeRunning",
            "afterRelayerRecoveryControlPlaneRunning",
            "afterRelayerRecoveryLiveProfile",
            "afterRelayerRecoveryMaxBlocksUnbounded",
            "afterRelayerRecoveryLoopRunning",
            "afterRelayerRecoveryLoopPidRecorded",
            "afterRelayerRecoveryLoopCommandLineMatched",
            "afterRelayerRecoveryLoopReportHealthy",
            "childLogPathsInsideRepo",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredMinimums = [ordered]@{
            restartAttempts = 1
            "nodeRecovery.restartAttempts" = 1
            "relayerLoopRecovery.restartAttempts" = 1
        }
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "before.status" = "passed"
            "afterCrash.controlPlaneStatus" = "stopped"
            "afterRecovery.status" = "passed"
            "afterRecovery.nodeRunning" = $true
            "afterRecovery.controlPlaneRunning" = $true
            "afterRecovery.liveProfile" = $true
            "afterRecovery.maxBlocks" = 0
            "nodeRecovery.afterCrash.detected" = $true
            "nodeRecovery.afterRecovery.status" = "passed"
            "nodeRecovery.afterRecovery.nodeRunning" = $true
            "nodeRecovery.afterRecovery.controlPlaneRunning" = $true
            "nodeRecovery.afterRecovery.liveProfile" = $true
            "nodeRecovery.afterRecovery.maxBlocks" = 0
            "relayerLoopRecovery.beforeCrash.status" = "passed"
            "relayerLoopRecovery.beforeCrash.loopStatus" = "running"
            "relayerLoopRecovery.beforeCrash.commandLineMatched" = $true
            "relayerLoopRecovery.beforeCrash.reportHealthy" = $true
            "relayerLoopRecovery.afterCrash.status" = "passed"
            "relayerLoopRecovery.afterCrash.loopStatus" = "stopped"
            "relayerLoopRecovery.afterCrash.detected" = $true
            "relayerLoopRecovery.afterRecovery.status" = "passed"
            "relayerLoopRecovery.afterRecovery.nodeRunning" = $true
            "relayerLoopRecovery.afterRecovery.controlPlaneRunning" = $true
            "relayerLoopRecovery.afterRecovery.liveProfile" = $true
            "relayerLoopRecovery.afterRecovery.maxBlocks" = 0
            "relayerLoopRecovery.afterRecovery.loopStatus" = "running"
            "relayerLoopRecovery.afterRecovery.loopCommandLineMatched" = $true
            "relayerLoopRecovery.afterRecovery.reportHealthy" = $true
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "service-install-validation"
        requirement = "Owner-host service lifecycle validates no-secret Windows Scheduled Task plan/status/uninstall behavior and a bridge-relayer opt-in plan for reboot-persistent live supervisor operation."
        path = "docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json"
        command = "npm run flowchain:service:install:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "installScriptExists",
            "supervisorScriptExists",
            "packageScriptsPresent",
            "planCommandPassed",
            "planDidNotMutate",
            "schedulerCmdletsAvailable",
            "scheduledTaskActionSupportsWorkingDirectory",
            "actionUsesSupervisor",
            "actionUsesRepoWorkingDirectory",
            "liveProfileDefault",
            "noBridgeRelayerDefault",
            "triggerModeBothByDefault",
            "triggerIncludesStartup",
            "triggerIncludesLogon",
            "rebootPersistentTrigger",
            "bridgeRelayerOptInPlanCommandPassed",
            "bridgeRelayerOptInPlanDidNotMutate",
            "bridgeRelayerOptInStartsLoop",
            "bridgeRelayerOptInAddsSupervisorFlag",
            "bridgeRelayerOptInUsesSupervisor",
            "bridgeRelayerOptInKeepsBothTriggers",
            "hasIntervalSeconds",
            "hasMaxRestartAttempts",
            "hasMaxStateAgeSeconds",
            "commandOmitsNonLiveProfile",
            "statusCommandPassed",
            "statusActionReadOnly",
            "statusDidNotMutate",
            "statusTaskExistsStable",
            "statusReportNoSecrets",
            "statusReportEnvValuesPrintedFalse",
            "statusReportBroadcastsFalse",
            "uninstallAbsentPreflightTaskAbsent",
            "uninstallAbsentCommandPassed",
            "uninstallAbsentTaskCommandPassed",
            "uninstallAbsentTaskWasAbsentBefore",
            "uninstallAbsentDidNotCreateTask",
            "uninstallAbsentTaskAbsentAfter",
            "uninstallAbsentDidNotRemoveTask",
            "uninstallAbsentTaskRemovedFalse",
            "uninstallAbsentReportNoSecrets",
            "uninstallAbsentReportEnvValuesPrintedFalse",
            "uninstallAbsentReportBroadcastsFalse",
            "commandsPresent",
            "envValuesPrintedFalse",
            "childReportsNoSecrets",
            "childReportsSecretMarkerFindingsEmpty",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingPackageScripts",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "systemd-service-install-validation"
        requirement = "Owner Linux/VPS service lifecycle validates no-secret systemd live-service and supervisor templates, install/status/uninstall command plans, and autorecovery defaults without mutating the host."
        path = "docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json"
        command = "npm run flowchain:service:install:systemd:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "installScriptExists",
            "installPackageScriptPresent",
            "validationPackageScriptPresent",
            "publicRpcBundleExists",
            "liveServiceTemplateExists",
            "supervisorTemplateExists",
            "renderScriptExists",
            "verifyRunbookExists",
            "rollbackRunbookExists",
            "liveServiceUsesLiveProfile",
            "liveServiceRunsStatusAfterStart",
            "liveServiceReloadRestartsLiveProfile",
            "liveServiceStopPreservesState",
            "liveServiceRestartOnFailure",
            "liveServiceRemainAfterExit",
            "supervisorUsesAutorecoveryLoop",
            "supervisorRestartAlways",
            "bridgeRelayerDefaultOff",
            "bridgeRelayerOptInPlanCommandPassed",
            "bridgeRelayerOptInPlanReportPassed",
            "bridgeRelayerOptInPlanDidNotMutate",
            "bridgeRelayerOptInPlanUsesRenderedUnits",
            "bridgeRelayerOptInStartsLoop",
            "bridgeRelayerOptInUsesSupervisor",
            "bridgeRelayerOptInPlanNoSecrets",
            "bridgeRelayerOptInPlanEnvValuesPrintedFalse",
            "bridgeRelayerOptInPlanBroadcastsFalse",
            "ownerEnvFileUsed",
            "repoWorkingDirectoryUsed",
            "cargoTargetDirIsExternalized",
            "leastPrivilegeHardeningPresent",
            "writePathsScoped",
            "installTargetPresent",
            "renderScriptRendersSystemdUnits",
            "verifyRunbookMentionsSystemdVerify",
            "rollbackRunbookMentionsSystemctl",
            "installPlanValidationPassed",
            "installPlanCommandPassed",
            "installPlanDidNotMutate",
            "installPlanUsesRenderedUnits",
            "installPlanReportNoSecrets",
            "installPlanReportEnvValuesPrintedFalse",
            "installPlanReportBroadcastsFalse",
            "installCommandsPresent",
            "statusCommandsPresent",
            "uninstallCommandsPresent",
            "hostMutationPerformedFalse",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "hostMutationPerformed" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "upgrade-rehearsal"
        requirement = "State-preserving upgrade and rollback rehearsal copies live L1 state, verifies matching hashes after next-release and rollback restore, and documents exact operator commands without host mutation."
        path = "docs/agent-runs/live-product-infra-rpc/upgrade-rehearsal-report.json"
        command = "npm run flowchain:upgrade:rehearse"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "stateSourceExists",
            "sourceStateReadable",
            "previousReleaseStateCopied",
            "backupStateCopied",
            "nextReleaseStateCopied",
            "rollbackStateCopied",
            "sourceStateHashPresent",
            "previousStateHashMatchesSource",
            "nextStateHashMatchesSource",
            "rollbackStateHashMatchesSource",
            "chainIdPreserved",
            "genesisHashPreserved",
            "nextBlockNumberPreserved",
            "packageManifestCaptured",
            "migrationManifestWritten",
            "rollbackManifestWritten",
            "rollbackCommandsPresent",
            "verifyCommandsPresent",
            "workDirInsideRepo",
            "hostMutationPerformedFalse",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "hostMutationPerformed" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "install-check"
        requirement = "Top-level owner-host install check verifies tools, package commands, install runbooks, Windows service install validation, Linux systemd validation, and no-secret boundaries as one operator preflight."
        path = "docs/agent-runs/live-product-infra-rpc/install-check-report.json"
        command = "npm run flowchain:install:check"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "repoRootResolved",
            "packageJsonReadable",
            "requiredPackageScriptsPresent",
            "requiredRunbooksPresent",
            "requiredToolsPresent",
            "diskFreeMeetsMinimum",
            "serviceInstallValidationReportPassed",
            "systemdInstallValidationReportPassed",
            "childValidationsPassed",
            "childValidationsDidNotTimeout",
            "ownerInputNamesOnly",
            "ownerInputAbsenceIsNonRepoBlocker",
            "hostMutationPerformedFalse",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingScripts",
            "missingDocs",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "hostMutationPerformed" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "live-product-e2e"
        requirement = "Local live-product e2e covers runtime, wallet, live infra, and tester rehearsal without public claims."
        path = "docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json"
        command = "npm run flowchain:live-product:e2e -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $false
    },
    [ordered]@{
        id = "live-infra-check"
        requirement = "Live infrastructure readiness separates repo-owned checks from public owner-input blockers."
        path = "docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json"
        command = "npm run flowchain:live-infra:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "wallet-live-service-e2e"
        requirement = "Wallet creation and wallet-to-wallet service flow works against the running private service."
        path = "docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json"
        command = "npm run flowchain:wallet:live-service:e2e"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "serviceStatusSucceeded",
            "healthSchemaOk",
            "faucetQueuedTransactions",
            "senderFundedBalanceReached",
            "sendAccepted",
            "sendQueuedLocalRuntime",
            "sendTxIdsPresent",
            "transferIdPresent",
            "senderDebitApplied",
            "recipientCreditApplied",
            "transferHistoryRecorded",
            "chainStatusReadableBefore",
            "chainStatusReadableAfter",
            "blockHeightAdvanced",
            "localOnly",
            "productionReadyFalse",
            "noLiveBroadcast",
            "broadcastsFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "localOnly" = $true
            "productionReady" = $false
            "noLiveBroadcast" = $true
            "broadcasts" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
        }
    },
    [ordered]@{
        id = "tester-network-e2e"
        requirement = "Separate tester wallets can transact and observe chain state in local rehearsal."
        path = "docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json"
        command = "npm run flowchain:wallet:live-tester:e2e"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "serviceStatusSucceeded",
            "healthSchemaOk",
            "rpcDiscoverSchemaOk",
            "rpcReadinessSchemaOk",
            "testerCountAtLeastFour",
            "walletCreatesPublicOnly",
            "walletAccountsUnique",
            "fundingTxIdsPresent",
            "transferCountMatches",
            "allTransfersQueued",
            "allTransferIdsPresent",
            "allTransferTxIdsPresent",
            "balancesMatchExpected",
            "historyCountsAtLeastTwo",
            "chainStatusReadableBefore",
            "chainStatusReadableAfter",
            "blockHeightAdvanced",
            "packetExecutableSmokeValidated",
            "packetSmokeChecksAllPassed",
            "localOnly",
            "productionReadyFalse",
            "noLiveBroadcast",
            "broadcastsFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "localOnly" = $true
            "productionReady" = $false
            "noLiveBroadcast" = $true
            "broadcasts" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
        }
    },
    [ordered]@{
        id = "owner-inputs"
        requirement = "Owner-provided public RPC, backup, and Base 8453 bridge inputs are configured and valid."
        path = "docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json"
        command = "npm run flowchain:owner-inputs -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "owner-onboarding"
        requirement = "Owner onboarding explains exactly what must be set up, proves FlowChain RPC is repo-owned, and separates the external Base 8453 dependency from this chain's public RPC edge without printing owner values."
        path = "docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json"
        command = "npm run flowchain:owner:onboarding"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "flowChainRpcIsOurs",
            "thirdPartyFlowChainRpcProviderNeededFalse",
            "publicRpcRequiresOwnerPublicEdge",
            "base8453RpcIsExternalChainDependency",
            "localEnvFileSupported",
            "onboardingGroupsPresent",
            "localShellTemplatePresent",
            "nextCommandsPresent",
            "valuesPrintedFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "flowChainRpcIsOurs" = $true
            "thirdPartyFlowChainRpcProviderNeeded" = $false
            "publicRpcRequiresOwnerPublicEdge" = $true
            "base8453RpcIsExternalChainDependency" = $true
            "localEnvFileSupported" = $true
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "owner-signup-checklist"
        requirement = "Owner signup checklist covers every required public RPC, backup, tester-write, and bridge env input, states what to get, and states what not to send."
        path = "docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json"
        command = "npm run flowchain:owner:signup-checklist"
        productionGate = $true
        ownerInputGate = $false
        requiredEmptyArrays = @(
            "missingChecklistCoverage",
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredChecks = @(
            "missingChecklistCoverageEmpty",
            "flowChainRpcIsRepoOwned",
            "thirdPartyFlowChainRpcProviderNeededFalse",
            "localEnvFileSupported",
            "itemCountMinimumMet",
            "externalSignupCountMinimumMet",
            "requiredOwnerEnvNamesPresent",
            "valuesPrintedFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredReportProperties = [ordered]@{
            "flowChainRpcIsRepoOwned" = $true
            "thirdPartyFlowChainRpcProviderNeeded" = $false
            "localEnvFileSupported" = $true
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "owner-activation-plan"
        requirement = "Owner activation plan turns the remaining public launch inputs into ordered stages with exact validation commands, resource boundaries, and no-secret handoff instructions."
        path = "docs/agent-runs/live-product-infra-rpc/owner-activation-plan-report.json"
        command = "npm run flowchain:owner:activation-plan"
        productionGate = $true
        ownerInputGate = $false
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings",
            "missingCoverage",
            "unknownMissingEnvNames",
            "unknownInvalidEnvNames",
            "invalidEnvNames"
        )
        requiredChecks = @(
            "stageCountMinimumMet",
            "requiredEnvCoverageComplete",
            "knownMissingEnvNamesOnly",
            "invalidEnvNamesEmpty",
            "knownInvalidEnvNamesOnly",
            "validationCommandsPresent",
            "ownerMustNotSendPresent",
            "externalResourceMappingPresent",
            "serviceStagePresent",
            "publicRpcStagePresent",
            "backupStagePresent",
            "testerStagePresent",
            "bridgeStagePresent",
            "finalAuditStagePresent",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "owner-go-live-handoff"
        requirement = "Owner go-live handoff converts activation stages, remaining owner inputs, external resources, validation commands, and do-not-send boundaries into one machine-readable launch deck without printing owner values."
        path = "docs/agent-runs/live-product-infra-rpc/owner-go-live-handoff-report.json"
        command = "npm run flowchain:owner:go-live-handoff"
        productionGate = $true
        ownerInputGate = $false
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings",
            "unknownMissingEnvNames",
            "unknownInvalidEnvNames",
            "invalidEnvNames"
        )
        requiredMinimums = [ordered]@{
            stageCount = 8
            nextCommandCount = 6
            mustNotSendCount = 6
            launchSequenceCount = 8
            launchSequenceCommandCount = 20
            launchSequenceExpectedReportPathCount = 8
            rollbackCommandCount = 4
        }
        requiredChecks = @(
            "packageScriptPresent",
            "activationPlanLoaded",
            "activationPlanPassed",
            "signupChecklistLoaded",
            "signupChecklistPassed",
            "ownerInputsLoaded",
            "truthTableLoaded",
            "stageDeckPresent",
            "stageCountMinimumMet",
            "everyStageHasValidationCommand",
            "everyStageHasOwnerMustNotSend",
            "nonReadyStagesExplainBlockers",
            "requiredEnvCoverageComplete",
            "requiredAndOptionalOwnerInputsSeparated",
            "neededNowExcludesOptionalOwnerInputs",
            "knownOwnerInputBlockersOnly",
            "nextOwnerInputsPresentWhenBlocked",
            "nextCommandsPresent",
            "launchSequencePresent",
            "launchSequenceEveryStepHasCommands",
            "launchSequenceEveryStepHasExpectedStatuses",
            "launchSequenceEveryStepHasExpectedReportPath",
            "launchSequenceExpectedReportPathsScoped",
            "launchSequenceEveryStepStopsOnFailure",
            "launchSequenceCoversOwnerEnvReadiness",
            "launchSequenceCoversPublicRpcRender",
            "launchSequenceCoversOwnerHostApplyPlan",
            "launchSequenceCoversOwnerHostApplyExecution",
            "launchSequenceCoversWindowsOwnerHostApplyPlan",
            "launchSequenceCoversWindowsOwnerHostApplyExecution",
            "launchSequenceCoversSystemdInstallPlan",
            "launchSequenceCoversServiceMonitor",
            "launchSequenceCoversPublicRpcCanary",
            "launchSequenceCoversBackupRestore",
            "launchSequenceCoversBridgeRelayer",
            "launchSequenceCoversTesterPacket",
            "launchSequenceCoversCutoverAudit",
            "launchSequenceCoversTruthAndNoSecret",
            "launchSequenceCommandsAvoidInlineEnvAssignment",
            "launchSequenceCommandsAvoidUrls",
            "launchSequencePackageScriptsPresent",
            "rollbackCommandsPresent",
            "rollbackCoversLocalStop",
            "rollbackCoversBridgeEmergencyStop",
            "rollbackCoversOpsSnapshot",
            "rollbackCoversOwnerHostApplyRollback",
            "rollbackCoversWindowsOwnerHostApplyRollback",
            "rollbackPackageScriptsPresent",
            "releaseClaimBlockedUntilTruthPassed",
            "packetShareBlockedUntilReady",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
            "noLiveBroadcast" = $true
        }
    },
    [ordered]@{
        id = "owner-needs-now"
        requirement = "Owner needs-now report answers what the L1 needs now by grouping remaining owner-input blockers into public RPC edge, backup, tester gateway, and Base 8453 bridge actions without printing owner values."
        path = "docs/agent-runs/live-product-infra-rpc/owner-needs-now-report.json"
        command = "npm run flowchain:owner:needs-now"
        productionGate = $true
        ownerInputGate = $false
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings",
            "missingRequiredCoverage",
            "missingSetupCoverage",
            "setupItemsMissingValidation",
            "setupItemsMissingDoNotSend",
            "setupItemsMissingSignupFlag",
            "unknownNeededNowEnvNames",
            "optionalNeededNowEnvNames",
            "invalidEnvNames"
        )
        requiredMinimums = [ordered]@{
            groupCount = 4
            neededNowGroupCount = 1
            setupItemCount = 8
            externalSignupItemCount = 3
        }
        requiredChecks = @(
            "packageScriptPresent",
            "ownerInputsLoaded",
            "ownerGoLiveHandoffLoaded",
            "activationPlanLoaded",
            "truthTableLoaded",
            "reportStatusDeckPresent",
            "groupCountMinimumMet",
            "requiredEnvCoverageComplete",
            "setupItemsCountMinimumMet",
            "setupItemsCoverAllRequiredOwnerInputs",
            "setupItemsValidationCommandsPresent",
            "setupItemsDoNotSendPresent",
            "setupItemsSignupFlagsPresent",
            "setupItemsIncludeExternalSignup",
            "setupItemsIncludeAlwaysOnHost",
            "setupItemsIncludeOwnerEnvFile",
            "groupCommandsPresent",
            "groupDoNotSendPresent",
            "knownNeededNowOwnerInputsOnly",
            "optionalOwnerInputsExcludedFromNeededNow",
            "nextOwnerInputsPresentWhenBlocked",
            "neededNowGroupsPresentWhenBlocked",
            "readyTesterGatewayCaptured",
            "noReleaseReadyClaimWhileBlocked",
            "publicSharingBlockedUntilReady",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredReportProperties = [ordered]@{
            "launchReadinessStatus" = "blocked-owner-input"
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
            "noLiveBroadcast" = $true
        }
    },
    [ordered]@{
        id = "owner-env-template"
        requirement = "Owner env template creates or preserves an ignored local-only NAME=value scaffold and no-secret field guide for every owner input without recording real values."
        path = "docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json"
        command = "npm run flowchain:owner-env:template"
        productionGate = $true
        ownerInputGate = $false
        requiredMinimums = [ordered]@{
            requiredEnvNameCount = 17
            fieldGuideCount = 19
        }
        requiredChecks = @(
            "pathIsGitIgnored",
            "createdOrPreservedLocalFile",
            "templateIncludesAllRequiredEnvNames",
            "requiredEnvNameCountExpected",
            "optionalEnvNameCountExpected",
            "fieldGuideCoversAllRequiredEnvNames",
            "fieldGuideCoversAllOptionalEnvNames",
            "fieldGuideHasValidationForEveryName",
            "fieldGuideHasDoNotSendForEveryName",
            "valuesPrintedFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "pathIsGitIgnored" = $true
            "templateIncludesAllRequiredEnvNames" = $true
            "valuesPrinted" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "owner-env-readiness-validation"
        requirement = "Owner env readiness validation proves missing or unignored owner env files fail before child live gates run and before any owner values can leak."
        path = "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json"
        command = "npm run flowchain:owner-env:readiness:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "missingOwnerEnvFileFailsBeforeChildGates",
            "unignoredOwnerEnvFileFailsBeforeChildGates",
            "scenarioCountExpected",
            "allScenariosPassed",
            "failedScenariosAbsent",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "owner-env-readiness"
        requirement = "Owner env readiness points live checks at the ignored local owner env file and stays blocked only on known owner inputs until real public deployment values exist."
        path = "docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json"
        command = "npm run flowchain:owner-env:readiness -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
        requiredReportProperties = [ordered]@{
            "ownerEnvFile.exists" = $true
            "ownerEnvFile.isFile" = $true
            "ownerEnvFile.gitIgnored" = $true
            "readiness.ownerInputsReady" = $true
            "readiness.liveInfraReady" = $true
            "readiness.publicDeploymentContractReady" = $true
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "tester-write-token-setup"
        requirement = "Tester write token setup creates or preserves the raw bearer token only in ignored local storage, writes only its SHA-256 digest and send cap into the ignored owner env file, and proves no token or digest is printed to committed evidence."
        path = "docs/agent-runs/live-product-infra-rpc/tester-write-token-setup-report.json"
        command = "npm run flowchain:tester:token:setup"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "tokenPathGitIgnored",
            "ownerEnvPathGitIgnored",
            "tokenFileExists",
            "ownerEnvFileExists",
            "tokenLengthSufficient",
            "tokenHashLengthValid",
            "ownerEnvTesterEnabledWritten",
            "ownerEnvTesterHashWritten",
            "ownerEnvTesterCapWritten",
            "rawTokenPrintedFalse",
            "tokenHashPrintedFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "maxSendUnitsConfigured" = $true
            "rawTokenPrinted" = $false
            "tokenHashPrinted" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "public-tester-gateway-e2e"
        requirement = "Public tester write gateway proves friends-and-family wallet create, capped faucet funding, capped tester-to-tester send settlement, over-cap rejection, and no-secret/no-broadcast behavior on a temporary local control plane."
        path = "docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json"
        command = "npm run flowchain:tester:gateway:e2e"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "localOnly",
            "originRestricted",
            "testerGatewayConfigured",
            "testerWriteTokenHashConfigured",
            "walletCreateSchemaOk",
            "testerFaucetSchemaOk",
            "walletSendSchemaOk",
            "accountCountAtLeastTwo",
            "transferAccepted",
            "transferAppliedLocalRuntime",
            "transferIdPresent",
            "capRejected",
            "capRejectStatusCode400",
            "capRejectSchemaOk",
            "capRejectNoSecrets",
            "routesCoverRequired",
            "balancesMatchExpected",
            "noLiveBroadcast",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredMinimums = [ordered]@{
            accountCount = 2
        }
        requiredReportProperties = [ordered]@{
            "localOnly" = $true
            "originRestricted" = $true
            "testerGatewayConfigured" = $true
            "testerWriteTokenHashConfigured" = $true
            "transferAccepted" = $true
            "transferStatus" = "applied_local_runtime"
            "capRejected" = $true
            "capRejectStatusCode" = 400
            "noLiveBroadcast" = $true
            "broadcasts" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
        }
    },
    [ordered]@{
        id = "public-rpc-readiness"
        requirement = "Public FlowChain RPC has URL, TLS acknowledgement, CORS, rate limit, backup path, and response hygiene."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
        command = "npm run flowchain:public-rpc:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "public-rpc-synthetic-canary"
        requirement = "Public RPC synthetic canary runs read-only live probes against the owner endpoint, never plans write methods, and stays owner-blocked without printing endpoint values until the endpoint exists."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json"
        command = "npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
        requiredChecks = @(
            "packageScriptPresent",
            "endpointConfigured",
            "endpointAbsoluteHttp",
            "endpointValuePrintedFalse",
            "publicModeNonLocal",
            "httpsRequiredForPublicMode",
            "safeReadMethodAllowlistEnforced",
            "noWriteMethodsPlanned",
            "noWriteMethodsInvoked",
            "plannedReadPathsCovered",
            "plannedReadMethodsCovered",
            "allProbesPassedWhenNetworkAllowed",
            "responseHygienePassed",
            "broadcastsFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "missingEnvNames",
            "problems",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "syntheticCanaryReady" = $true
            "endpointValuePrinted" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "public-rpc-canary-schedule-validation"
        requirement = "Public RPC canary schedule validation renders no-secret Windows Scheduled Task and Linux systemd timer plans for recurring read-only synthetic canary checks without host mutation or external delivery."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-canary-schedule-validation-report.json"
        command = "npm run flowchain:public-rpc:canary:schedule:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptPresent",
            "syntheticCanaryPackageScriptPresent",
            "canaryScriptExists",
            "canaryScriptReadOnlyPlan",
            "scheduledReportPathInsideRepo",
            "scheduledMarkdownPathInsideRepo",
            "windowsPlanUsesCanaryScript",
            "windowsPlanUsesOwnerEnvFile",
            "windowsPlanHasAllowBlocked",
            "windowsPlanHasReportPath",
            "windowsPlanHasMarkdownPath",
            "windowsPlanUsesRepoWorkingDirectory",
            "windowsPlanDoesNotMutateHost",
            "systemdServiceRendered",
            "systemdServiceUsesOneshot",
            "systemdServiceUsesOwnerEnvFile",
            "systemdServiceHasAllowBlocked",
            "systemdServiceHasReportPath",
            "systemdServiceHasMarkdownPath",
            "systemdServiceHardeningPresent",
            "systemdServiceWritePathsScoped",
            "systemdTimerRendered",
            "systemdTimerPersistent",
            "systemdTimerIntervalConfigured",
            "noExternalDelivery",
            "hostMutationPerformedFalse",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
            "hostMutationPerformed" = $false
        }
    },
    [ordered]@{
        id = "public-rpc-validation"
        requirement = "Public RPC validation harness is present and fail-closed before endpoint sharing."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json"
        command = "npm run flowchain:public-rpc:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "readinessExitedCleanly",
            "localEndpointBlocksPublicReady",
            "localEndpointSelfReportsNonProduction",
            "discoveryMatchesReadinessDeployment",
            "readinessDeploymentFlagsConsistent",
            "noPublicRpcEnvMissing",
            "noFailedEndpointChecks",
            "allowedOriginAccepted",
            "disallowedOriginProbePerformed",
            "disallowedOriginRejected",
            "securityHeaderProbeSkippedForLocalEndpoint",
            "securityHeaderPassRequiredOnlyForPublicMode",
            "rateLimitProbePerformed",
            "rateLimitRejected",
            "rateLimitRetryAfterHeaderPresent",
            "responseHygienePassed",
            "failedProblemsAbsent",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "publicRpcReady" = $false
            "expectedBlockedBecauseEndpointIsLocal" = $true
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "public-rpc-abuse-test"
        requirement = "Public RPC abuse harness proves CORS rejection, media-type rejection, malformed JSON handling, batch/body caps, notification handling, rate limiting, and no-secret summaries."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json"
        command = "npm run flowchain:public-rpc:abuse-test"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "serverStarted",
            "allowedOriginAccepted",
            "disallowedOriginRejected",
            "optionsPreflightPassed",
            "unsupportedMediaTypeRejected",
            "malformedJsonRejected",
            "unknownMethodRejected",
            "transactionSubmitRejected",
            "bridgeObservationSubmitRejected",
            "rawJsonGetRejected",
            "devnetStateRejected",
            "bridgeObservationPostAliasRejected",
            "testerWriteGatewayFailsClosed",
            "badParamsRejected",
            "emptyBatchRejected",
            "oversizedBatchRejected",
            "oversizedBodyRejected",
            "notificationNoContent",
            "rateLimitRejected",
            "responseHygienePassed",
            "failedCasesAbsent",
            "fatalErrorAbsent",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "noLiveBroadcast",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "abuseTestReady" = $true
            "ownerValuesRequired" = $false
            "localOnly" = $true
            "serverBoundToLocalhost" = $true
            "noLiveBroadcast" = $true
            "broadcasts" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
        }
    },
    [ordered]@{
        id = "public-rpc-deployment-bundle"
        requirement = "No-secret public RPC deployment bundle exists and owner-render validation proves HTTPS reverse proxy, service, shell preflight, Windows preflight, tester write preflight, verification, and rollback artifacts render safely."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json"
        command = "npm run flowchain:public-rpc:deployment-bundle"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "edgeTemplatePassed",
            "readmeWritten",
            "nginxTemplateWritten",
            "systemdServiceTemplateWritten",
            "systemdSupervisorTemplateWritten",
            "renderScriptWritten",
            "nginxPreflightScriptWritten",
            "nginxPreflightChecklistWritten",
            "windowsNginxPreflightScriptWritten",
            "windowsNginxPreflightChecklistWritten",
            "windowsNginxPreflightTokensPresent",
            "requiredPlaceholdersPresent",
            "nginxRequiredTokensPresent",
            "systemdLiveServiceTemplatePresent",
            "systemdSupervisorTemplatePresent",
            "renderScriptTokensPresent",
            "nginxPreflightTokensPresent",
            "includesWindowsNginxConfigTest",
            "includesTesterWritePreflight",
            "includesMethodRejectionPreflight",
            "ownerRenderPreflightsRejectWrongMethods",
            "ownerRenderValidationPassed",
            "ownerRenderCommandPassed",
            "ownerRenderFilesHaveNoPlaceholders",
            "ownerRenderWritesShellPreflight",
            "ownerRenderWritesWindowsPreflight",
            "ownerRenderDoesNotPrintTokenHash",
            "ownerRenderFilesDoNotContainTokenHash",
            "includesPrivateOrigin",
            "includesRateLimitPlaceholder",
            "includesTlsPlaceholders",
            "includesCorsOriginForwarding",
            "publicStateMirrorExcluded",
            "devnetStatePublicRpcExcluded",
            "includesNginxConfigTest",
            "includesVerificationCommands",
            "includesRollbackCommands",
            "envExampleHasAllRequiredNames",
            "ownerEnvExampleValuesBlank",
            "noLiveBroadcastCommands",
            "noLiveBroadcastArtifacts",
            "valuesNotPrinted",
            "envValuesNotPrinted",
            "noSecrets",
            "secretMarkerFindingsEmpty",
            "liveBroadcastsDisabled",
            "ownerEnvExampleWritten",
            "verifyRunbookWritten",
            "rollbackRunbookWritten"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "flowChainRpcIsRepoOwned" = $true
            "thirdPartyFlowChainRpcProviderNeeded" = $false
            "privateOrigin" = "127.0.0.1:8787"
            "valuesPrinted" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
            "liveBroadcasts" = $false
        }
    },
    [ordered]@{
        id = "public-rpc-deployment-automation"
        requirement = "Public RPC deployment automation validates owner-host rendering of concrete Nginx, systemd, shell preflight, Windows preflight, tester write unauthenticated rejection probe, synthetic public RPC canary, hashed artifact manifest, Linux and Windows owner-host plan/apply/rollback scripts, install/edge apply phases, post-deploy verification, and rollback phases without host mutation or owner-value leakage."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json"
        command = "npm run flowchain:public-rpc:deployment:automation"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "bundleReportPassed",
            "renderScriptExists",
            "packageScriptPresent",
            "bundleHasOwnerRenderValidation",
            "bundleHasShellPreflight",
            "bundleHasWindowsPreflight",
            "bundleHasRollbackRunbook",
            "bundlePreflightsCheckMethodRejection",
            "ownerPathsOutsideRepo",
            "hostMutationPerformedFalse",
            "valuesPrintedFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty",
            "broadcastsFalse",
            "liveBroadcastsFalse",
            "renderCommandPassed",
            "renderedFilesHaveNoPlaceholders",
            "renderedFilesKeepPrivateOrigin",
            "renderedNginxHasTls",
            "renderedNginxHasCorsForwarding",
            "renderedNginxHasRateLimit",
            "renderedSystemdUsesOwnerEnv",
            "renderedPreflightHasReadinessProbe",
            "renderedPreflightHasTesterUnauthProbe",
            "renderedPreflightHasMethodRejectionProbes",
            "commandPlanIncludesSyntheticCanary",
            "renderedFilesDoNotContainTokenHash",
            "renderedReportDoesNotContainTokenHash",
            "renderedReportKeepsOwnerPathsOutsideRepo",
            "renderedReportNoSecrets",
            "renderedReportBroadcastsFalse",
            "renderedOwnerHostApplyScriptWritten",
            "renderedOwnerHostApplyScriptHasPlanApplyRollback",
            "renderedOwnerHostApplyScriptVerifiesHashes",
            "renderedOwnerHostApplyScriptRunsPostDeployProof",
            "renderedOwnerHostApplyPowerShellWritten",
            "renderedOwnerHostApplyPowerShellHasPlanApplyRollback",
            "renderedOwnerHostApplyPowerShellParses",
            "renderedOwnerHostApplyPowerShellVerifiesHashes",
            "renderedOwnerHostApplyPowerShellRunsPostDeployProof",
            "ownerHostApplyPlanPresent",
            "ownerHostApplyPlanSchema",
            "ownerHostApplyPlanRepoOwned",
            "ownerHostApplyPlanPrivateOrigin",
            "ownerHostApplyPlanArtifactManifestCount",
            "ownerHostApplyPlanAllArtifactsListed",
            "ownerHostApplyPlanArtifactsExist",
            "ownerHostApplyPlanArtifactsHaveSha256",
            "ownerHostApplyPlanInstallTargetsMapped",
            "ownerHostApplyPlanPhaseCount",
            "ownerHostApplyPlanAllPhasesPresent",
            "ownerHostApplyPlanHasMutatingInstallPhase",
            "ownerHostApplyPlanHasMutatingEdgePhase",
            "ownerHostApplyPlanHasReadOnlyProofPhase",
            "ownerHostApplyPlanIncludesSystemdInstallCommand",
            "ownerHostApplyPlanIncludesSystemdStatusCommand",
            "ownerHostApplyPlanIncludesSystemdUninstallRollback",
            "ownerHostApplyPlanIncludesNginxReload",
            "ownerHostApplyPlanIncludesOwnerApplyScript",
            "ownerHostApplyPlanIncludesWindowsOwnerApplyScript",
            "ownerHostApplyPlanIncludesPostDeployEvidence",
            "ownerHostApplyPlanValuesPrintedFalse",
            "ownerHostApplyPlanEnvValuesPrintedFalse",
            "ownerHostApplyPlanNoSecrets",
            "ownerHostApplyPlanBroadcastsFalse",
            "rollbackDrillPerformed",
            "rollbackRenderedConfigExists",
            "rollbackPreviousConfigWritten",
            "rollbackRenderedConfigRestoredFromPrevious",
            "rollbackOriginalConfigRestoredAfterDrill",
            "rollbackArtifactsStayedInsideRenderDir",
            "rollbackDrillNoSecrets",
            "rollbackDrillBroadcastsFalse",
            "cleanupAttempted"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "action" = "Validate"
            "flowChainRpcIsRepoOwned" = $true
            "thirdPartyFlowChainRpcProviderNeeded" = $false
            "valuesPrinted" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
            "liveBroadcasts" = $false
            "hostMutationPerformed" = $false
        }
    },
    [ordered]@{
        id = "public-rpc-command-matrix"
        requirement = "Public RPC command matrix maps preflight, render, service-install, owner-host plan/apply, post-deploy proof, tester, release, and rollback commands to owner inputs, mutation risk, evidence paths, and no-secret boundaries."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-command-matrix-report.json"
        command = "npm run flowchain:public-rpc:command-matrix"
        productionGate = $true
        ownerInputGate = $false
        requiredMinimums = [ordered]@{
            commandCount = 20
            ownerHostCommandCount = 6
            mutatingOwnerHostCommandCount = 4
            committedEvidencePathCount = 12
        }
        requiredChecks = @(
            "packageScriptPresent",
            "allPackageScriptsPresent",
            "phaseCoverageComplete",
            "renderPlanApplyProofRollbackCovered",
            "ownerHostPlanCommandsPresent",
            "ownerHostApplyCommandsPresent",
            "ownerHostRollbackCommandsPresent",
            "mutatingOwnerHostCommandsHaveRollbackCoverage",
            "deploymentAutomationReportPassed",
            "deploymentBundleReportPassed",
            "deploymentAutomationCommandPlanCovered",
            "deploymentAutomationOwnerHostApplyCovered",
            "deploymentAutomationRollbackDrillCovered",
            "deploymentBundleRollbackRunbookCovered",
            "requiredEnvReferencesPresent",
            "validationSignalsPresent",
            "commandsAvoidInlineEnvAssignment",
            "commandsAvoidUrls",
            "commandsAvoidKeyMaterial",
            "ownerInputNamesOnly",
            "committedEvidencePathsCovered",
            "envValuesPrintedFalse",
            "broadcastsFalse",
            "noSecrets"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingPackageScripts",
            "missingPhases",
            "rowsMissingEnvReferences",
            "rowsMissingValidationSignals",
            "commandsWithInlineEnvAssignment",
            "commandsWithUrls",
            "commandsWithKeyMaterialReference",
            "badOwnerInputRows"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "node-operator-package"
        requirement = "No-secret node operator package collects runbooks, command matrix, owner-input names, and current evidence for install, autorecovery, public RPC, backup, ops, bridge, testers, and release gates."
        path = "docs/agent-runs/live-product-infra-rpc/operator-package-report.json"
        command = "npm run flowchain:operator:package"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptsPresent",
            "commandMatrixWritten",
            "readmeWritten",
            "manifestWritten",
            "runbookDocsCopied",
            "evidenceReportsCopied",
            "copiedFileHashesWritten",
            "copiedFileHashesMatch",
            "ownerInputNamesOnly",
            "flowChainRpcIsRepoOwned",
            "thirdPartyFlowChainRpcProviderNeededFalse",
            "noSecretScanPassed",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "broadcastsFalse",
            "noSecrets"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "copiedFileHashMismatches",
            "copiedFilesMissingHashes",
            "secretMarkerFindings"
        )
    },
    [ordered]@{
        id = "node-operator-package-verify"
        requirement = "Node operator package verifier independently checks generated package files, command matrix, owner-input name-only boundary, owner go-live expected evidence reports, forbidden local files, and no-secret scan."
        path = "docs/agent-runs/live-product-infra-rpc/operator-package-verify-report.json"
        command = "npm run flowchain:operator:package:verify"
        productionGate = $true
        ownerInputGate = $false
        requiredMinimums = [ordered]@{
            goLiveExpectedPackageEvidenceCount = 30
        }
        requiredChecks = @(
            "packageReportExists",
            "packageReportPassed",
            "packageDirExists",
            "manifestExists",
            "manifestSchemaValid",
            "commandMatrixExists",
            "commandMatrixCountMatches",
            "expectedFilesPresent",
            "manifestRunbookHashesPresent",
            "manifestEvidenceHashesPresent",
            "manifestDestinationHashesMatch",
            "reportRunbookCountEnough",
            "reportEvidenceCountEnough",
            "goLiveHandoffEvidencePresent",
            "goLiveExpectedEvidencePathsPresent",
            "goLiveExpectedEvidenceInManifest",
            "ownerInputNamesOnly",
            "noForbiddenLocalFiles",
            "noSecretScanPassed",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "broadcastsFalse",
            "noSecrets"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "hashProblems",
            "missingGoLivePackageEvidence",
            "goLivePackageEvidenceNotInManifest",
            "secretMarkerFindings"
        )
    },
    [ordered]@{
        id = "second-computer-readiness"
        requirement = "Second-computer readiness creates a no-secret offline source bundle, verifies local dependency prerequisites, documents the bundle/verify commands, and keeps the bundle under ignored local output."
        path = "docs/agent-runs/live-product-infra-rpc/second-computer-readiness-report.json"
        command = "npm run flowchain:second-computer:readiness"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "bundlePackageScriptPresent",
            "verifyPackageScriptPresent",
            "readinessPackageScriptPresent",
            "setupDocExists",
            "setupDocMentionsBundle",
            "setupDocMentionsVerify",
            "bundleCommandPassed",
            "verifyCommandPassed",
            "bundleReportPassed",
            "verifyReportPassed",
            "stageNoSecretScanPassed",
            "bundleZipCreated",
            "bundleSha256Present",
            "manifestWritten",
            "manifestNextCommandsPresent",
            "excludesGitMetadata",
            "excludesNodeModules",
            "excludesLocalRuntime",
            "excludesEnvFiles",
            "excludesSecretMarkerFiles",
            "verifyChecksPassed",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingNextCommands",
            "failedVerifyChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "developer-dev-pack"
        requirement = "Developer SDK/devkit proof connects to the real RPC, proves Node and Python SDKs, CLI examples, signed-envelope submission, packaged Vite/React browser starter build/smoke, generated OpenAPI/Postman/cURL docs, runtime-backed local wallet sends, and public readiness fail-closed behavior."
        path = "docs/agent-runs/live-product-dev-pack/dev-pack-e2e-report.json"
        command = "npm run flowchain:dev-pack:e2e"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "discoveryLoaded",
            "readinessLoaded",
            "healthReadable",
            "nodeStatusReadable",
            "blockListReadable",
            "blockGetReadable",
            "transactionListReadable",
            "transactionGetReadable",
            "mempoolReadable",
            "accountListReadable",
            "balanceReadable",
            "walletMetadataReadable",
            "walletTransfersReadable",
            "walletBalancesReadable",
            "faucetEventsReadable",
            "finalityReadable",
            "bridgeLifecycleReadable",
            "walletSendRuntimeBacked",
            "waitTransactionSdkIncluded",
            "cliJsonStatus",
            "cliJsonBlocks",
            "cliJsonWaitTransaction",
            "nodeExamplePassed",
            "signedEnvelopeExamplePassed",
            "cliSignedEnvelopePrepared",
            "cliSignedTransactionSubmit",
            "browserExamplePresent",
            "browserExampleViteReactPackaged",
            "browserExampleBuildPassed",
            "browserExampleSmokePassed",
            "openApiSpecGenerated",
            "postmanCollectionGenerated",
            "curlExamplesGenerated",
            "developerGuidesPresent",
            "pythonSdkE2ePassed",
            "pythonSdkDiscoveryLoaded",
            "pythonSdkReadinessLoaded",
            "pythonDevkitJsonStatus",
            "pythonDevkitJsonBlocks",
            "pythonDevkitWaitTransaction",
            "pythonSdkDocsPresent",
            "pythonSdkSafeDiagnostics",
            "heightAdvanced",
            "publicReadinessFailClosed",
            "publicWriteMethodsBlockedFromPublicList",
            "broadLocalStateBlockedFromPublicList",
            "inventoryGenerated",
            "inventorySafe"
        )
        requiredMinimums = [ordered]@{
            "methodCount" = 20
        }
        requiredEmptyArrays = @("failedChecks")
        requiredReportProperties = [ordered]@{
            "publicReadyMethodCount" = 0
            "noLiveBroadcast" = $true
            "broadcasts" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
        }
    },
    [ordered]@{
        id = "backup-readiness"
        requirement = "Configured production backup path can create and restore manifest-backed state snapshots."
        path = "docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json"
        command = "npm run flowchain:backup:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "backup-restore-validation"
        requirement = "Local backup/restore rehearsal restores the latest snapshot safely and rejects corrupt, tampered, missing-artifact, stale-pointer, and wrong-chain evidence."
        path = "docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json"
        command = "npm run flowchain:backup:restore:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "backupCommandPassed",
            "restoreCommandPassed",
            "backupRestoreHashRoundTrip",
            "secondBackupCommandPassed",
            "latestManifestMatchesSecondSnapshot",
            "latestRestoreCommandPassed",
            "latestRestoreUsedLatestSnapshot",
            "restoreTargetsLiveStateProtected",
            "liveStateNonMutationProven",
            "corruptedSnapshotDetected",
            "manifestTamperDetected",
            "missingStateArtifactDetected",
            "missingSnapshotManifestDetected",
            "latestPointerTamperDetected",
            "wrongChainStateMismatchDetected",
            "valuesPrintedFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "valuesPrinted" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "backup-owner-path-dry-run"
        requirement = "Backup owner-path dry run injects an ignored local backup path into the production backup readiness gate and proves snapshot plus restore evidence without using the owner's real directory."
        path = "docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json"
        command = "npm run flowchain:backup:owner-path:dry-run"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "childReadinessCommandPassed",
            "readinessStatusPassed",
            "snapshotProofPassed",
            "restoreProofPassed",
            "writeVerified",
            "latestPointerVerified",
            "latestPointerWrittenAtomically",
            "restoreLiveStateProtected",
            "restoreDidNotMutateLiveState",
            "ownerBackupEnvRestored",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "backup-install-validation"
        requirement = "Backup scheduler validation proves no-secret Windows Scheduled Task and Linux systemd timer plan paths for recurring state snapshots and restore drills without host mutation."
        path = "docs/agent-runs/live-product-infra-rpc/backup-install-validation-report.json"
        command = "npm run flowchain:backup:install:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "installScriptExists",
            "systemdInstallScriptExists",
            "systemdValidationScriptExists",
            "backupScriptExists",
            "restoreDrillScriptExists",
            "packageScriptsPresent",
            "planCommandPassed",
            "planDidNotMutate",
            "schedulerCmdletsAvailable",
            "scheduledTaskActionSupportsWorkingDirectory",
            "taskNamesDistinct",
            "retentionCountValid",
            "actionUsesBackupScript",
            "actionUsesRetentionCount",
            "restoreDrillUsesRestoreScript",
            "restoreDrillHasRestoreRoot",
            "restoreDrillHasStatePath",
            "restoreDrillHasReportPath",
            "ownerBackupEnvRequired",
            "restoreDrillOwnerBackupEnvRequired",
            "commandOmitsAllowBlocked",
            "commandsPresent",
            "systemdValidationCommandPassed",
            "systemdValidationPassed",
            "systemdFailedChecksEmpty",
            "systemdPlanDidNotMutate",
            "systemdBackupServiceUnitPlanned",
            "systemdBackupTimerUnitPlanned",
            "systemdRestoreServiceUnitPlanned",
            "systemdRestoreTimerUnitPlanned",
            "systemdCommandOmitsAllowBlocked",
            "systemdOwnerBackupEnvRequired",
            "systemdOwnerEnvInjectable",
            "systemdServicesHardeningPresent",
            "systemdBackupRootWritePathConfigurable",
            "systemdChildReportNoSecrets",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingPackageScripts"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "bridge-live-readiness"
        requirement = "Base 8453 live bridge pilot has required owner inputs, caps, confirmations, and operator acknowledgement."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json"
        command = "npm run flowchain:bridge:live:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "bridge-infra-readiness"
        requirement = "Bridge infrastructure readiness is safe for external funded testing."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json"
        command = "npm run flowchain:bridge:infra:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "bridge-command-matrix"
        requirement = "Bridge pilot command matrix maps deploy, observe, relayer, credit, withdrawal/release, emergency-control, smoke, and release commands to owner env names, broadcast acknowledgement gates, risk class, and evidence paths without owner-value leakage."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-command-matrix-report.json"
        command = "npm run flowchain:bridge:command-matrix"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "allRequiredScriptsPresent",
            "phaseCoverageComplete",
            "deployObserveRelayerControlReleaseCovered",
            "liveBroadcastCommandsAckGated",
            "observeCommandOperatorAckGated",
            "relayerOnceOperatorAckGated",
            "controlCommandsBroadcastAckGated",
            "deployCommandBroadcastAckGated",
            "requiredEnvReferencesPresent",
            "requiredAckReferencesPresent",
            "validationSignalsPresent",
            "commandsAvoidInlineEnvAssignment",
            "commandsAvoidUrls",
            "commandsAvoidKeyMaterial",
            "ownerInputNamesOnly",
            "committedEvidencePathsCovered",
            "envValuesPrintedFalse",
            "broadcastsFalse",
            "noSecrets"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingScripts",
            "missingPhases",
            "liveBroadcastRowsWithoutAck",
            "badOwnerInputRows"
        )
        requiredMinimums = [ordered]@{
            commandCount = 18
            liveBroadcastCapableCommandCount = 4
            committedEvidencePathCount = 10
        }
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "bridge-no-secret-audit"
        requirement = "Bridge generated pilot evidence has committed JSON and Markdown no-secret proof before owner-funded bridge activation."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-no-secret-audit-report.json"
        command = "npm run flowchain:bridge:no-secret-audit"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "scannedPathsPresent",
            "scannedFileCountPositive",
            "findingsEmpty",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings",
            "findings"
        )
        requiredMinimums = [ordered]@{
            scannedFileCount = 1
        }
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "base-tx-diagnostic-fail-closed"
        requirement = "Base 8453 transaction diagnosis fails closed without owner env/tx inputs, prints no env values, writes no secrets, and never broadcasts."
        path = "devnet/local/live-l1-bridge-e2e/base-tx-diagnostic.json"
        command = "npm run flowchain:bridge:diagnose:tx"
        productionGate = $true
        ownerInputGate = $false
        blockedAsPassed = $true
        requiredReportProperties = [ordered]@{
            "safeReasonCode" = "missing-env"
            "broadcasts" = $false
            "printsEnvValues" = $false
            "noSecrets" = $true
        }
    },
    [ordered]@{
        id = "bridge-deploy-control-validation"
        requirement = "Base 8453 bridge deploy, pause, resume, and emergency-stop paths fail closed without owner env, require explicit pilot and broadcast acknowledgements, map capped pilot deployment env into Foundry, and remain no-broadcast during validation."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-deploy-control-validation-report.json"
        command = "npm run flowchain:bridge:deploy:control:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptDeployPresent",
            "packageScriptPausePresent",
            "packageScriptResumePresent",
            "packageScriptEmergencyStopPresent",
            "packageScriptValidationPresent",
            "deployScriptExists",
            "controlScriptExists",
            "foundryScriptExists",
            "lockboxContractExists",
            "deploymentRunbookExists",
            "deployMissingEnvCommandFailedClosed",
            "deployMissingEnvReportWritten",
            "deployMissingEnvReportBlockedNoBroadcast",
            "pauseMissingEnvCommandFailedClosed",
            "pauseMissingEnvReportBlockedNoBroadcast",
            "resumeMissingEnvCommandFailedClosed",
            "resumeMissingEnvReportBlockedNoBroadcast",
            "emergencyStopMissingEnvCommandFailedClosed",
            "emergencyStopMissingEnvReportBlockedNoBroadcast",
            "deployRequiresBase8453ChainId",
            "deployRequiresPilotAck",
            "deployRequiresBroadcastAck",
            "deployRequiresAcknowledgeBroadcastSwitch",
            "deployMapsFoundryPilotAck",
            "deployMapsNativeAndErc20Caps",
            "deployDryRunNoBroadcastStatus",
            "deployBroadcastUsesForgeBroadcast",
            "controlExecuteRequiresOwnerKeyAndBroadcastAck",
            "controlNoExecuteReportsReadyNoBroadcast",
            "controlSupportsPauseResumeEmergency",
            "controlExecuteUsesCastSend",
            "foundryScriptGatesBase8453",
            "foundryScriptRequiresTotalCapOnBase",
            "foundryScriptDeploysLockboxAndSpine",
            "lockboxHasNonReentrantPauseEmergency",
            "lockboxHasCapsAndReplayProtection",
            "lockboxRejectsPlaceholderRecipient",
            "lockboxHasReleaseAuthority",
            "runbookHasDryRunBroadcastVerifyRollback",
            "childProcessesDidNotTimeout",
            "validationArtifactsInsideRepo",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "bridge-relayer-guardrail-validation"
        requirement = "Bridge relayer missing-owner-input runs fail closed without mutating final cursor state, staging cursor state, queueing credits, printing env values, or broadcasting."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json"
        command = "npm run flowchain:bridge:relayer:guardrail:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "relayerCommandExitedZeroWithAllowBlocked",
            "relayerReportWritten",
            "relayerStatusBlocked",
            "relayerChildTimeoutRecorded",
            "relayerNoChildTimeouts",
            "blockedBeforeLiveReadiness",
            "externalOwnerIssueRecorded",
            "finalCursorUnchanged",
            "stagedCursorNotWritten",
            "finalCursorNotCommitted",
            "noCreditsObserved",
            "noCreditsQueued",
            "noCreditsApplied",
            "ownerEnvNotImported",
            "broadcastsFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "bridge-relayer-loop-validation"
        requirement = "Bridge relayer loop validation proves the live service can start an isolated relayer loop, report fresh blocked-only-on-owner-input loop health, then stop it cleanly without stale PID files or leftover relayer processes."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json"
        command = "npm run flowchain:bridge:relayer:loop:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "startCommandPassed",
            "startReportWritten",
            "liveProfile",
            "relayerLoopRequested",
            "relayerLoopStartedOrRunning",
            "relayerPidRecorded",
            "relayerPollSecondsRecorded",
            "relayerQueuesRuntimeHandoffs",
            "statusCommandPassed",
            "statusReportsRelayerRunning",
            "statusRelayerCommandLineMatched",
            "statusRelayerReportFresh",
            "statusRelayerReportAcceptable",
            "statusRelayerReportBlockedOnlyOnOwnerInputs",
            "statusRelayerReportNoSecrets",
            "statusRelayerReportNoBroadcasts",
            "statusRelayerReportHealthy",
            "stopCommandPassed",
            "stopPreservedState",
            "stopHandledRelayerLoop",
            "statusAfterStopCommandPassed",
            "statusAfterStopNotRunning",
            "relayerPidNoLongerMatchesAfterStop",
            "relayerPidFileRemovedAfterStop",
            "stopReportRelayerPidFileRemoved",
            "noValidationRelayerProcessAfterStop",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "bridge-runtime-credit-validation"
        requirement = "Bridge runtime credit validation proves a production-shaped Base 8453 handoff can be queued into an isolated L1, become spendable within the settlement target, reject replay, spend from the credited wallet, and survive restart/export/import without secrets or broadcasts."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json"
        command = "npm run flowchain:bridge:runtime-credit:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "childCommandPassed",
            "childDidNotTimeout",
            "proofReportWritten",
            "proofClassificationReady",
            "proofFailedChecksEmpty",
            "requiredRuntimeChecksCovered",
            "requiredRuntimeChecksPassed",
            "sourceChainBase8453",
            "creditAppliedOnce",
            "creditedBalanceTransferable",
            "replayRejected",
            "restartPreservesCreditHistory",
            "exportImportPreservesReplayProtection",
            "latencyRecorded",
            "latencyGatePassed",
            "transferLatencyUnderTarget",
            "proofBroadcastsFalse",
            "proofEnvValuesPrintedFalse",
            "proofNoSecrets",
            "handoffReportReadable",
            "handoffNoReleaseBroadcast",
            "handoffNoWithdrawalBroadcast",
            "secretMarkerFindingsEmpty",
            "broadcastsFalse",
            "envValuesPrintedFalse",
            "noSecrets"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingRuntimeChecks",
            "falseRuntimeChecks",
            "proofFailedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "real-value-pilot-aggregate"
        requirement = "Real-value pilot aggregate coordinates contracts, bridge, runtime, wallet, control-dashboard, and ops proofs under bounded child timeouts before a funded owner pilot can be treated as complete."
        path = "docs/agent-runs/live-product-infra-rpc/real-value-pilot-aggregate-report.json"
        command = "npm run flowchain:real-value-pilot:e2e -- -SkipBaseline -ChildTimeoutSeconds 1800 -ReportPath docs/agent-runs/live-product-infra-rpc/real-value-pilot-aggregate-report.json"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "pilotSpecPresent",
            "baselineScriptsPresent",
            "requiredProofScriptsPresent",
            "requiredProofCommandsRun",
            "childTimeoutSecondsPositive",
            "commandsDidNotTimeout",
            "commandsDidNotFail",
            "missingProofsEmpty",
            "ownerGoNoGoTrue",
            "outputTailsRedacted",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredMinimums = [ordered]@{
            "childTimeoutSeconds" = 1
        }
        requiredEmptyArrays = @(
            "missingProofs",
            "missingExpectedCommands",
            "timedOutCommands",
            "failedCommands"
        )
        requiredReportProperties = [ordered]@{
            "skipBaseline" = $true
            "ownerGoNoGo.go" = $true
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "bridge-reconciliation"
        requirement = "Bridge reconciliation summarizes live relayer observed/new/queued/applied/pending credits, cursor commit safety, local runtime credit proof, replay rejection, and release evidence validation in one no-secret operator report."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-report.json"
        command = "npm run flowchain:bridge:reconciliation"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "relayerOnceReportLoaded",
            "relayerOnceStatusBlockedOrPassed",
            "relayerOnceNoFailedChecks",
            "relayerOnceNoSecrets",
            "relayerOnceNoBroadcasts",
            "relayerCountsNonNegative",
            "pendingCreditsNonNegative",
            "cursorModeStaged",
            "cursorFinalNotCommittedWhenBlocked",
            "relayerBlockedClassifiedOwnerInput",
            "guardrailReportPassed",
            "guardrailNoFailedChecks",
            "guardrailCursorSafe",
            "loopValidationPassedOrOwnerBlocked",
            "runtimeCreditPassed",
            "runtimeCreditNoFailedChecks",
            "runtimeCreditAppliedOnce",
            "runtimeReplayRejected",
            "localPilotPassed",
            "localPilotNoFailedChecks",
            "localPilotExactValueConserved",
            "localPilotDuplicateReplayRejected",
            "releaseEvidenceValidationPassed",
            "releaseEvidenceNoFailedChecks",
            "reconciliationRowsPresent",
            "liveReadinessBlockedOrPassed",
            "bridgeInfraBlockedOrPassed",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredMinimums = [ordered]@{
            "counts.localRuntimeAppliedProofs" = 1
            "counts.duplicateReplayRejectedProofs" = 1
            "counts.releaseEvidenceValidationProofs" = 1
        }
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "bridge-reconciliation-schedule-validation"
        requirement = "Bridge reconciliation schedule validation renders no-secret Windows Scheduled Task and Linux systemd timer plans for recurring bridge reconciliation checks without host mutation or external delivery."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-schedule-validation-report.json"
        command = "npm run flowchain:bridge:reconciliation:schedule:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptPresent",
            "reconciliationPackageScriptPresent",
            "reconciliationScriptExists",
            "reconciliationScriptReadsRelayerEvidence",
            "reconciliationScriptReadsRuntimeEvidence",
            "scheduledReportPathInsideRepo",
            "scheduledMarkdownPathInsideRepo",
            "windowsPlanUsesReconciliationScript",
            "windowsPlanUsesOwnerEnvFile",
            "windowsPlanHasReportPath",
            "windowsPlanHasMarkdownPath",
            "windowsPlanUsesRepoWorkingDirectory",
            "windowsPlanDoesNotMutateHost",
            "systemdServiceRendered",
            "systemdServiceUsesOneshot",
            "systemdServiceUsesOwnerEnvFile",
            "systemdServiceHasReportPath",
            "systemdServiceHasMarkdownPath",
            "systemdServiceHardeningPresent",
            "systemdServiceWritePathsScoped",
            "systemdTimerRendered",
            "systemdTimerPersistent",
            "systemdTimerIntervalConfigured",
            "noExternalDelivery",
            "hostMutationPerformedFalse",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "hostMutationPerformed" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "external-tester-readiness"
        requirement = "External tester flow remains blocked until public RPC, backup, bridge, and local tester evidence pass."
        path = "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
        command = "npm run flowchain:tester:readiness -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
        staleIfOlderThan = @("public-tester-gateway-e2e")
    },
    [ordered]@{
        id = "bridge-release-evidence-validation"
        requirement = "Bridge withdrawal/release evidence validation proves matching release evidence passes, missing inputs block, method/amount/token/recipient/chain/asset mismatches fail, broadcast and production boundary flags are rejected, and validation remains no-secret/no-broadcast."
        path = "docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json"
        command = "npm run flowchain:bridge:release:evidence:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "releaseEvidenceScriptExists",
            "matchingEvidencePasses",
            "missingInputsBlock",
            "amountMismatchFails",
            "methodMismatchFails",
            "tokenMismatchFails",
            "recipientMismatchFails",
            "chainMismatchFails",
            "assetMismatchFails",
            "releaseBroadcastRejected",
            "withdrawalBroadcastRejected",
            "releaseProductionReadyFalseRejected",
            "releaseLocalOnlyTrueRejected",
            "allRequiredCasesCovered",
            "failedCasesAbsent",
            "noSecretScanPassed",
            "broadcastsFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "failedCases",
            "missingRequiredCases",
            "secretMarkerFindings"
        )
        requiredMinimums = [ordered]@{
            caseCount = 12
        }
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "external-tester-packet"
        requirement = "Friends-and-family tester packet is shareable only after all public gates pass."
        path = "docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json"
        command = "npm run flowchain:external-tester:packet -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "external-tester-packet-validation"
        requirement = "Friends-and-family tester packet validation proves the packet and connect pack are no-secret, executable through local tester smoke, and fail closed until owner public inputs exist."
        path = "docs/agent-runs/live-product-infra-rpc/external-tester-packet-validation-report.json"
        command = "npm run flowchain:external-tester:packet:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptPacketPresent",
            "packageScriptValidationPresent",
            "packetScriptExists",
            "readinessScriptExists",
            "testerNetworkReportExists",
            "publicTesterGatewayReportExists",
            "packetCommandAllowsBlocked",
            "packetReportWritten",
            "packetMarkdownWritten",
            "connectPackWritten",
            "packetStatusBlockedUntilOwnerInputs",
            "packetShareableFalseWithoutOwnerInputs",
            "connectPackShareableFalseWithoutOwnerInputs",
            "externalSharingReadyFalse",
            "localTesterRehearsalReady",
            "packetExecutableSmokeValidated",
            "testerNetworkReportPassed",
            "publicTesterGatewayReportPassed",
            "publicTesterGatewayRoutesCovered",
            "publicTesterGatewayCapRejected",
            "packetSmokeChecksAllTrue",
            "packetSmokeRoutesCoverReadOnly",
            "packetSmokeRoutesCoverTesterWrites",
            "connectPackChecksAllTrue",
            "connectPackSchemaValid",
            "connectPackStatusMatchesReport",
            "connectPackShareableMatchesReport",
            "connectPackHasChainId",
            "connectPackHasEndpointPlaceholders",
            "connectPackHasNoConcreteUrl",
            "connectPackReadOnlyRoutesCovered",
            "connectPackTesterWriteRoutesCovered",
            "packetMarkdownWarnsNotShareable",
            "packetMarkdownHasConnectionProfile",
            "packetMarkdownHasEndpointChecks",
            "packetMarkdownHasWalletFlow",
            "packetMarkdownListsOwnerCommands",
            "requiredOwnerEnvNamesListed",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty",
            "packetReportInsideRepo",
            "connectPackInsideRepo",
            "packetMarkdownInsideRepo"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
            "packetShareable" = $false
            "connectPackShareable" = $false
            "externalSharingReady" = $false
            "packetExecutableSmokeValidated" = $true
        }
        staleIfOlderThan = @("public-tester-gateway-e2e")
    },
    [ordered]@{
        id = "external-tester-client-validation"
        requirement = "Standalone friends-and-family tester client validates the generated connect pack in a no-network dry run covering read routes, wallet create, faucet, send, redaction, no-token storage, no secrets, and no broadcasts."
        path = "docs/agent-runs/live-product-infra-rpc/external-tester-client-validation-report.json"
        command = "npm run flowchain:external-tester:client:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "clientScriptExists",
            "connectPackExists",
            "connectPackSchemaValid",
            "clientExitCodeZero",
            "dryRunReportWritten",
            "dryRunSchemaValid",
            "dryRunStatusPlanned",
            "dryRunNoNetwork",
            "blockedConnectPackAllowedOnlyByFlag",
            "plannedRoutesCoverReads",
            "plannedRoutesCoverWrites",
            "endpointRedacted",
            "tokenNotConfiguredInDryRun",
            "broadcastsFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
        staleIfOlderThan = @("external-tester-packet")
    },
    [ordered]@{
        id = "external-tester-evidence-validation"
        requirement = "External tester evidence validation proves redacted friends-and-family evidence contains required files, advancing block height, matching wallet transfer and balances, amount caps, and no-secret boundaries."
        path = "docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json"
        command = "npm run flowchain:tester:evidence:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptPresent",
            "guideExists",
            "guideListsSuggestedFiles",
            "guideHasOwnerReviewChecklist",
            "guideHasStopRules",
            "evidenceDirInsideRepo",
            "evidenceDirExists",
            "requiredFilesPresent",
            "requiredJsonValid",
            "notesPresent",
            "readinessPassed",
            "diagnosticsPassed",
            "diagnosticsNoSecrets",
            "heightsNumeric",
            "blockHeightAdvanced",
            "sendAccepted",
            "transferIdPresent",
            "transactionIdPresent",
            "transferFound",
            "transferMatchesAccounts",
            "transferAmountMatches",
            "transactionIdMatches",
            "transferBlockHeightInWindow",
            "includedHeightMatchesTransfer",
            "amountWithinLimit",
            "balancesPresent",
            "senderDebited",
            "recipientCredited",
            "secretMarkerFindingsEmpty",
            "credentialUrlFindingsEmpty",
            "envAssignmentFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingRequiredFiles",
            "invalidJsonFiles",
            "secretMarkerFindings",
            "credentialUrlFindings",
            "envAssignmentFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "dashboard-ui-readiness"
        requirement = "Dashboard browser readiness proves desktop and mobile users can create a tester wallet, request faucet funds, send tester units, inspect the result in Explorer, review tester launch readiness, review the L1 activation cockpit, review bridge/runtime proof surfaces, and avoid token/secret leakage or horizontal overflow."
        path = "docs/agent-runs/live-product-infra-rpc/dashboard-ui-readiness-report.json"
        command = "npm run flowchain:dashboard:ui:readiness"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "dashboardPackageScriptPresent",
            "rootPackageScriptPresent",
            "playwrightConfigExists",
            "browserSpecExists",
            "desktopProjectConfigured",
            "mobileProjectConfigured",
            "walletTesterRouteCovered",
            "testerWalletCreateCovered",
            "testerFaucetCovered",
            "testerSendCovered",
            "explorerRouteCovered",
            "testerLaunchRouteCovered",
            "activationRouteCovered",
            "bridgeRouteCovered",
            "bridgePilotRuntimeProofCovered",
            "bridgeRuntimeCreditProofCovered",
            "realValuePilotAggregateProofCovered",
            "publicRpcHeaderProofCovered",
            "noSecretLeakageAsserted",
            "noHorizontalOverflowAsserted",
            "dashboardUnitTestsPassed",
            "dashboardBrowserE2ePassed",
            "dashboardBuildPassed",
            "controlPlaneTesterGatewayTestsPassed",
            "commandsCompletedWithoutTimeout",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "ops-snapshot"
        requirement = "Ops snapshot distinguishes critical incidents from expected owner-input blockers and gives incident commands."
        path = "docs/agent-runs/live-product-infra-rpc/ops-snapshot-report.json"
        command = "npm run flowchain:ops:snapshot -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "ops-alert-rules"
        requirement = "Ops alert rules map every current ops finding to local operator commands with no unmapped findings and no external delivery credentials."
        path = "docs/agent-runs/live-product-infra-rpc/ops-alert-rules-report.json"
        command = "npm run flowchain:ops:alerts -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $false
        requiredMinimums = [ordered]@{
            ruleCount = 10
            criticalRuleCount = 5
            blockedRuleCount = 5
        }
        requiredChecks = @(
            "opsSnapshotLoaded",
            "opsRefreshSucceeded",
            "ruleCountSufficient",
            "criticalRuleCountSufficient",
            "blockedRuleCountSufficient",
            "currentFindingsLoaded",
            "everyCurrentFindingMapped",
            "everyRuleHasCommands",
            "everyActiveRuleHasCommands",
            "commandsAvoidInlineEnvAssignment",
            "commandsAvoidUrls",
            "publicRpcEdgeHardeningRuleCoversRollbackDrill",
            "publicRpcEdgeHardeningRuleCoversOwnerHostApplyPlan",
            "backupRestoreValidationRuleCoversSafety",
            "backupOwnerPathDryRunRuleCoversOwnerPath",
            "bridgeDeployControlRuleCoversDeploymentControls",
            "bridgeNoSecretAuditRuleCoversNoSecretProof",
            "supervisorNodeRecoveryRuleCoversLiveProfile",
            "bridgeRelayerLoopRuleCoversValidationTelemetry",
            "bridgeReconciliationRuleCoversCursorAndReplay",
            "serviceInstallValidationRuleCoversAutorecoveryTelemetry",
            "devPackRuleCoversBrowserStarter",
            "secondComputerRuleCoversBundleVerifyNoSecret",
            "publicTesterGatewayRuleCoversNoSecretNoBroadcast",
            "ownerGoLiveHandoffRuleCoversReleaseReady",
            "ownerGoLiveHandoffRuleCoversLaunchAndRollback",
            "findingsWithoutCommandsEmpty",
            "notificationPlanStoresNoSecrets",
            "notificationPlanNoNetworkDelivery",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "unmappedCurrentFindingCodes",
            "rulesWithoutCommands",
            "activeRuleIdsWithoutCommands",
            "commandsWithInlineEnvAssignment",
            "commandsWithUrls",
            "findingsWithoutCommands",
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
            "notificationPlan.storesSecrets" = $false
            "notificationPlan.sendsNetworkNotifications" = $false
        }
    },
    [ordered]@{
        id = "ops-metrics-export"
        requirement = "Ops metrics export converts no-secret service, supervisor autorecovery, alert, public-readiness, bridge, tester, owner handoff, truth-table, and no-secret evidence into JSON plus Prometheus textfile metrics without network delivery or owner-value leakage."
        path = "docs/agent-runs/live-product-infra-rpc/ops-metrics-export-report.json"
        command = "npm run flowchain:ops:metrics:export"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptPresent",
            "opsSnapshotLoaded",
            "opsAlertRulesLoaded",
            "serviceStatusLoaded",
            "serviceMonitorLoaded",
            "serviceInstallValidationLoaded",
            "systemdServiceInstallValidationLoaded",
            "externalTesterEvidenceLoaded",
            "externalTesterClientValidationLoaded",
            "liveCutoverLoaded",
            "ownerGoLiveHandoffLoaded",
            "truthTableLoaded",
            "noSecretLoaded",
            "metricsJsonWritten",
            "prometheusTextWritten",
            "markdownWritten",
            "metricCountSufficient",
            "requiredMetricsPresent",
            "backupRestoreValidationLoaded",
            "backupRestoreValidationMetricsPresent",
            "backupOwnerPathDryRunLoaded",
            "backupOwnerPathDryRunMetricsPresent",
            "publicRpcRollbackDrillMetricsPresent",
            "publicRpcOwnerHostApplyPlanMetricsPresent",
            "bridgeDeployControlMetricsPresent",
            "serviceInstallValidationMetricsPresent",
            "externalTesterEvidenceMetricsPresent",
            "publicTesterGatewayMetricsPresent",
            "bridgeNoSecretAuditLoaded",
            "bridgeNoSecretAuditMetricsPresent",
            "bridgeRelayerLoopValidationMetricsPresent",
            "bridgeReconciliationLoaded",
            "bridgeReconciliationMetricsPresent",
            "bridgeReleaseEvidenceMetricsPresent",
            "externalTesterClientMetricsPresent",
            "secondComputerLoaded",
            "secondComputerMetricsPresent",
            "devPackLoaded",
            "devPackMetricsPresent",
            "ownerGoLiveHandoffMetricsPresent",
            "supervisorNodeRecoveryMetricsPresent",
            "prometheusHasHelpAndType",
            "prometheusContainsNoUrls",
            "prometheusContainsNoEnvAssignments",
            "metricsJsonNoSecrets",
            "metricsJsonSecretMarkerFindingsEmpty",
            "metricsJsonEnvValuesPrintedFalse",
            "metricsJsonBroadcastsFalse",
            "envValuesPrintedFalse",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingMetricNames",
            "secretMarkerFindings"
        )
        requiredMinimums = [ordered]@{
            metricCount = 35
        }
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "ops-monitoring-bundle"
        requirement = "Ops monitoring bundle renders no-secret Grafana dashboard and Prometheus alert-rule artifacts from current FlowChain metrics and alert-rule evidence, covering block production, service health, public RPC, backup, bridge relayer, external testers, truth table, and no-secret boundaries without external delivery credentials."
        path = "docs/agent-runs/live-product-infra-rpc/monitoring-bundle-report.json"
        command = "npm run flowchain:ops:monitoring:bundle"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptPresent",
            "metricsJsonLoaded",
            "metricsExportReportLoaded",
            "alertRulesLoaded",
            "sourceMetricsSufficient",
            "sourceAlertRulesSufficient",
            "dashboardWritten",
            "dashboardJsonValid",
            "dashboardPanelCountSufficient",
            "dashboardTargetsHaveKnownMetrics",
            "dashboardIncludesCorePanels",
            "prometheusRulesWritten",
            "prometheusYamlHasRules",
            "prometheusRuleCountSufficient",
            "prometheusRulesReferenceKnownMetrics",
            "prometheusRulesReferenceKnownAlertRuleIds",
            "prometheusRulesHaveRunbookCommands",
            "prometheusCommandsAvoidInlineEnvAssignment",
            "prometheusCommandsAvoidUrls",
            "readmeWritten",
            "manifestWritten",
            "artifactHashesPresent",
            "filesNoSecretMarkers",
            "noNetworkDelivery",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingDashboardMetricNames",
            "missingPrometheusMetricNames",
            "missingSourceRuleIds",
            "missingPanelTitles",
            "rulesWithoutCommands",
            "commandsWithInlineEnvAssignment",
            "commandsWithUrls",
            "artifactHashGaps",
            "secretMarkerFindings"
        )
        requiredMinimums = [ordered]@{
            sourceMetricCount = 50
            sourceAlertRuleCount = 10
            dashboardPanelCount = 12
            prometheusRuleCount = 8
        }
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
            "notificationPlan.storesSecrets" = $false
            "notificationPlan.sendsNetworkNotifications" = $false
        }
    },
    [ordered]@{
        id = "ops-metrics-install-validation"
        requirement = "Scheduled metrics export install validation proves Windows Scheduled Task and Linux systemd timer plan/status/uninstall boundaries and no external delivery for recurring JSON and Prometheus textfile metrics."
        path = "docs/agent-runs/live-product-infra-rpc/metrics-install-validation-report.json"
        command = "npm run flowchain:ops:metrics:install:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptsPresent",
            "planDidNotMutate",
            "statusDidNotMutate",
            "statusTaskStatePreserved",
            "uninstallAbsentCommandPassed",
            "uninstallAbsentDidNotMutate",
            "uninstallAbsentTaskAbsentAfter",
            "scheduledTaskTriggerSupportsRepetition",
            "actionUsesMetricsScript",
            "hasAllowBlocked",
            "hasMetricsJsonPath",
            "hasPrometheusTextPath",
            "scheduledCommandDoesNotDisableRefresh",
            "systemdValidationCommandPassed",
            "systemdValidationPassed",
            "systemdPlanDidNotMutate",
            "systemdServiceUnitPlanned",
            "systemdTimerUnitPlanned",
            "systemdTimerIntervalConfigured",
            "systemdOwnerEnvFileInjectable",
            "systemdNoExternalDelivery",
            "systemdChildReportNoSecrets",
            "noExternalDelivery",
            "childReportsNoSecrets",
            "childReportsSecretMarkerFindingsEmpty",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingPackageScripts",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "ops-alert-install-validation"
        requirement = "Scheduled alert refresh install validation proves plan/status/uninstall no-op behavior and no external delivery."
        path = "docs/agent-runs/live-product-infra-rpc/alert-install-validation-report.json"
        command = "npm run flowchain:ops:alerts:install:validate"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptsPresent",
            "planDidNotMutate",
            "statusDidNotMutate",
            "statusTaskStatePreserved",
            "uninstallAbsentCommandPassed",
            "uninstallAbsentDidNotMutate",
            "uninstallAbsentTaskAbsentAfter",
            "scheduledTaskTriggerSupportsRepetition",
            "actionUsesAlertsScript",
            "hasAllowBlocked",
            "scheduledCommandDoesNotDisableRefresh",
            "systemdValidationCommandPassed",
            "systemdValidationPassed",
            "systemdPlanDidNotMutate",
            "systemdServiceUnitPlanned",
            "systemdTimerUnitPlanned",
            "systemdTimerIntervalConfigured",
            "systemdOwnerEnvFileInjectable",
            "systemdNoExternalDelivery",
            "systemdChildReportNoSecrets",
            "noExternalDelivery",
            "childReportsNoSecrets",
            "childReportsSecretMarkerFindingsEmpty",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "ops-escalation-dry-run"
        requirement = "Ops escalation dry run maps current findings to local operator actions and proves no network delivery or credential storage."
        path = "docs/agent-runs/live-product-infra-rpc/ops-escalation-dry-run-report.json"
        command = "npm run flowchain:ops:escalation:dry-run -- -NoRefresh"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "opsSnapshotLoaded",
            "opsAlertRulesLoaded",
            "opsSnapshotStatusSafe",
            "opsAlertRulesPassed",
            "notificationPlanNoNetworkDelivery",
            "notificationPlanStoresNoSecrets",
            "notificationPlanOutOfRepo",
            "activeRulesExistInManifest",
            "activeRulesHaveCommands",
            "everyCurrentFindingMapped",
            "everyCurrentFindingHasCommands",
            "noCommandUrls",
            "noInlineEnvAssignments",
            "dryRunEventsDoNotSend",
            "dryRunEventsStoreNoCredentials",
            "envValuesPrintedFalse",
            "sourceReportsSecretMarkerFindingsEmpty",
            "secretMarkerFindingsEmpty",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "activeRuleIdsMissingFromManifest",
            "activeRuleIdsWithoutCommands",
            "commandsWithInlineEnvAssignment",
            "commandsWithUrls",
            "findingsWithoutCommands",
            "unmappedFindingCodes",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    },
    [ordered]@{
        id = "incident-drill"
        requirement = "Incident drills prove operational failures become critical incidents while owner-input blockers remain non-critical."
        path = "docs/agent-runs/live-product-infra-rpc/incident-drill-report.json"
        command = "npm run flowchain:ops:incident-drill"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "incidentDrillReady",
            "ownerValuesRequiredFalse",
            "mutatesLiveStateFalse",
            "syntheticIncidentInputs",
            "allRequiredScenariosCovered",
            "allCasesPassed",
            "failedCasesAbsent",
            "minimumCaseCountMet",
            "publicTesterGatewayIncidentCovered",
            "recoveryCommandPrinted",
            "postDrillLiveStatusPassed",
            "liveStateBeforeReadable",
            "liveStateAfterReadable",
            "liveBlockHeightAdvancedOrEqual",
            "noLiveBroadcast",
            "broadcastsFalse",
            "envValuesPrintedFalse",
            "noSecrets",
            "secretMarkerFindingsEmpty"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings",
            "missingRequiredScenarios"
        )
        requiredReportProperties = [ordered]@{
            "incidentDrillReady" = $true
            "ownerValuesRequired" = $false
            "mutatesLiveState" = $false
            "syntheticIncidentInputs" = $true
            "noLiveBroadcast" = $true
            "broadcasts" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
        }
    },
    [ordered]@{
        id = "public-deployment-contract"
        requirement = "Public deployment contract is ready before endpoint exposure or tester packet sharing."
        path = "docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json"
        command = "npm run flowchain:public-deployment:contract -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "live-cutover-rehearsal"
        requirement = "Live cutover rehearsal runs owner-env, public deployment, local tester wallet network, tester write-token setup, tester packet, packet validation, external tester client validation, completion, truth table, and no-secret gates through one redacted command and blocks only on known owner inputs before external sharing."
        path = "docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json"
        command = "npm run flowchain:live:cutover:rehearsal -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
        requiredChecks = @(
            "ownerEnvFilePathSafe",
            "ownerEnvFileExists",
            "ownerEnvFileIsFile",
            "ownerEnvFileGitIgnored",
            "stepsRan",
            "stepCommandsSucceeded",
            "noFailedSteps",
            "missingEnvNamesEmpty",
            "invalidEnvNamesEmpty",
            "unknownMissingEnvNamesEmpty",
            "ownerEnvReady",
            "publicDeploymentReady",
            "testerNetworkE2ePassed",
            "testerWriteTokenSetupPassed",
            "testerPacketShareable",
            "testerPacketValidationPassed",
            "testerClientValidationPassed",
            "completionReady",
            "truthTableCompleted",
            "noSecretScanPassed",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "invalidEnvNames",
            "unknownMissingEnvNames"
        )
        requiredReportProperties = [ordered]@{
            "blockedOnlyOnKnownExternalOwnerInputs" = $false
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
        staleIfOlderThan = @("owner-env-readiness", "public-deployment-contract", "tester-network-e2e", "tester-write-token-setup", "external-tester-packet", "external-tester-packet-validation", "external-tester-client-validation", "public-rpc-command-matrix", "completion-audit")
    },
    [ordered]@{
        id = "live-chain-capability-matrix"
        requirement = "User-facing live-chain capability matrix maps wallet creation, wallet-to-wallet transfer, public RPC connection, real-value bridge pilot, RPC services, block production, Explorer/faucet/wallet UI, backup, observability, external tester launch, developer tooling, and owner go-live controls to concrete evidence and remaining owner-input blockers."
        path = "docs/agent-runs/live-product-infra-rpc/live-chain-capability-matrix-report.json"
        command = "npm run flowchain:live:capabilities"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageScriptPresent",
            "requiredReportsLoaded",
            "capabilityCountMinimumMet",
            "userRequirementCoverageComplete",
            "publicLaunchCriticalCapabilitiesCovered",
            "allCriticalCapabilitiesEitherPassedOrOwnerBlocked",
            "repoBlockedCapabilitiesEmpty",
            "blockedCapabilitiesHaveBlockers",
            "blockedCapabilitiesUseKnownOwnerInputs",
            "truthTableOwnerBlockersKnown",
            "publicRpcCapabilityBlocksOnPublicRpcInputs",
            "bridgeCapabilityBlocksOnBridgeInputs",
            "backupCapabilityBlocksOnBackupInput",
            "noProductionReadyClaimWhileBlocked",
            "ownerNeedsNowLoaded",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse",
            "secretMarkerFindingsEmpty"
        )
        requiredMinimums = [ordered]@{
            capabilityCount = 12
            publicLaunchCriticalCapabilityCount = 10
        }
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings",
            "repoBlockedCapabilities",
            "missingUserCapabilityCoverage",
            "missingRequiredReports",
            "blockedCapabilitiesMissingBlockers",
            "blockedCapabilitiesUnknownBlockers"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
            "noLiveBroadcast" = $true
        }
        staleIfOlderThan = @("service-status", "service-monitor", "service-supervisor-validation", "service-install-validation", "systemd-service-install-validation", "wallet-live-service-e2e", "tester-network-e2e", "public-rpc-readiness", "public-rpc-synthetic-canary", "public-tester-gateway-e2e", "dashboard-ui-readiness", "bridge-live-readiness", "bridge-infra-readiness", "bridge-relayer-once", "bridge-relayer-guardrail-validation", "bridge-relayer-loop-validation", "bridge-runtime-credit-validation", "real-value-pilot-aggregate", "bridge-reconciliation", "bridge-release-evidence-validation", "backup-readiness", "backup-restore-validation", "backup-owner-path-dry-run", "backup-install-validation", "ops-snapshot", "ops-alert-rules", "ops-metrics-export", "ops-monitoring-bundle", "ops-alert-install-validation", "ops-metrics-install-validation", "external-tester-readiness", "external-tester-packet", "external-tester-client-validation", "owner-needs-now", "owner-go-live-handoff", "public-deployment-contract", "developer-dev-pack")
    },
    [ordered]@{
        id = "architecture-audit"
        requirement = "System architecture audit covers local runtime, public RPC, backup, bridge, tester, and no-secret gates."
        path = "docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json"
        command = "npm run flowchain:architecture:audit -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
    },
    [ordered]@{
        id = "completion-audit"
        requirement = "Completion audit is fresh and is the release gate for claiming production readiness."
        path = "docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json"
        command = "npm run flowchain:completion:audit -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
        staleIfOlderThan = @("operator-doctor", "service-supervisor-validation", "service-install-validation", "systemd-service-install-validation", "backup-restore-validation", "backup-install-validation", "base-tx-diagnostic-fail-closed", "bridge-no-secret-audit", "bridge-deploy-control-validation", "bridge-relayer-guardrail-validation", "bridge-relayer-loop-validation", "bridge-runtime-credit-validation", "real-value-pilot-aggregate", "bridge-reconciliation-schedule-validation", "bridge-release-evidence-validation", "public-tester-gateway-e2e", "external-tester-packet-validation", "external-tester-client-validation", "external-tester-evidence-validation", "ops-snapshot", "ops-alert-rules", "ops-metrics-export", "ops-alert-install-validation", "ops-metrics-install-validation", "ops-escalation-dry-run", "owner-onboarding", "owner-signup-checklist", "owner-activation-plan", "owner-env-template", "owner-env-readiness-validation", "owner-env-readiness", "public-rpc-synthetic-canary", "public-rpc-canary-schedule-validation", "public-rpc-deployment-bundle", "public-rpc-deployment-automation", "public-rpc-command-matrix", "tester-write-token-setup", "dashboard-ui-readiness", "developer-dev-pack", "node-operator-package", "node-operator-package-verify", "public-deployment-contract")
    },
    [ordered]@{
        id = "no-secret-scan"
        requirement = "Generated reports, docs, and packets contain no secrets or owner-provided values."
        path = "docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json"
        command = "npm run flowchain:no-secret:scan"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "scansDashboardPublicData",
            "scansGeneratedLiveProductReports",
            "scansGeneratedDevPackReports",
            "scansGeneratedSdkDocs",
            "reportPathMatchesProductionGate",
            "scannedCountPositive",
            "findingsEmpty",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings",
            "findings"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
        }
    }
)

function Get-TruthProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [object] $Default = $null
    )

    if ($null -ne $Object -and $Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }
    if ($null -ne $Object) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) {
            return $property.Value
        }
    }
    return $Default
}

function Test-TruthPathExists {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Path
    )

    $current = $Object
    foreach ($part in @($Path -split "\.")) {
        if ($null -eq $current) {
            return $false
        }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($part)) {
                return $false
            }
            $current = $current[$part]
            continue
        }

        $property = $current.PSObject.Properties[$part]
        if ($null -eq $property) {
            return $false
        }
        $current = $property.Value
    }

    return $true
}

function Get-TruthPathProp {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory = $true)][string] $Path,
        [object] $Default = $null
    )

    if (-not (Test-TruthPathExists -Object $Object -Path $Path)) {
        Write-Output -NoEnumerate $Default
        return
    }

    $current = $Object
    foreach ($part in @($Path -split "\.")) {
        if ($current -is [System.Collections.IDictionary]) {
            $current = $current[$part]
            continue
        }
        $current = $current.PSObject.Properties[$part].Value
    }

    Write-Output -NoEnumerate $current
}

function Test-TruthExpectedValue {
    param(
        [AllowNull()][object] $Actual,
        [AllowNull()][object] $Expected
    )

    if ($null -eq $Actual) {
        return $false
    }

    if ($Expected -is [bool]) {
        if ($Actual -is [bool]) {
            return $Actual -eq $Expected
        }
        $actualText = "$Actual".Trim().ToLowerInvariant()
        if ($Expected) {
            return $actualText -eq "true"
        }
        return $actualText -eq "false"
    }

    if ($Expected -is [byte] -or $Expected -is [int16] -or $Expected -is [int] -or $Expected -is [long] -or $Expected -is [float] -or $Expected -is [double] -or $Expected -is [decimal]) {
        try {
            return ([double] $Actual) -eq ([double] $Expected)
        }
        catch {
            return $false
        }
    }

    return "$Actual" -eq "$Expected"
}

function Add-UniqueTruthValue {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Value
    )

    $text = "$Value"
    if (-not [string]::IsNullOrWhiteSpace($text) -and -not $Target.Contains($text)) {
        [void] $Target.Add($text)
    }
}

function Add-TruthBlockersFromList {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList] $Target,
        [AllowNull()][object] $Values
    )

    foreach ($value in @($Values)) {
        Add-UniqueTruthValue -Target $Target -Value $value
    }
}

function Get-TruthGeneratedAt {
    param([AllowNull()][object] $Report)

    $value = Get-TruthProp -Object $Report -Name "generatedAt"
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace("$value")) {
        return $null
    }

    try {
        return [DateTimeOffset]::Parse("$value", [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $null
    }
}

function Get-TruthReportAgeSeconds {
    param([AllowNull()][DateTimeOffset] $GeneratedAt)

    if ($null -eq $GeneratedAt) {
        return $null
    }

    $age = [DateTimeOffset]::UtcNow - $GeneratedAt.ToUniversalTime()
    return [int][Math]::Max(0, [Math]::Floor($age.TotalSeconds))
}

function Get-TruthStatus {
    param([AllowNull()][object] $Report)
    return [string](Get-TruthProp -Object $Report -Name "status" -Default "missing")
}

function Get-TruthBlockers {
    param([AllowNull()][object] $Report)

    $blockers = New-Object System.Collections.ArrayList
    if ($null -eq $Report) {
        return @($blockers)
    }

    Add-TruthBlockersFromList -Target $blockers -Values (Get-TruthProp -Object $Report -Name "missingEnvNames" -Default @())
    Add-TruthBlockersFromList -Target $blockers -Values (Get-TruthProp -Object $Report -Name "invalidEnvNames" -Default @())

    foreach ($problem in @((Get-TruthProp -Object $Report -Name "problems" -Default @()))) {
        $kind = [string](Get-TruthProp -Object $problem -Name "kind" -Default "")
        if ($kind -ne "blocked") {
            continue
        }
        Add-UniqueTruthValue -Target $blockers -Value (Get-TruthProp -Object $problem -Name "name")
        Add-UniqueTruthValue -Target $blockers -Value (Get-TruthProp -Object $problem -Name "envName")
    }

    foreach ($item in @((Get-TruthProp -Object $Report -Name "items" -Default @()))) {
        $itemStatus = [string](Get-TruthProp -Object $item -Name "status" -Default "")
        if ($itemStatus -notin @("blocked", "failed")) {
            continue
        }
        Add-TruthBlockersFromList -Target $blockers -Values (Get-TruthProp -Object $item -Name "blockers" -Default @())
    }

    return @($blockers)
}

function Test-TruthAllKnownOwnerInputs {
    param([AllowNull()][object[]] $Blockers)

    $values = @($Blockers | Where-Object { -not [string]::IsNullOrWhiteSpace("$_") })
    if ($values.Count -eq 0) {
        return $false
    }

    foreach ($value in $values) {
        if ($value -notin $knownOwnerInputs) {
            return $false
        }
    }
    return $true
}

function ConvertTo-TruthEvidence {
    param(
        [AllowNull()][object] $Report,
        [string] $RawStatus,
        [AllowNull()][object[]] $Blockers
    )

    if ($null -eq $Report) {
        return "report=missing"
    }

    $facts = New-Object System.Collections.ArrayList
    Add-UniqueTruthValue -Target $facts -Value "status=$RawStatus"

    foreach ($name in @(
        "latestHeight",
        "finalizedHeight",
        "publicRpcReady",
        "ownerInputReady",
        "ownerInputsStatus",
        "flowChainRpcIsOurs",
        "flowChainRpcIsRepoOwned",
        "thirdPartyFlowChainRpcProviderNeeded",
        "publicRpcRequiresOwnerPublicEdge",
        "base8453RpcIsExternalChainDependency",
        "localEnvFileSupported",
        "externalSignupCount",
        "itemCount",
        "requiredEnvNameCount",
        "fieldGuideCount",
        "templateIncludesAllRequiredEnvNames",
        "pathIsGitIgnored",
        "deploymentReady",
        "packetShareable",
        "externalSharingReady",
        "localTesterRehearsalReady",
        "commandCount",
        "runbookCount",
        "evidenceReportCount",
        "metricCount",
        "expectedFileCount",
        "ownerInputNameCount",
        "methodCount",
        "publicReadyMethodCount",
        "ruleCount",
        "criticalRuleCount",
        "blockedRuleCount",
        "dryRunEventCount",
        "restartAttempts",
        "bridgePollSeconds",
        "settleSeconds",
        "opsSnapshotStatus",
        "opsAlertRulesStatus",
        "completionReady",
        "launchReadinessStatus",
        "productionReady",
        "capabilityCount",
        "publicLaunchCriticalCapabilityCount",
        "blockedCapabilityCount",
        "repoBlockedCapabilityCount",
        "blockedOnlyOnKnownExternalOwnerInputs",
        "blockedOnlyOnOwnerInputs",
        "safeReasonCode",
        "printsEnvValues",
        "envValuesPrinted",
        "noSecrets",
        "noLiveBroadcast",
        "broadcasts"
    )) {
        $value = Get-TruthProp -Object $Report -Name $name
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace("$value")) {
            Add-UniqueTruthValue -Target $facts -Value "$name=$value"
        }
    }

    $chain = Get-TruthProp -Object $Report -Name "chain"
    if ($null -ne $chain) {
        $latest = Get-TruthProp -Object $chain -Name "latestHeight"
        $finalized = Get-TruthProp -Object $chain -Name "finalizedHeight"
        if ($null -ne $latest) {
            Add-UniqueTruthValue -Target $facts -Value "latestHeight=$latest"
        }
        if ($null -ne $finalized) {
            Add-UniqueTruthValue -Target $facts -Value "finalizedHeight=$finalized"
        }
    }

    $backup = Get-TruthProp -Object $Report -Name "backup"
    if ($null -ne $backup) {
        Add-UniqueTruthValue -Target $facts -Value "snapshotProofStatus=$(Get-TruthProp -Object $backup -Name "snapshotProofStatus" -Default "unknown")"
        Add-UniqueTruthValue -Target $facts -Value "restoreProofStatus=$(Get-TruthProp -Object $backup -Name "restoreProofStatus" -Default "unknown")"
    }

    $checks = Get-TruthProp -Object $Report -Name "checks"
    if ($null -ne $checks) {
        foreach ($name in @(
            "backupRestoreHashRoundTrip",
            "latestRestoreUsedLatestSnapshot",
            "restoreTargetsLiveStateProtected",
            "liveStateNonMutationProven",
            "corruptedSnapshotDetected",
            "manifestTamperDetected",
            "missingStateArtifactDetected",
            "missingSnapshotManifestDetected",
            "latestPointerTamperDetected",
            "wrongChainStateMismatchDetected",
            "packageScriptsPresent",
            "planDidNotMutate",
            "statusDidNotMutate",
            "uninstallAbsentDidNotMutate",
            "noExternalDelivery",
            "planCommandPassed",
            "planDidNotMutate",
            "schedulerCmdletsAvailable",
            "actionUsesSupervisor",
            "liveProfileDefault",
            "bridgeRelayerOptInStartsLoop",
            "bundleCommandPassed",
            "verifyCommandPassed",
            "stageNoSecretScanPassed",
            "manifestNextCommandsPresent",
            "statusRelayerReportHealthy",
            "statusAfterStopNotRunning",
            "relayerPidFileRemovedAfterStop",
            "noValidationRelayerProcessAfterStop",
            "opsSnapshotLoaded",
            "opsAlertRulesLoaded",
            "opsAlertRulesPassed",
            "everyCurrentFindingMapped",
            "everyCurrentFindingHasCommands",
            "dryRunEventsDoNotSend",
            "dryRunEventsStoreNoCredentials",
            "walletSendRuntimeBacked",
            "cliSignedTransactionSubmit",
            "browserExampleSmokePassed",
            "openApiSpecGenerated",
            "postmanCollectionGenerated",
            "curlExamplesGenerated",
            "pythonSdkE2ePassed",
            "pythonDevkitWaitTransaction",
            "publicReadinessFailClosed",
            "requiredAndOptionalOwnerInputsSeparated",
            "neededNowExcludesOptionalOwnerInputs",
            "inventoryGenerated",
            "inventorySafe",
            "scansGeneratedDevPackReports",
            "scansGeneratedSdkDocs",
            "dryRunNoNetwork",
            "blockedConnectPackAllowedOnlyByFlag",
            "plannedRoutesCoverReads",
            "plannedRoutesCoverWrites",
            "tokenNotConfiguredInDryRun",
            "desktopProjectConfigured",
            "mobileProjectConfigured",
            "bridgeRouteCovered",
            "bridgePilotRuntimeProofCovered",
            "bridgeRuntimeCreditProofCovered",
            "realValuePilotAggregateProofCovered",
            "publicRpcHeaderProofCovered",
            "fieldGuideCoversAllRequiredEnvNames",
            "fieldGuideCoversAllOptionalEnvNames",
            "fieldGuideHasValidationForEveryName",
            "fieldGuideHasDoNotSendForEveryName",
            "dashboardBrowserE2ePassed",
            "commandsCompletedWithoutTimeout",
            "noSecretLeakageAsserted",
            "noHorizontalOverflowAsserted"
        )) {
            $value = Get-TruthProp -Object $checks -Name $name
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace("$value")) {
                Add-UniqueTruthValue -Target $facts -Value "$name=$value"
            }
        }
    }

    foreach ($arrayName in @(
        "failedChecks",
        "missingChecklistCoverage",
        "missingMetricNames",
        "missingNextCommands",
        "failedVerifyChecks",
        "unmappedCurrentFindingCodes",
        "rulesWithoutCommands",
        "activeRuleIdsMissingFromManifest",
        "activeRuleIdsWithoutCommands",
        "commandsWithInlineEnvAssignment",
        "commandsWithUrls",
        "findingsWithoutCommands",
        "unmappedFindingCodes",
        "missingRequiredEnvNames",
        "missingOptionalEnvNames",
        "missingRequiredOwnerInputs",
        "missingOptionalOwnerInputs",
        "browserProjects",
        "coveredRoutes",
        "coveredProofs",
        "languageSdks"
    )) {
        if (Test-TruthPathExists -Object $Report -Path $arrayName) {
            $values = @((Get-TruthPathProp -Object $Report -Path $arrayName))
            Add-UniqueTruthValue -Target $facts -Value "$($arrayName)Count=$($values.Count)"
        }
    }

    if (@($Blockers).Count -gt 0) {
        Add-UniqueTruthValue -Target $facts -Value "blockers=$(@($Blockers) -join ',')"
    }

    return (@($facts) -join "; ")
}

function Get-TruthClassification {
    param(
        [Parameter(Mandatory = $true)][object] $Definition,
        [AllowNull()][object] $Report,
        [AllowNull()][object[]] $Blockers,
        [bool] $IsStale
    )

    if ($null -eq $Report -or $IsStale) {
        return "stale"
    }

    $rawStatus = (Get-TruthStatus -Report $Report).ToLowerInvariant()
    if ($rawStatus -in @("passed", "valid")) {
        $requiredChecks = @((Get-TruthProp -Object $Definition -Name "requiredChecks" -Default @()))
        if ($requiredChecks.Count -gt 0) {
            $checks = Get-TruthProp -Object $Report -Name "checks"
            foreach ($name in $requiredChecks) {
                if ((Get-TruthProp -Object $checks -Name $name -Default $false) -ne $true) {
                    return "failed"
                }
            }
        }

        $requiredMinimums = Get-TruthProp -Object $Definition -Name "requiredMinimums"
        if ($null -ne $requiredMinimums -and $requiredMinimums -is [System.Collections.IDictionary]) {
            foreach ($entry in $requiredMinimums.GetEnumerator()) {
                $actual = Get-TruthPathProp -Object $Report -Path ([string] $entry.Key)
                try {
                    if (([double] $actual) -lt ([double] $entry.Value)) {
                        return "failed"
                    }
                }
                catch {
                    return "failed"
                }
            }
        }

        foreach ($path in @((Get-TruthProp -Object $Definition -Name "requiredEmptyArrays" -Default @()))) {
            if (-not (Test-TruthPathExists -Object $Report -Path ([string] $path))) {
                return "failed"
            }
            if (@((Get-TruthPathProp -Object $Report -Path ([string] $path))).Count -ne 0) {
                return "failed"
            }
        }

        $requiredReportProperties = Get-TruthProp -Object $Definition -Name "requiredReportProperties"
        if ($null -ne $requiredReportProperties -and $requiredReportProperties -is [System.Collections.IDictionary]) {
            foreach ($entry in $requiredReportProperties.GetEnumerator()) {
                $actual = Get-TruthPathProp -Object $Report -Path ([string] $entry.Key)
                if (-not (Test-TruthExpectedValue -Actual $actual -Expected $entry.Value)) {
                    return "failed"
                }
            }
        }

        return "passed"
    }
    if ($rawStatus -in @("failed", "error", "invalid")) {
        return "failed"
    }
    if ($rawStatus -eq "blocked" -and ((Get-TruthProp -Object $Definition -Name "blockedAsPassed" -Default $false) -eq $true)) {
        $requiredChecks = @((Get-TruthProp -Object $Definition -Name "requiredChecks" -Default @()))
        if ($requiredChecks.Count -gt 0) {
            $checks = Get-TruthProp -Object $Report -Name "checks"
            foreach ($name in $requiredChecks) {
                if ((Get-TruthProp -Object $checks -Name $name -Default $false) -ne $true) {
                    return "failed"
                }
            }
        }

        foreach ($path in @((Get-TruthProp -Object $Definition -Name "requiredEmptyArrays" -Default @()))) {
            if (-not (Test-TruthPathExists -Object $Report -Path ([string] $path))) {
                return "failed"
            }
            if (@((Get-TruthPathProp -Object $Report -Path ([string] $path))).Count -ne 0) {
                return "failed"
            }
        }

        $requiredReportProperties = Get-TruthProp -Object $Definition -Name "requiredReportProperties"
        if ($null -ne $requiredReportProperties -and $requiredReportProperties -is [System.Collections.IDictionary]) {
            foreach ($entry in $requiredReportProperties.GetEnumerator()) {
                $actual = Get-TruthPathProp -Object $Report -Path ([string] $entry.Key)
                if (-not (Test-TruthExpectedValue -Actual $actual -Expected $entry.Value)) {
                    return "failed"
                }
            }
        }

        return "passed"
    }
    if ($rawStatus -eq "blocked") {
        $criticalFindings = @((Get-TruthProp -Object $Report -Name "findings" -Default @()) | Where-Object {
            [string](Get-TruthProp -Object $_ -Name "severity" -Default "") -eq "critical"
        })
        if ($criticalFindings.Count -gt 0) {
            return "failed"
        }
        $blockedOnlyOnKnownOwnerInputs = Get-TruthProp -Object $Report -Name "blockedOnlyOnKnownExternalOwnerInputs" -Default $false
        if ($blockedOnlyOnKnownOwnerInputs -eq $true -or (Test-TruthAllKnownOwnerInputs -Blockers $Blockers)) {
            return "blocked-owner-input"
        }
        if ((Get-TruthProp -Object $Definition -Name "ownerInputGate" -Default $false) -eq $true) {
            return "blocked-owner-input"
        }
        return "blocked-repo-work"
    }
    if ($rawStatus -eq "missing") {
        return "stale"
    }

    return "blocked-repo-work"
}

$reportsById = [ordered]@{}
$generatedAtById = [ordered]@{}
foreach ($definition in $definitions) {
    $fullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $definition.path
    $report = Read-FlowChainJsonIfExists -Path $fullPath
    $reportsById[$definition.id] = $report
    $generatedAtById[$definition.id] = Get-TruthGeneratedAt -Report $report
}

$items = New-Object System.Collections.ArrayList
$now = [DateTimeOffset]::UtcNow
$maxAgeSeconds = [int]([TimeSpan]::FromHours($MaxReportAgeHours).TotalSeconds)

foreach ($definition in $definitions) {
    $id = [string] $definition.id
    $fullPath = Resolve-FlowChainPath -RepoRoot $repoRoot -Path $definition.path
    $report = $reportsById[$id]
    $generatedAt = $generatedAtById[$id]
    $ageSeconds = Get-TruthReportAgeSeconds -GeneratedAt $generatedAt
    $staleReasons = New-Object System.Collections.ArrayList

    if ($null -eq $report) {
        Add-UniqueTruthValue -Target $staleReasons -Value "missing-or-unreadable-report"
    }
    elseif ($null -eq $generatedAt) {
        Add-UniqueTruthValue -Target $staleReasons -Value "missing-generatedAt"
    }
    elseif ($ageSeconds -gt $maxAgeSeconds) {
        Add-UniqueTruthValue -Target $staleReasons -Value "older-than-$MaxReportAgeHours-hours"
    }

    foreach ($dependencyId in @((Get-TruthProp -Object $definition -Name "staleIfOlderThan" -Default @()))) {
        $dependencyGeneratedAt = $generatedAtById[$dependencyId]
        if ($null -ne $generatedAt -and $null -ne $dependencyGeneratedAt -and $generatedAt.ToUniversalTime() -lt $dependencyGeneratedAt.ToUniversalTime()) {
            Add-UniqueTruthValue -Target $staleReasons -Value "older-than-$dependencyId"
        }
    }

    $blockers = @(Get-TruthBlockers -Report $report)
    $rawStatus = Get-TruthStatus -Report $report
    $classification = Get-TruthClassification -Definition $definition -Report $report -Blockers $blockers -IsStale (@($staleReasons).Count -gt 0)
    $evidence = ConvertTo-TruthEvidence -Report $report -RawStatus $rawStatus -Blockers $blockers

    $ownerInputBlockers = @($blockers | Where-Object { $_ -in $knownOwnerInputs })
    $requiredOwnerInputBlockers = @($ownerInputBlockers | Where-Object { $_ -in $requiredOwnerInputs })
    $optionalOwnerInputBlockers = @($ownerInputBlockers | Where-Object { $_ -in $optionalOwnerInputs })

    [void] $items.Add([ordered]@{
        id = $id
        requirement = [string] $definition.requirement
        classification = $classification
        rawStatus = $rawStatus
        evidence = $evidence
        command = [string] $definition.command
        reportPath = [string] $definition.path
        reportExists = $null -ne $report
        generatedAt = if ($null -ne $generatedAt) { $generatedAt.ToUniversalTime().ToString("o") } else { $null }
        ageSeconds = $ageSeconds
        staleReasons = @($staleReasons)
        blockers = @($blockers)
        ownerInputBlockers = @($ownerInputBlockers)
        requiredOwnerInputBlockers = @($requiredOwnerInputBlockers)
        optionalOwnerInputBlockers = @($optionalOwnerInputBlockers)
        productionGate = [bool] $definition.productionGate
    })
}

$classificationCounts = [ordered]@{}
foreach ($classification in @("passed", "blocked-owner-input", "blocked-repo-work", "failed", "stale")) {
    $classificationCounts[$classification] = @($items | Where-Object { $_.classification -eq $classification }).Count
}

$missingOwnerInputs = New-Object System.Collections.ArrayList
$missingOptionalOwnerInputs = New-Object System.Collections.ArrayList
foreach ($item in @($items)) {
    foreach ($name in @($item.requiredOwnerInputBlockers)) {
        Add-UniqueTruthValue -Target $missingOwnerInputs -Value $name
    }
    foreach ($name in @($item.optionalOwnerInputBlockers)) {
        Add-UniqueTruthValue -Target $missingOptionalOwnerInputs -Value $name
    }
}

$staleItems = @($items | Where-Object { $_.classification -eq "stale" })
$failedItems = @($items | Where-Object { $_.classification -eq "failed" })
$repoBlockedItems = @($items | Where-Object { $_.classification -eq "blocked-repo-work" })
$ownerBlockedItems = @($items | Where-Object { $_.classification -eq "blocked-owner-input" })

$overallStatus = if ($failedItems.Count -gt 0) {
    "failed"
}
elseif ($staleItems.Count -gt 0) {
    "stale"
}
elseif ($repoBlockedItems.Count -gt 0) {
    "blocked-repo-work"
}
elseif ($ownerBlockedItems.Count -gt 0) {
    "blocked-owner-input"
}
else {
    "passed"
}

$nextRepoTasks = New-Object System.Collections.ArrayList
foreach ($item in @($staleItems + $repoBlockedItems + $failedItems)) {
    [void] $nextRepoTasks.Add([ordered]@{
        id = Get-TruthProp -Object $item -Name "id"
        classification = Get-TruthProp -Object $item -Name "classification"
        command = Get-TruthProp -Object $item -Name "command"
        reason = if (@((Get-TruthProp -Object $item -Name "staleReasons" -Default @())).Count -gt 0) { @((Get-TruthProp -Object $item -Name "staleReasons" -Default @())) -join "," } else { Get-TruthProp -Object $item -Name "rawStatus" }
    })
}
if ($nextRepoTasks.Count -eq 0 -and $ownerBlockedItems.Count -gt 0) {
    [void] $nextRepoTasks.Add([ordered]@{
        id = "owner-inputs"
        classification = "blocked-owner-input"
        command = "npm run flowchain:owner-inputs -- -AllowBlocked"
        reason = "Only known owner-input blockers remain in the current truth table."
    })
}

$report = [ordered]@{
    schema = "flowchain.production_truth_table_report.v1"
    generatedAt = $now.ToString("o")
    status = $overallStatus
    maxReportAgeHours = $MaxReportAgeHours
    classificationCounts = $classificationCounts
    productionGateCount = @($items | Where-Object { $_.productionGate -eq $true }).Count
    completionReady = $overallStatus -eq "passed"
    blockedOnlyOnKnownOwnerInputs = $overallStatus -eq "blocked-owner-input"
    requiredOwnerInputs = @($requiredOwnerInputs)
    optionalOwnerInputs = @($optionalOwnerInputs)
    missingOwnerInputs = @($missingOwnerInputs)
    missingRequiredOwnerInputs = @($missingOwnerInputs)
    missingOptionalOwnerInputs = @($missingOptionalOwnerInputs)
    nextRepoOwnedTasks = @($nextRepoTasks)
    items = @($items)
}

Write-FlowChainJson -Path $reportFullPath -Value $report -Depth 20

$lines = New-Object System.Collections.ArrayList
[void] $lines.Add("# FlowChain Production Truth Table")
[void] $lines.Add("")
[void] $lines.Add("Generated: $($report.generatedAt)")
[void] $lines.Add("Status: $overallStatus")
[void] $lines.Add("Completion ready: $($report.completionReady)")
[void] $lines.Add("Blocked only on known owner inputs: $($report.blockedOnlyOnKnownOwnerInputs)")
[void] $lines.Add("")
[void] $lines.Add("## Classification Counts")
[void] $lines.Add("")
[void] $lines.Add("| Classification | Count |")
[void] $lines.Add("| --- | ---: |")
foreach ($entry in $classificationCounts.GetEnumerator()) {
    [void] $lines.Add("| $($entry.Key) | $($entry.Value) |")
}
[void] $lines.Add("")

if (@($missingOwnerInputs).Count -gt 0) {
    [void] $lines.Add("## Missing Required Owner Inputs")
    [void] $lines.Add("")
    foreach ($name in @($missingOwnerInputs)) {
        [void] $lines.Add("- $name")
    }
    [void] $lines.Add("")
}

if (@($missingOptionalOwnerInputs).Count -gt 0) {
    [void] $lines.Add("## Optional Owner Inputs Mentioned")
    [void] $lines.Add("")
    [void] $lines.Add("These names are accepted owner-provided overrides, but they are not required for go-live readiness.")
    [void] $lines.Add("")
    foreach ($name in @($missingOptionalOwnerInputs)) {
        [void] $lines.Add("- $name")
    }
    [void] $lines.Add("")
}

if ($nextRepoTasks.Count -gt 0) {
    [void] $lines.Add("## Next Repo-Owned Tasks")
    [void] $lines.Add("")
    foreach ($task in @($nextRepoTasks | Select-Object -First 8)) {
        $taskId = Get-TruthProp -Object $task -Name "id"
        $taskClassification = Get-TruthProp -Object $task -Name "classification"
        $taskReason = Get-TruthProp -Object $task -Name "reason"
        $taskCommand = Get-TruthProp -Object $task -Name "command"
        [void] $lines.Add("- ${taskId}: ${taskClassification} - ${taskReason}")
        [void] $lines.Add("  Command: $taskCommand")
    }
    [void] $lines.Add("")
}

[void] $lines.Add("## Gate Table")
[void] $lines.Add("")
[void] $lines.Add("| Gate | Classification | Raw Status | Evidence | Command |")
[void] $lines.Add("| --- | --- | --- | --- | --- |")
foreach ($item in @($items)) {
    $itemId = Get-TruthProp -Object $item -Name "id"
    $itemClassification = Get-TruthProp -Object $item -Name "classification"
    $itemRawStatus = Get-TruthProp -Object $item -Name "rawStatus"
    $itemCommand = Get-TruthProp -Object $item -Name "command"
    $safeEvidence = "$(Get-TruthProp -Object $item -Name "evidence")".Replace("|", "\|")
    [void] $lines.Add("| $itemId | $itemClassification | $itemRawStatus | $safeEvidence | ``$itemCommand`` |")
}
[void] $lines.Add("")
[void] $lines.Add("## Release Decision")
[void] $lines.Add("")
if ($overallStatus -eq "passed") {
    [void] $lines.Add("All tracked production gates are passed from fresh evidence.")
}
elseif ($overallStatus -eq "blocked-owner-input") {
    [void] $lines.Add("Do not claim public production readiness yet. The current tracked blockers are known owner inputs.")
}
elseif ($overallStatus -eq "stale") {
    [void] $lines.Add("Do not claim public production readiness yet. At least one required report is stale or missing.")
}
elseif ($overallStatus -eq "blocked-repo-work") {
    [void] $lines.Add("Do not claim public production readiness yet. At least one repo-owned gate is blocked.")
}
else {
    [void] $lines.Add("Do not claim public production readiness yet. At least one gate failed.")
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$markdownParent = Split-Path -Parent $markdownFullPath
if (-not [string]::IsNullOrWhiteSpace($markdownParent)) {
    New-Item -ItemType Directory -Force -Path $markdownParent | Out-Null
}
[System.IO.File]::WriteAllText($markdownFullPath, (@($lines) -join [Environment]::NewLine) + [Environment]::NewLine, $utf8NoBom)

Write-Host "FlowChain production truth table status: $overallStatus"
Write-Host "Report: $reportFullPath"
Write-Host "Markdown: $markdownFullPath"

if ($overallStatus -ne "passed" -and -not $AllowBlocked) {
    exit 1
}
