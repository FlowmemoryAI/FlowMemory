# FlowChain Alert Install Validation

Generated: 2026-05-21T10:56:05.1308999Z
Status: passed

This validation proves the scheduled alert refresh path is planned, status-checkable, absent-uninstall safe, no-secret, non-mutating in read-only/no-op modes, and refreshes local alert evidence without external delivery. It covers both Windows Scheduled Task and Linux systemd timer paths.

## Checks

- installScriptExists: True
- systemdInstallScriptExists: True
- systemdValidationScriptExists: True
- alertsScriptExists: True
- packageScriptsPresent: True
- planCommandPassed: True
- planDidNotMutate: True
- statusCommandPassed: True
- statusDidNotMutate: True
- statusTaskStatePreserved: True
- uninstallAbsentCommandPassed: True
- uninstallAbsentDidNotMutate: True
- uninstallAbsentTaskAbsentBefore: True
- uninstallAbsentTaskAbsentAfter: True
- schedulerCmdletsAvailable: True
- scheduledTaskActionSupportsWorkingDirectory: True
- scheduledTaskTriggerSupportsRepetition: True
- actionUsesAlertsScript: True
- actionUsesRepoWorkingDirectory: True
- hasAllowBlocked: True
- hasReportPath: True
- hasMarkdownPath: True
- hasOpsSnapshotPath: True
- noExternalDelivery: True
- commandsPresent: True
- scheduledCommandKeepsBlockedAlertsVisible: True
- scheduledCommandDoesNotDisableRefresh: True
- systemdValidationCommandPassed: True
- systemdValidationPassed: True
- systemdPlanDidNotMutate: True
- systemdServiceUnitPlanned: True
- systemdTimerUnitPlanned: True
- systemdTimerIntervalConfigured: True
- systemdOwnerEnvFileInjectable: True
- systemdNoExternalDelivery: True
- systemdChildReportNoSecrets: True
- envValuesPrintedFalse: True
- childReportsNoSecrets: True
- childReportsSecretMarkerFindingsEmpty: True
- secretMarkerFindingsEmpty: True
- noSecrets: True
- broadcastsFalse: True

## Commands

- plan: npm run flowchain:ops:alerts:install:windows -- -Action Plan
- systemdPlan: npm run flowchain:ops:alerts:install:systemd -- -Action Plan
- systemdValidate: npm run flowchain:ops:alerts:install:systemd:validate
- install: npm run flowchain:ops:alerts:install:windows -- -Action Install
- status: npm run flowchain:ops:alerts:install:windows -- -Action Status
- uninstall: npm run flowchain:ops:alerts:install:windows -- -Action Uninstall
- validate: npm run flowchain:ops:alerts:install:validate
