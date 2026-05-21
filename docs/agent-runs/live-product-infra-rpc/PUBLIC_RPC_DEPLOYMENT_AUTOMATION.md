# FlowChain Public RPC Deployment Automation

Generated: 2026-05-21T03:35:07.2182530Z
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
- renderedOwnerHostApplyPowerShellWritten: True
- renderedOwnerHostApplyScriptHasPlanApplyRollback: True
- renderedOwnerHostApplyPowerShellHasPlanApplyRollback: True
- renderedOwnerHostApplyPowerShellParses: True
- renderedOwnerHostApplyScriptVerifiesHashes: True
- renderedOwnerHostApplyPowerShellVerifiesHashes: True
- renderedOwnerHostApplyScriptRunsPostDeployProof: True
- renderedOwnerHostApplyPowerShellRunsPostDeployProof: True
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
- ownerHostApplyPlanIncludesWindowsOwnerApplyScript: True
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
- npm run flowchain:service:install:windows -- -Action Plan
- powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Plan
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

- nginx-flowchain-rpc.conf: role=public-rpc-nginx-edge, target=/etc/nginx/conf.d/flowchain-rpc.conf, sha256=90932da09b8653cd20f22fb8c847e9ec85d54d51e51999e3f127302971be38b1
- flowchain-live.service: role=block-producer-systemd-unit, target=/etc/systemd/system/flowchain-live.service, sha256=18b7dc444a21bc0d9f557a7352de8ac9348ea7909459105f66676a4a704216ef
- flowchain-supervisor.service: role=autorecovery-supervisor-systemd-unit, target=/etc/systemd/system/flowchain-supervisor.service, sha256=1de42388fddac453761597bb067ff779f60f71b7bdf629cfccc7cc8ced1d7434
- nginx-preflight.sh: role=linux-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh, sha256=cdec272c2662eec38a70c72f0738c1847f6e89b797e4e4e3f226a8dc2c715cfc
- nginx-preflight.ps1: role=windows-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.ps1, sha256=03773e4dd5322ce5485c2648eb5e5ace176f05da1046d6c05a9bb6fe193ef525
- public-rpc-render-report.json: role=render-evidence, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/public-rpc-render-report.json, sha256=313304f4964dc1d0769d975447d999d3d8415fd11560a0efd2b4ae153652820c
- owner-host-apply.sh: role=owner-host-apply-script, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh, sha256=4720c0dc0920c540786dca14ccac80fe956bcb7ebe9f00a46344156c32d145a2
- owner-host-apply.ps1: role=windows-owner-host-apply-script, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1, sha256=1a5982f38ec161fdb3ce81fc9d7741eeed0f68926c4fad3962f342f85d7bd2a0

## Owner Host Apply Phases

- render-owner-files: mutatesHost=False
- preflight-rendered-artifacts: mutatesHost=False
- install-systemd-services: mutatesHost=True
- publish-nginx-edge: mutatesHost=True
- post-deploy-proof: mutatesHost=False
- rollback-ready: mutatesHost=False
