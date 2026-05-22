# FlowChain Public RPC Deployment Automation

Generated: 2026-05-22T00:51:29.1848704Z
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
- commandPlanIncludesOpsLaunchWatch: True
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
- renderedNginxHasTimeoutGuardrails: True
- renderedNginxAuthorizationForwardingScoped: True
- renderedSystemdUsesOwnerEnv: True
- renderedPreflightHasReadinessProbe: True
- renderedPreflightHasTesterUnauthProbe: True
- renderedPreflightHasDisallowedOriginProbe: True
- renderedPreflightChecksSecurityHeaders: True
- renderedPreflightChecksTimeoutGuardrails: True
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
- npm run flowchain:no-secret:scan
- npm run flowchain:ops:launch-watch -- -NoRefresh
- npm run flowchain:truth-table -- -AllowBlocked

## Rendered Artifact Manifest

- nginx-flowchain-rpc.conf: role=public-rpc-nginx-edge, target=/etc/nginx/conf.d/flowchain-rpc.conf, sha256=efc2eff89b0afd0e251a793eda36478fe01b1a2432bd63c355801933368921f8
- flowchain-live.service: role=block-producer-systemd-unit, target=/etc/systemd/system/flowchain-live.service, sha256=cf0442192086124f5e300979ff189a0034884400806ae77ed6822f0fc56fa903
- flowchain-supervisor.service: role=autorecovery-supervisor-systemd-unit, target=/etc/systemd/system/flowchain-supervisor.service, sha256=580915ec544937dc90d79f74045b1b685a93e5018c05f13ed745ad9e6a32bbb8
- nginx-preflight.sh: role=linux-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.sh, sha256=dad0928742f7411d8d7be7b2b02e2e930d00f985804766b7738a12ed1d348798
- nginx-preflight.ps1: role=windows-public-rpc-preflight, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/nginx-preflight.ps1, sha256=0b4c8d76feb51d335c4cffcacd40e0f476dedf3c4b1f469629e3f884965a6540
- public-rpc-render-report.json: role=render-evidence, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/public-rpc-render-report.json, sha256=28576a56a6df0fb182c95098886894e8f87327a2ae1631b15e4caa37f1344be8
- owner-host-apply.sh: role=owner-host-apply-script, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh, sha256=9a534c23301cb5f22253c9440d5dd52a163a4748cf63c2c987b9af8e3f2efa91
- owner-host-apply.ps1: role=windows-owner-host-apply-script, target=<FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1, sha256=634106d0885d966eca56696cd6c68622d992ba847e704ae6a92209722b4e9bce

## Owner Host Apply Phases

- render-owner-files: mutatesHost=False
- preflight-rendered-artifacts: mutatesHost=False
- install-systemd-services: mutatesHost=True
- publish-nginx-edge: mutatesHost=True
- post-deploy-proof: mutatesHost=False
- rollback-ready: mutatesHost=False
