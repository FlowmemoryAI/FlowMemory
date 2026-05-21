# FlowChain Public RPC Deployment Automation

Generated: 2026-05-21T01:47:06.8564712Z
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

- nginx-flowchain-rpc.conf: role=public-rpc-nginx-edge, target=/etc/nginx/conf.d/flowchain-rpc.conf, sha256=59a07f3c423810bd68d3bbc082ccf38d15615b620edb793b9b84e53323556e06
- flowchain-live.service: role=block-producer-systemd-unit, target=/etc/systemd/system/flowchain-live.service, sha256=1e926d409e65fecdafff6a5b019ac12dea548fe90bba8f5f888ecd3414d579d1
- flowchain-supervisor.service: role=autorecovery-supervisor-systemd-unit, target=/etc/systemd/system/flowchain-supervisor.service, sha256=256e40b39d17c1f9b42ac1b344c2f28c90207edd0be5bb3f71466d3002c326b3
- nginx-preflight.sh: role=linux-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh, sha256=6cbf808f13109353c7aa7ec7b48465a639d965a1ef209ab8b2fa8ffb4381bae0
- nginx-preflight.ps1: role=windows-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.ps1, sha256=1126e778be3ca6256bc3f1c985b3e750e8a07baff60f2f908258688a303f191b
- public-rpc-render-report.json: role=render-evidence, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/public-rpc-render-report.json, sha256=c8f3dee71c5609c1f378143a7e6c35fd6add305cdfcc13c6815ca0788d4e78ce
- owner-host-apply.sh: role=owner-host-apply-script, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh, sha256=a3f3211f4c72495f779980ab3e14fe6658adba72c19c560151218effb69572cc

## Owner Host Apply Phases

- render-owner-files: mutatesHost=False
- preflight-rendered-artifacts: mutatesHost=False
- install-systemd-services: mutatesHost=True
- publish-nginx-edge: mutatesHost=True
- post-deploy-proof: mutatesHost=False
- rollback-ready: mutatesHost=False
