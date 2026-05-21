# FlowChain Public RPC Deployment Bundle

Generated: 2026-05-21T02:05:49.1753061Z
Status: passed

This bundle packages placeholder-only files for an owner-operated HTTPS edge in front of the repo-owned private RPC origin `127.0.0.1:8787`.

## Files

- README.md
- nginx-flowchain-rpc.template.conf
- flowchain-live.service.template
- flowchain-supervisor.service.template
- render-public-rpc-bundle.template.ps1
- nginx-preflight.template.sh
- NGINX_PREFLIGHT.md
- nginx-preflight.template.ps1
- WINDOWS_NGINX_PREFLIGHT.md
- owner-public-rpc.env.example
- VERIFY.md
- ROLLBACK.md
- bundle-checks.json

## Required Placeholders

- <FLOWCHAIN_RPC_PUBLIC_HOST>
- <FLOWCHAIN_RPC_PUBLIC_URL>
- <FLOWCHAIN_RPC_ALLOWED_ORIGIN>
- <FLOWCHAIN_RPC_DISALLOWED_ORIGIN>
- <FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE>
- <PATH_TO_TLS_CERTIFICATE>
- <PATH_TO_TLS_CERTIFICATE_KEY>
- <FLOWCHAIN_REPO_ABSOLUTE_PATH>
- <FLOWCHAIN_SERVICE_USER>
- <FLOWCHAIN_SERVICE_GROUP>
- <FLOWCHAIN_OWNER_ENV_FILE>
- <FLOWCHAIN_CONTROL_PLANE_CARGO_TARGET_DIR>
- <FLOWCHAIN_RPC_NGINX_RENDERED_CONF>
- <FLOWCHAIN_NGINX_EXE>
- <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>
- <FLOWCHAIN_NGINX_WINDOWS_PREFLIGHT_SCRIPT>
- <FLOWCHAIN_SYSTEMD_RENDERED_UNIT>
- <FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>
- <PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF>
- <FLOWCHAIN_DEPLOY_RENDER_DIR>

## Required Env Names

- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED
- FLOWCHAIN_RPC_STATE_BACKUP_PATH
- FLOWCHAIN_TESTER_WRITE_ENABLED
- FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256
- FLOWCHAIN_TESTER_MAX_SEND_UNITS

## Verification Commands

- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:supervisor -- -Once
- npm run flowchain:service:supervisor:validate
- npm run flowchain:service:install:systemd:validate
- npm run flowchain:service:status
- npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30
- npm run flowchain:ops:snapshot -- -AllowBlocked
- npm run flowchain:public-rpc:validate
- npm run flowchain:public-rpc:check
- npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked
- npm run flowchain:tester:gateway:e2e
- npm run flowchain:wallet:live-tester:e2e
- npm run flowchain:backup:restore:validate
- npm run flowchain:backup:check
- npm run flowchain:public-deployment:contract -- -AllowBlocked
- npm run flowchain:external-tester:packet -- -AllowBlocked
- npm run flowchain:live:cutover:rehearsal -- -AllowBlocked
- npm run flowchain:truth-table -- -AllowBlocked
- npm run flowchain:no-secret:scan

## Owner-Host Render Commands

- powershell -NoProfile -ExecutionPolicy Bypass -File render-public-rpc-bundle.template.ps1 -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -OwnerEnvFile <FLOWCHAIN_OWNER_ENV_FILE> -RepoRoot <FLOWCHAIN_REPO_ABSOLUTE_PATH> -ServiceUser <FLOWCHAIN_SERVICE_USER> -ServiceGroup <FLOWCHAIN_SERVICE_GROUP> -TlsCertificatePath <PATH_TO_TLS_CERTIFICATE> -TlsCertificateKeyPath <PATH_TO_TLS_CERTIFICATE_KEY> -NginxExe <FLOWCHAIN_NGINX_EXE>

## Owner-Host Preflight Commands

- npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>
- npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop
- systemd-analyze verify <FLOWCHAIN_SYSTEMD_RENDERED_UNIT>
- systemd-analyze verify <FLOWCHAIN_SUPERVISOR_SYSTEMD_RENDERED_UNIT>
- nginx -t
- bash <FLOWCHAIN_NGINX_PREFLIGHT_SCRIPT>
- powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_NGINX_WINDOWS_PREFLIGHT_SCRIPT>

## Rollback Commands

- npm run flowchain:ops:snapshot -- -AllowBlocked
- npm run flowchain:service:status
- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:stop
- npm run flowchain:emergency:stop-local
- systemctl stop flowchain-supervisor.service
- systemctl stop flowchain-live.service
- cp <PREVIOUS_FLOWCHAIN_RPC_NGINX_CONF> <FLOWCHAIN_RPC_NGINX_RENDERED_CONF>
- nginx -t
- systemctl reload nginx
- systemctl restart flowchain-live.service
- systemctl restart flowchain-supervisor.service

## Bundle Checks

- edgeTemplatePassed: True
- readmeWritten: True
- nginxTemplateWritten: True
- systemdServiceTemplateWritten: True
- systemdSupervisorTemplateWritten: True
- renderScriptWritten: True
- nginxPreflightScriptWritten: True
- nginxPreflightChecklistWritten: True
- windowsNginxPreflightScriptWritten: True
- windowsNginxPreflightChecklistWritten: True
- ownerEnvExampleWritten: True
- verifyRunbookWritten: True
- rollbackRunbookWritten: True
- bundleChecksJsonWritten: True
- requiredPlaceholdersPresent: True
- nginxRequiredTokensPresent: True
- systemdLiveServiceTemplatePresent: True
- systemdSupervisorTemplatePresent: True
- renderScriptTokensPresent: True
- nginxPreflightTokensPresent: True
- windowsNginxPreflightTokensPresent: True
- ownerRenderValidationPassed: True
- ownerRenderCommandPassed: True
- ownerRenderFilesHaveNoPlaceholders: True
- ownerRenderWritesShellPreflight: True
- ownerRenderWritesWindowsPreflight: True
- ownerRenderDoesNotPrintTokenHash: True
- ownerRenderFilesDoNotContainTokenHash: True
- ownerRenderIncludesSecurityHeaders: True
- ownerRenderPreflightsRejectWrongMethods: True
- ownerRenderRejectsPublicUrlPath: True
- ownerRenderPublicUrlPathRejectOutputNoSecrets: True
- includesPrivateOrigin: True
- includesRateLimitPlaceholder: True
- includesTlsPlaceholders: True
- includesSecurityHeaders: True
- preflightsCheckSecurityHeaders: True
- includesMethodRejectionPreflight: True
- includesCorsOriginForwarding: True
- publicStateMirrorExcluded: True
- devnetStatePublicRpcExcluded: True
- includesNginxConfigTest: True
- includesWindowsNginxConfigTest: True
- includesTesterWritePreflight: True
- includesDisallowedOriginPreflight: True
- includesBroadStateBlockedPreflight: True
- includesPrivateWalletCreateBlockedPreflight: True
- authorizationForwardingScopedToTesterWrite: True
- includesVerificationCommands: True
- includesRollbackCommands: True
- envExampleHasAllRequiredNames: True
- ownerEnvExampleValuesBlank: True
- noLiveBroadcastCommands: True
- noLiveBroadcastArtifacts: True
- valuesNotPrinted: True
- envValuesNotPrinted: True
- noSecrets: True
- secretMarkerFindingsEmpty: True
- liveBroadcastsDisabled: True
