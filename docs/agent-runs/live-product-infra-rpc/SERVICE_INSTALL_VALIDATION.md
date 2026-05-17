# FlowChain Service Install Validation

Generated: 2026-05-17T16:24:09.2069534Z
Status: passed

This validation proves the Windows Scheduled Task install path is planned, no-secret, live-profile by default, and non-mutating when run in plan mode.

## Checks

- installScriptExists: True
- supervisorScriptExists: True
- packageScriptsPresent: True
- planCommandPassed: True
- planDidNotMutate: True
- schedulerCmdletsAvailable: True
- scheduledTaskActionSupportsWorkingDirectory: True
- actionUsesSupervisor: True
- actionUsesRepoWorkingDirectory: True
- liveProfileDefault: True
- noBridgeRelayerDefault: True
- hasIntervalSeconds: True
- hasMaxRestartAttempts: True
- hasMaxStateAgeSeconds: True
- commandOmitsNonLiveProfile: True
- commandsPresent: True
- envValuesPrintedFalse: True
- noSecrets: True
- broadcastsFalse: True

## Commands

- plan: npm run flowchain:service:install:windows -- -Action Plan
- install: npm run flowchain:service:install:windows -- -Action Install
- status: npm run flowchain:service:install:windows -- -Action Status
- uninstall: npm run flowchain:service:install:windows -- -Action Uninstall
- validate: npm run flowchain:service:install:validate
