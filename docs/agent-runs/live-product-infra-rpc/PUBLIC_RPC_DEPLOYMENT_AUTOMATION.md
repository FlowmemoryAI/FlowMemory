# FlowChain Public RPC Deployment Automation

Generated: 2026-05-21T10:56:48.0741764Z
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

- nginx-flowchain-rpc.conf: role=public-rpc-nginx-edge, target=/etc/nginx/conf.d/flowchain-rpc.conf, sha256=ab79fdb1133525e70a1c20884e6b6b8e3b0eb6c7ca937e7837253063516c326d
- flowchain-live.service: role=block-producer-systemd-unit, target=/etc/systemd/system/flowchain-live.service, sha256=5283636fcf4293475fb13b3d72bcc0c4a02ba82709e80bc4d1c1da400656e252
- flowchain-supervisor.service: role=autorecovery-supervisor-systemd-unit, target=/etc/systemd/system/flowchain-supervisor.service, sha256=62505c2aa33b60fdcb9d07b173e73b0c8962b7d503ac62d726b7254ce4688c00
- nginx-preflight.sh: role=linux-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh, sha256=c3048160bcf6767592e1510a5353080637f7cb6f34f84f173c5da0678375d41d
- nginx-preflight.ps1: role=windows-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.ps1, sha256=fb2d44d4c77e48211976264f2ccff8c3e4cf5c211c3c9257ad1fbde1de42d5fe
- public-rpc-render-report.json: role=render-evidence, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/public-rpc-render-report.json, sha256=c3546861d097613abc8a1d3cefed387d13b9c3070e774b0ec87ad504e92f4aff
- owner-host-apply.sh: role=owner-host-apply-script, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh, sha256=ceca83af90e9e2fb03768aebc9f390da45d0ee7d9d8b14c5416b1a1006a3a163
- owner-host-apply.ps1: role=windows-owner-host-apply-script, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1, sha256=f02842d6654b65edf009113a6dfbbc04e2d28b5afaac4e504b9b18c06971ae38

## Owner Host Apply Phases

- render-owner-files: mutatesHost=False
- preflight-rendered-artifacts: mutatesHost=False
- install-systemd-services: mutatesHost=True
- publish-nginx-edge: mutatesHost=True
- post-deploy-proof: mutatesHost=False
- rollback-ready: mutatesHost=False
