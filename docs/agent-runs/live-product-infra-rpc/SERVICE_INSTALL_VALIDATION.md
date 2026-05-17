# FlowChain Service Install Validation

Generated: 2026-05-17T19:30:20.6553366Z
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
- bridgeRelayerOptInPlanCommandPassed: True
- bridgeRelayerOptInPlanDidNotMutate: True
- bridgeRelayerOptInStartsLoop: True
- bridgeRelayerOptInAddsSupervisorFlag: True
- bridgeRelayerOptInUsesSupervisor: True
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
