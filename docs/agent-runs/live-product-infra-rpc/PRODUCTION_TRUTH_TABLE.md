# FlowChain Production Truth Table

Generated: 2026-05-18T05:25:56.7293811+00:00
Status: blocked-owner-input
Completion ready: False
Blocked only on known owner inputs: True

## Classification Counts

| Classification | Count |
| --- | ---: |
| passed | 31 |
| blocked-owner-input | 15 |
| blocked-repo-work | 0 |
| failed | 0 |
| stale | 0 |

## Missing Owner Inputs

- FLOWCHAIN_PILOT_OPERATOR_ACK
- FLOWCHAIN_BASE8453_RPC_URL
- FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
- FLOWCHAIN_BASE8453_SUPPORTED_TOKEN
- FLOWCHAIN_BASE8453_ASSET_DECIMALS
- FLOWCHAIN_BASE8453_FROM_BLOCK
- FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
- FLOWCHAIN_PILOT_TOTAL_CAP_WEI
- FLOWCHAIN_PILOT_CONFIRMATIONS
- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED
- FLOWCHAIN_RPC_STATE_BACKUP_PATH
- FLOWCHAIN_TESTER_WRITE_ENABLED
- FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256
- FLOWCHAIN_TESTER_MAX_SEND_UNITS
- FLOWCHAIN_BASE8453_CURSOR_STATE
- FLOWCHAIN_BASE8453_TO_BLOCK

## Next Repo-Owned Tasks

- owner-inputs: blocked-owner-input - Only known owner-input blockers remain in the current truth table.
  Command: npm run flowchain:owner-inputs -- -AllowBlocked

## Gate Table

