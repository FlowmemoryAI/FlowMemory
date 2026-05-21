# FlowChain Public RPC Deployment Automation

Generated: 2026-05-21T02:05:54.2310320Z
Status: passed
Action: Validate

This validator proves the owner-host public RPC deployment path can render concrete Nginx, systemd, shell preflight, Windows preflight, verification, and rollback artifacts without printing owner values or mutating the host.

## Checks

- bundleReportPassed: True
- renderScriptExists: True
- packageScriptPresent: True
- bundleHasOwnerRenderValidation: True
- bundleHasShellPreflight: True
- bundleHasWindowsPreflight: True
- bundleHasRollbackRunbook: True
- bundleHasSecurityHeaders: True
- bundlePreflightsCheckSecurityHeaders: True
- bundlePreflightsCheckMethodRejection: True
- commandPlanIncludesTesterGatewayE2e: True
- commandPlanIncludesWalletTesterE2e: True
- commandPlanIncludesSyntheticCanary: True
- commandPlanIncludesCutoverRehearsal: True
- commandPlanIncludesTruthTable: True
- commandPlanIncludesNoSecretScan: True
- ownerPathsOutsideRepo: True
- hostMutationPerformedFalse: True
- valuesPrintedFalse: True
- envValuesPrintedFalse: True
- noSecrets: True
- secretMarkerFindingsEmpty: True
- broadcastsFalse: True
- liveBroadcastsFalse: True
- renderCommandPassed: True
- renderedNginxWritten: True
- renderedSystemdLiveWritten: True
- renderedSystemdSupervisorWritten: True
- renderedShellPreflightWritten: True
- renderedWindowsPreflightWritten: True
- renderedOwnerHostApplyScriptWritten: True
- renderedOwnerHostApplyScriptHasPlanApplyRollback: True
- renderedOwnerHostApplyScriptVerifiesHashes: True
- renderedOwnerHostApplyScriptRunsPostDeployProof: True
- renderedReportWritten: True
- renderedReportPassed: True
- renderedReportAllowedOriginCountPresent: True
- renderedFilesHaveNoPlaceholders: True
- renderedFilesKeepPrivateOrigin: True
- renderedNginxHasTls: True
- renderedNginxHasCorsForwarding: True
- renderedNginxHasRateLimit: True
- renderedNginxHasSecurityHeaders: True
- renderedNginxAuthorizationForwardingScoped: True
- renderedSystemdUsesOwnerEnv: True
- renderedPreflightHasReadinessProbe: True
- renderedPreflightHasTesterUnauthProbe: True
- renderedPreflightHasDisallowedOriginProbe: True
- renderedPreflightChecksSecurityHeaders: True
- renderedPreflightHasMethodRejectionProbes: True
- renderedPreflightBlocksBroadStatePath: True
- renderedPreflightBlocksPrivateWalletCreate: True
- renderedFilesDoNotContainTokenHash: True
- renderedReportDoesNotContainTokenHash: True
- renderedReportKeepsOwnerPathsOutsideRepo: True
- renderedReportNoSecrets: True
- renderedReportBroadcastsFalse: True
- renderedReportSummaryPresent: True
- renderedReportSummaryPassed: True
- renderedReportSummaryListsFiles: True
- renderedReportSummaryHasRequiredEnvNames: True
- renderedReportSummaryNoSecrets: True
- renderedReportSummaryBroadcastsFalse: True
- renderedReportSummaryOwnerPathsOutsideRepo: True
- ownerHostApplyPlanPresent: True
- ownerHostApplyPlanSchema: True
- ownerHostApplyPlanRepoOwned: True
- ownerHostApplyPlanPrivateOrigin: True
- ownerHostApplyPlanArtifactManifestCount: True
- ownerHostApplyPlanAllArtifactsListed: True
- ownerHostApplyPlanArtifactsExist: True
- ownerHostApplyPlanArtifactsHaveSha256: True
- ownerHostApplyPlanInstallTargetsMapped: True
- ownerHostApplyPlanPhaseCount: True
- ownerHostApplyPlanAllPhasesPresent: True
- ownerHostApplyPlanHasMutatingInstallPhase: True
- ownerHostApplyPlanHasMutatingEdgePhase: True
- ownerHostApplyPlanHasReadOnlyProofPhase: True
- ownerHostApplyPlanIncludesSystemdInstallCommand: True
- ownerHostApplyPlanIncludesSystemdStatusCommand: True
- ownerHostApplyPlanIncludesSystemdUninstallRollback: True
- ownerHostApplyPlanIncludesNginxReload: True
- ownerHostApplyPlanIncludesOwnerApplyScript: True
- ownerHostApplyPlanIncludesPostDeployEvidence: True
- ownerHostApplyPlanValuesPrintedFalse: True
- ownerHostApplyPlanEnvValuesPrintedFalse: True
- ownerHostApplyPlanNoSecrets: True
- ownerHostApplyPlanBroadcastsFalse: True
- rollbackDrillPerformed: True
- rollbackRenderedConfigExists: True
- rollbackPreviousConfigWritten: True
- rollbackRenderedConfigRestoredFromPrevious: True
- rollbackOriginalConfigRestoredAfterDrill: True
- rollbackArtifactsStayedInsideRenderDir: True
- rollbackDrillNoSecrets: True
- rollbackDrillBroadcastsFalse: True
- renderedReportSnapshotWritten: True
- renderedReportSnapshotNoSecrets: True
- cleanupAttempted: True

