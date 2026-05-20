# FlowChain Public RPC Deployment Automation

Generated: 2026-05-20T00:03:48.8616442Z
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
- npm run flowchain:public-rpc:abuse-test
- npm run flowchain:public-deployment:contract -- -AllowBlocked