| Gate | Classification | Raw Status | Evidence | Command |
| --- | --- | --- | --- | --- |
| service-status | passed | passed | status=passed; latestHeight=66040; finalizedHeight=66040; failedChecksCount=0 | `npm run flowchain:service:status` |
| service-monitor | passed | passed | status=passed; latestHeight=65995; failedChecksCount=0 | `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30` |
| operator-doctor | blocked-owner-input | blocked | status=blocked; latestHeight=66040; finalizedHeight=66040; blockedOnlyOnOwnerInputs=True; failedChecksCount=0 | `npm run flowchain:doctor -- -ReportPath docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json` |
| service-supervisor-validation | passed | passed | status=passed; restartAttempts=1; failedChecksCount=0 | `npm run flowchain:service:supervisor:validate` |
| service-install-validation | passed | passed | status=passed; packageScriptsPresent=True; planDidNotMutate=True; statusDidNotMutate=True; planCommandPassed=True; schedulerCmdletsAvailable=True; actionUsesSupervisor=True; liveProfileDefault=True; bridgeRelayerOptInStartsLoop=True; failedChecksCount=0 | `npm run flowchain:service:install:validate` |
| systemd-service-install-validation | passed | passed | status=passed; failedChecksCount=0 | `npm run flowchain:service:install:systemd:validate` |
| live-product-e2e | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS,FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS | `npm run flowchain:live-product:e2e -- -AllowBlocked` |
| live-infra-check | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:live-infra:check -- -AllowBlocked` |
| wallet-live-service-e2e | passed | passed | status=passed | `npm run flowchain:wallet:live-service:e2e` |
| tester-network-e2e | passed | passed | status=passed | `npm run flowchain:wallet:live-tester:e2e` |
| owner-inputs | blocked-owner-input | blocked | status=blocked; ownerInputReady=False; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:owner-inputs -- -AllowBlocked` |
| owner-onboarding | passed | passed | status=passed; ownerInputsStatus=blocked; flowChainRpcIsOurs=True; thirdPartyFlowChainRpcProviderNeeded=False; publicRpcRequiresOwnerPublicEdge=True; base8453RpcIsExternalChainDependency=True; localEnvFileSupported=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:owner:onboarding` |
| owner-signup-checklist | passed | passed | status=passed; ownerInputsStatus=blocked; flowChainRpcIsRepoOwned=True; thirdPartyFlowChainRpcProviderNeeded=False; localEnvFileSupported=True; externalSignupCount=3; itemCount=9; missingChecklistCoverageCount=0; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:owner:signup-checklist` |
| owner-env-template | passed | passed | status=passed; requiredEnvNameCount=17; templateIncludesAllRequiredEnvNames=True; pathIsGitIgnored=True | `npm run flowchain:owner-env:template` |
| owner-env-readiness-validation | passed | passed | status=passed | `npm run flowchain:owner-env:readiness:validate` |
| owner-env-readiness | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:owner-env:readiness -- -AllowBlocked` |
| public-rpc-readiness | blocked-owner-input | blocked | status=blocked; publicRpcReady=False; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH | `npm run flowchain:public-rpc:check -- -AllowBlocked` |
| public-rpc-validation | passed | passed | status=passed; publicRpcReady=False; failedChecksCount=0 | `npm run flowchain:public-rpc:validate` |
| public-rpc-abuse-test | passed | passed | status=passed; failedChecksCount=0 | `npm run flowchain:public-rpc:abuse-test` |
| public-rpc-deployment-bundle | passed | passed | status=passed; flowChainRpcIsRepoOwned=True; thirdPartyFlowChainRpcProviderNeeded=False; failedChecksCount=0 | `npm run flowchain:public-rpc:deployment-bundle` |
| public-rpc-deployment-automation | passed | passed | status=passed; flowChainRpcIsRepoOwned=True; thirdPartyFlowChainRpcProviderNeeded=False; failedChecksCount=0 | `npm run flowchain:public-rpc:deployment:automation` |
| node-operator-package | passed | passed | status=passed; commandCount=41; runbookCount=24; evidenceReportCount=34; packageScriptsPresent=True; failedChecksCount=0 | `npm run flowchain:operator:package` |
| node-operator-package-verify | passed | passed | status=passed; commandCount=41; expectedFileCount=53; ownerInputNameCount=17; failedChecksCount=0 | `npm run flowchain:operator:package:verify` |
| second-computer-readiness | passed | passed | status=passed; bundleCommandPassed=True; verifyCommandPassed=True; stageNoSecretScanPassed=True; manifestNextCommandsPresent=True; failedChecksCount=0; missingNextCommandsCount=0; failedVerifyChecksCount=0 | `npm run flowchain:second-computer:readiness` |
| backup-readiness | blocked-owner-input | blocked | status=blocked; snapshotProofStatus=not-run; restoreProofStatus=not-run; blockers=FLOWCHAIN_RPC_STATE_BACKUP_PATH | `npm run flowchain:backup:check -- -AllowBlocked` |
| backup-restore-validation | passed | passed | status=passed; backupRestoreHashRoundTrip=True; latestRestoreUsedLatestSnapshot=True; restoreTargetsLiveStateProtected=True; liveStateNonMutationProven=True; corruptedSnapshotDetected=True; manifestTamperDetected=True; missingStateArtifactDetected=True; missingSnapshotManifestDetected=True; latestPointerTamperDetected=True; wrongChainStateMismatchDetected=True; failedChecksCount=0 | `npm run flowchain:backup:restore:validate` |
| backup-owner-path-dry-run | passed | passed | status=passed; failedChecksCount=0 | `npm run flowchain:backup:owner-path:dry-run` |
| bridge-live-readiness | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:bridge:live:check -- -AllowBlocked` |
| bridge-infra-readiness | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:bridge:infra:check -- -AllowBlocked` |
| bridge-deploy-control-validation | passed | passed | status=passed; failedChecksCount=0 | `npm run flowchain:bridge:deploy:control:validate` |
| bridge-relayer-guardrail-validation | passed | passed | status=passed; failedChecksCount=0 | `npm run flowchain:bridge:relayer:guardrail:validate` |
| bridge-relayer-loop-validation | passed | passed | status=passed; bridgePollSeconds=5; settleSeconds=5; statusRelayerReportHealthy=True; statusAfterStopNotRunning=True; relayerPidFileRemovedAfterStop=True; noValidationRelayerProcessAfterStop=True; failedChecksCount=0 | `npm run flowchain:bridge:relayer:loop:validate` |
| external-tester-readiness | blocked-owner-input | blocked | status=blocked; latestHeight=64687; externalSharingReady=False; localTesterRehearsalReady=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:tester:readiness -- -AllowBlocked` |
| external-tester-packet | blocked-owner-input | blocked | status=blocked; latestHeight=64687; finalizedHeight=64687; ownerInputsStatus=blocked; packetShareable=False; externalSharingReady=False; localTesterRehearsalReady=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:external-tester:packet -- -AllowBlocked` |
| external-tester-packet-validation | passed | passed | status=passed; packetShareable=False; externalSharingReady=False; failedChecksCount=0; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:external-tester:packet:validate` |
| dashboard-ui-readiness | passed | passed | status=passed; desktopProjectConfigured=True; mobileProjectConfigured=True; dashboardBrowserE2ePassed=True; noSecretLeakageAsserted=True; noHorizontalOverflowAsserted=True; failedChecksCount=0; browserProjectsCount=2; coveredRoutesCount=5 | `npm run flowchain:dashboard:ui:readiness` |
| ops-snapshot | blocked-owner-input | blocked | status=blocked; latestHeight=65760; finalizedHeight=65760 | `npm run flowchain:ops:snapshot -- -AllowBlocked` |
| ops-alert-rules | passed | passed | status=passed; ruleCount=16; criticalRuleCount=10; blockedRuleCount=6; opsSnapshotStatus=blocked; opsSnapshotLoaded=True; everyCurrentFindingMapped=True; failedChecksCount=0; unmappedCurrentFindingCodesCount=0; rulesWithoutCommandsCount=0; activeRuleIdsWithoutCommandsCount=0; commandsWithInlineEnvAssignmentCount=0; commandsWithUrlsCount=0; findingsWithoutCommandsCount=0 | `npm run flowchain:ops:alerts -- -AllowBlocked` |
| ops-metrics-export | passed | passed | status=passed; metricCount=28; opsSnapshotLoaded=True; opsAlertRulesLoaded=True; failedChecksCount=0; missingMetricNamesCount=0 | `npm run flowchain:ops:metrics:export` |
| ops-alert-install-validation | passed | passed | status=passed; packageScriptsPresent=True; planDidNotMutate=True; statusDidNotMutate=True; uninstallAbsentDidNotMutate=True; noExternalDelivery=True; planCommandPassed=True; schedulerCmdletsAvailable=True; failedChecksCount=0 | `npm run flowchain:ops:alerts:install:validate` |
| ops-escalation-dry-run | passed | passed | status=passed; dryRunEventCount=6; opsSnapshotStatus=blocked; opsAlertRulesStatus=passed; packageScriptsPresent=True; opsSnapshotLoaded=True; opsAlertRulesLoaded=True; opsAlertRulesPassed=True; everyCurrentFindingMapped=True; everyCurrentFindingHasCommands=True; dryRunEventsDoNotSend=True; dryRunEventsStoreNoCredentials=True; failedChecksCount=0; activeRuleIdsMissingFromManifestCount=0; activeRuleIdsWithoutCommandsCount=0; commandsWithInlineEnvAssignmentCount=0; commandsWithUrlsCount=0; findingsWithoutCommandsCount=0; unmappedFindingCodesCount=0 | `npm run flowchain:ops:escalation:dry-run -- -NoRefresh` |
| incident-drill | passed | passed | status=passed | `npm run flowchain:ops:incident-drill` |
| public-deployment-contract | blocked-owner-input | blocked | status=blocked; deploymentReady=False; packetShareable=False; blockedOnlyOnKnownExternalOwnerInputs=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:public-deployment:contract -- -AllowBlocked` |
| architecture-audit | blocked-owner-input | blocked | status=blocked; blockedOnlyOnKnownExternalOwnerInputs=True; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS,FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_BASE8453_CURSOR_STATE,FLOWCHAIN_BASE8453_TO_BLOCK | `npm run flowchain:architecture:audit -- -AllowBlocked` |
| completion-audit | blocked-owner-input | blocked | status=blocked; latestHeight=66040; completionReady=False; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS,FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS | `npm run flowchain:completion:audit -- -AllowBlocked` |
| no-secret-scan | passed | passed | status=passed | `npm run flowchain:no-secret:scan` |

## Release Decision

Do not claim public production readiness yet. The current tracked blockers are known owner inputs.
