# FlowChain Systemd Service Install

Generated: 2026-05-19T09:40:47.1783539Z
Status: passed
Action: Plan

This script installs, checks, or removes the rendered FlowChain live-service and supervisor systemd units on a Linux owner host. Plan mode is read-only and is the validation path used by this repository.

## Commands

- render: `npm run flowchain:public-rpc:deployment:automation -- -Action Render -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -OwnerEnvFile <FLOWCHAIN_OWNER_ENV_FILE> -TlsCertificatePath <PATH_TO_TLS_CERTIFICATE> -TlsCertificateKeyPath <PATH_TO_TLS_CERTIFICATE_KEY> -NginxExe <FLOWCHAIN_NGINX_EXE>`
- verifyLive: `systemd-analyze verify <FLOWCHAIN_DEPLOY_RENDER_DIR>/flowchain-live.service`
- verifySupervisor: `systemd-analyze verify <FLOWCHAIN_DEPLOY_RENDER_DIR>/flowchain-supervisor.service`
- plan: `npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>`
- install: `npm run flowchain:service:install:systemd -- -Action Install -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR>`
- status: `npm run flowchain:service:install:systemd -- -Action Status`
- uninstall: `npm run flowchain:service:install:systemd -- -Action Uninstall`
- serviceStatus: `npm run flowchain:service:status`
- serviceMonitor: `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30`

## Checks

- bundleDirExists: True
- unitNamesValid: True
- renderDirProvided: 
- sourceModeRenderedWhenProvided: 
- liveSourceExists: True
- supervisorSourceExists: True
- liveServiceUsesLiveProfile: True
- liveServiceRunsStatusAfterStart: True
- liveServiceStopPreservesState: True
- liveServiceRestartOnFailure: True
- supervisorUsesAutorecoveryLoop: True
- supervisorRestartAlways: True
- bridgeRelayerDefaultOff: True
- ownerEnvFileUsed: True
- repoWorkingDirectoryUsed: True
- leastPrivilegeHardeningPresent: True
- writePathsScoped: True
- installTargetPresent: True
- planActionReadOnly: True
- statusActionReadOnly: True
- installRequiresRenderedUnits: True
- installRequiresSystemdHost: True
- uninstallRequiresSystemdHost: True
- systemctlAvailable: 
- systemdAnalyzeAvailable: 
- journalctlAvailable: 
- commandPlanPresent: True
- envValuesPrintedFalse: True
- noSecrets: True
- broadcastsFalse: True
- secretMarkerFindingsEmpty: True
