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

$knownOwnerInputs = @(
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
    "FLOWCHAIN_BASE8453_CURSOR_STATE",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
    "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
    "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
    "FLOWCHAIN_PILOT_CONFIRMATIONS"
)

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
        requirement = "Service supervisor validation proves a crashed local control-plane can be recovered under the live profile without deleting chain state."
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
            "crashStatusBlocked",
            "supervisorOnceRecoveryCommandPassed",
            "restartAttemptsExactlyOne",
            "afterStatusCommandPassed",
            "afterRecoveryStatusPassed",
            "afterRecoveryNodeRunning",
            "afterRecoveryControlPlaneRunning",
            "afterRecoveryHeightNumeric",
            "afterRecoveryLiveProfile",
            "afterRecoveryMaxBlocksUnbounded",
            "childLogPathsInsideRepo",
            "secretMarkerFindingsEmpty",
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredMinimums = [ordered]@{
            restartAttempts = 1
        }
        requiredEmptyArrays = @(
            "failedChecks",
            "secretMarkerFindings"
        )
        requiredReportProperties = [ordered]@{
            "before.status" = "passed"
            "afterCrash.status" = "blocked"
            "afterRecovery.status" = "passed"
            "afterRecovery.nodeRunning" = $true
            "afterRecovery.controlPlaneRunning" = $true
            "afterRecovery.liveProfile" = $true
            "afterRecovery.maxBlocks" = 0
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
            "ownerEnvFileUsed",
            "repoWorkingDirectoryUsed",
            "cargoTargetDirIsExternalized",
            "leastPrivilegeHardeningPresent",
            "writePathsScoped",
            "installTargetPresent",
            "renderScriptRendersSystemdUnits",
            "verifyRunbookMentionsSystemdVerify",
            "rollbackRunbookMentionsSystemctl",
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
        id = "owner-env-template"
        requirement = "Owner env template creates or preserves an ignored local-only NAME=value scaffold for every required owner input without recording real values."
        path = "docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json"
        command = "npm run flowchain:owner-env:template"
        productionGate = $true
        ownerInputGate = $false
        requiredMinimums = [ordered]@{
            requiredEnvNameCount = 17
        }
        requiredChecks = @(
            "pathIsGitIgnored",
            "createdOrPreservedLocalFile",
            "templateIncludesAllRequiredEnvNames",
            "requiredEnvNameCountExpected",
            "optionalEnvNameCountExpected",
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
        id = "public-rpc-readiness"
        requirement = "Public FlowChain RPC has URL, TLS acknowledgement, CORS, rate limit, backup path, and response hygiene."
        path = "docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json"
        command = "npm run flowchain:public-rpc:check -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
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
        requirement = "Public RPC deployment automation validates owner-host rendering of concrete Nginx, systemd, shell preflight, Windows preflight, tester write unauthenticated rejection probe, post-deploy verification, and rollback phases without host mutation or owner-value leakage."
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
            "renderedFilesDoNotContainTokenHash",
            "renderedReportDoesNotContainTokenHash",
            "renderedReportKeepsOwnerPathsOutsideRepo",
            "renderedReportNoSecrets",
            "renderedReportBroadcastsFalse",
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
            "ownerInputNamesOnly",
            "flowChainRpcIsRepoOwned",
            "thirdPartyFlowChainRpcProviderNeededFalse",
            "noSecretScanPassed",
            "envValuesPrintedFalse",
            "broadcastsFalse",
            "noSecrets"
        )
    },
    [ordered]@{
        id = "node-operator-package-verify"
        requirement = "Node operator package verifier independently checks generated package files, command matrix, owner-input name-only boundary, forbidden local files, and no-secret scan."
        path = "docs/agent-runs/live-product-infra-rpc/operator-package-verify-report.json"
        command = "npm run flowchain:operator:package:verify"
        productionGate = $true
        ownerInputGate = $false
        requiredChecks = @(
            "packageReportExists",
            "packageReportPassed",
            "packageDirExists",
            "manifestExists",
            "manifestSchemaValid",
            "commandMatrixExists",
            "commandMatrixCountMatches",
            "expectedFilesPresent",
            "reportRunbookCountEnough",
            "reportEvidenceCountEnough",
            "ownerInputNamesOnly",
            "noForbiddenLocalFiles",
            "noSecretScanPassed",
            "envValuesPrintedFalse",
            "broadcastsFalse",
            "noSecrets"
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
            "envValuesPrintedFalse",
            "noSecrets",
            "broadcastsFalse"
        )
        requiredEmptyArrays = @(
            "failedChecks",
            "missingNextCommands",
            "failedVerifyChecks"
        )
        requiredReportProperties = [ordered]@{
            "envValuesPrinted" = $false
            "noSecrets" = $true
            "broadcasts" = $false
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
        id = "external-tester-readiness"
        requirement = "External tester flow remains blocked until public RPC, backup, bridge, and local tester evidence pass."
        path = "docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json"
        command = "npm run flowchain:tester:readiness -- -AllowBlocked"
        productionGate = $true
        ownerInputGate = $true
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
    },
    [ordered]@{
        id = "dashboard-ui-readiness"
        requirement = "Dashboard browser readiness proves desktop and mobile users can create a tester wallet, request faucet funds, send tester units, inspect the result in Explorer, and avoid token/secret leakage or horizontal overflow."
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
            "noSecretLeakageAsserted",
            "noHorizontalOverflowAsserted",
            "dashboardUnitTestsPassed",
            "dashboardBrowserE2ePassed",
            "dashboardBuildPassed",
            "controlPlaneTesterGatewayTestsPassed"
        )
        requiredEmptyArrays = @(
            "failedChecks"
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
        requirement = "Ops metrics export converts no-secret service, alert, public-readiness, bridge, tester, truth-table, and no-secret evidence into JSON plus Prometheus textfile metrics without network delivery or owner-value leakage."
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
            "truthTableLoaded",
            "noSecretLoaded",
            "metricsJsonWritten",
            "prometheusTextWritten",
            "markdownWritten",
            "metricCountSufficient",
            "requiredMetricsPresent",
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
            metricCount = 25
        }
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
        staleIfOlderThan = @("operator-doctor", "service-supervisor-validation", "service-install-validation", "systemd-service-install-validation", "backup-restore-validation", "bridge-deploy-control-validation", "bridge-relayer-guardrail-validation", "bridge-relayer-loop-validation", "external-tester-packet-validation", "ops-snapshot", "ops-alert-rules", "ops-metrics-export", "ops-alert-install-validation", "ops-escalation-dry-run", "owner-onboarding", "owner-signup-checklist", "owner-env-template", "owner-env-readiness-validation", "owner-env-readiness", "public-rpc-deployment-bundle", "public-rpc-deployment-automation", "dashboard-ui-readiness", "node-operator-package", "node-operator-package-verify", "public-deployment-contract")
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
        "blockedOnlyOnKnownExternalOwnerInputs",
        "blockedOnlyOnOwnerInputs"
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
            "desktopProjectConfigured",
            "mobileProjectConfigured",
            "dashboardBrowserE2ePassed",
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
        "browserProjects",
        "coveredRoutes"
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
        ownerInputBlockers = @($blockers | Where-Object { $_ -in $knownOwnerInputs })
        productionGate = [bool] $definition.productionGate
    })
}

$classificationCounts = [ordered]@{}
foreach ($classification in @("passed", "blocked-owner-input", "blocked-repo-work", "failed", "stale")) {
    $classificationCounts[$classification] = @($items | Where-Object { $_.classification -eq $classification }).Count
}

$missingOwnerInputs = New-Object System.Collections.ArrayList
foreach ($item in @($items)) {
    foreach ($name in @($item.ownerInputBlockers)) {
        Add-UniqueTruthValue -Target $missingOwnerInputs -Value $name
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
    missingOwnerInputs = @($missingOwnerInputs)
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
    [void] $lines.Add("## Missing Owner Inputs")
    [void] $lines.Add("")
    foreach ($name in @($missingOwnerInputs)) {
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
