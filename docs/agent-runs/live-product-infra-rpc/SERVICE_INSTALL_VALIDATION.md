# FlowChain Service Install Validation

Generated: 2026-05-21T10:55:25.7399046Z
Status: passed

This validation proves the Windows Scheduled Task install path is planned, no-secret, live-profile by default, non-mutating in plan/status mode, and has a safe absent-task uninstall no-op.

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
- triggerModeBothByDefault: True
- triggerIncludesStartup: True
- triggerIncludesLogon: True
- rebootPersistentTrigger: True
- bridgeRelayerOptInPlanCommandPassed: True
- bridgeRelayerOptInPlanDidNotMutate: True
- bridgeRelayerOptInStartsLoop: True
- bridgeRelayerOptInAddsSupervisorFlag: True
- bridgeRelayerOptInUsesSupervisor: True
- bridgeRelayerOptInKeepsBothTriggers: True
- hasIntervalSeconds: True
- hasMaxRestartAttempts: True
- hasMaxStateAgeSeconds: True
- commandOmitsNonLiveProfile: True
- statusCommandPassed: True
- statusActionReadOnly: True
- statusDidNotMutate: True
- statusTaskExistsStable: True
- statusReportNoSecrets: True
- statusReportEnvValuesPrintedFalse: True
- statusReportBroadcastsFalse: True
- uninstallAbsentPreflightTaskAbsent: True
- uninstallAbsentCommandPassed: True
- uninstallAbsentTaskCommandPassed: True
- uninstallAbsentTaskWasAbsentBefore: True
- uninstallAbsentDidNotCreateTask: True
- uninstallAbsentTaskAbsentAfter: True
- uninstallAbsentDidNotRemoveTask: True
- uninstallAbsentTaskRemovedFalse: True
- uninstallAbsentReportNoSecrets: True
- uninstallAbsentReportEnvValuesPrintedFalse: True
- uninstallAbsentReportBroadcastsFalse: True
- commandsPresent: True
- envValuesPrintedFalse: True
- childReportsNoSecrets: True
- childReportsSecretMarkerFindingsEmpty: True
- secretMarkerFindingsEmpty: True
- noSecrets: True
- broadcastsFalse: True

## Commands

- plan: npm run flowchain:service:install:windows -- -Action Plan
- install: npm run flowchain:service:install:windows -- -Action Install
- status: npm run flowchain:service:install:windows -- -Action Status
- uninstall: npm run flowchain:service:install:windows -- -Action Uninstall
- validate: npm run flowchain:service:install:validate