## Deployment Phases

- render-owner-files
- verify-systemd-units
- test-nginx-config
- run-public-rpc-preflight
- run-post-deploy-readiness-gates
- rollback-drill-no-host-mutation
- rollback-or-emergency-stop

## Commands

- npm run flowchain:public-rpc:deployment-bundle
- npm run flowchain:public-rpc:deployment:automation
- powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-public-rpc-deployment-automation.ps1 -Action Render -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -OwnerEnvFile <FLOWCHAIN_OWNER_ENV_FILE> -TlsCertificatePath <PATH_TO_TLS_CERTIFICATE> -TlsCertificateKeyPath <PATH_TO_TLS_CERTIFICATE_KEY> -NginxExe <FLOWCHAIN_NGINX_EXE>
- npm run flowchain:service:install:systemd:validate
- npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>
- npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop
- systemd-analyze verify <FLOWCHAIN_SYSTEMD_RENDERED_UNIT>
- systemd-analyze verify <FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>
- nginx -t
- bash <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>
- powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_NGINX_WINDOWS_PREFLIGHT_SCRIPT>
- npm run flowchain:public-rpc:validate
- npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked
- npm run flowchain:public-rpc:abuse-test
- npm run flowchain:tester:gateway:e2e
- npm run flowchain:wallet:live-tester:e2e
- npm run flowchain:public-deployment:contract -- -AllowBlocked
- npm run flowchain:live:cutover:rehearsal -- -AllowBlocked
- npm run flowchain:truth-table -- -AllowBlocked
- npm run flowchain:no-secret:scan

## Rendered Artifact Manifest

- nginx-flowchain-rpc.conf: role=public-rpc-nginx-edge, target=/etc/nginx/conf.d/flowchain-rpc.conf, sha256=d58192516e75e79d43d7398ce20fde31f2abe1a0e9619627c69938e08d3fc081
- flowchain-live.service: role=block-producer-systemd-unit, target=/etc/systemd/system/flowchain-live.service, sha256=d8d2e250a3b743e362396d2e2af302a0ec2c500847f9628480ed0d8d8ac7da23
- flowchain-supervisor.service: role=autorecovery-supervisor-systemd-unit, target=/etc/systemd/system/flowchain-supervisor.service, sha256=43e7bb7c0793552f14a41374285eb321a65477c0e8634a3859a7f8ee9ba4c582
- nginx-preflight.sh: role=linux-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh, sha256=91444c4ad3479bb04b8693a4c2a6f843cc342351b578f12b640225e41f503fa4
- nginx-preflight.ps1: role=windows-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.ps1, sha256=a3b7fc41cd11daad0423f37a987dfbe6a1289bfedaec652e7b7133b5d0736da5
- public-rpc-render-report.json: role=render-evidence, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/public-rpc-render-report.json, sha256=5ad27b6388f784371d83934cab3955868a4b6f83eb71c2e530cdee164ab8634d
- owner-host-apply.sh: role=owner-host-apply-script, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh, sha256=4c7752a4c5fc8b543398d6e789563073cc440fc92b7204076c57d0dcea3c3fc9

## Owner Host Apply Phases

- render-owner-files: mutatesHost=False
- preflight-rendered-artifacts: mutatesHost=False
- install-systemd-services: mutatesHost=True
- publish-nginx-edge: mutatesHost=True
- post-deploy-proof: mutatesHost=False
- rollback-ready: mutatesHost=False
