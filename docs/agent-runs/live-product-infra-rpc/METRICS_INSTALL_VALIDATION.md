# FlowChain Metrics Install Validation

Generated: 2026-05-20T14:12:58.8606448Z
Status: passed

This validation proves the scheduled metrics export path is planned, status-checkable, absent-uninstall safe, no-secret, non-mutating in read-only/no-op modes, and refreshes local JSON plus Prometheus textfile metrics without external delivery. It covers both Windows Scheduled Task and Linux systemd timer paths.

## Checks

- installScriptExists: True
- systemdInstallScriptExists: True
- systemdValidationScriptExists: True
- metricsScriptExists: True
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
- actionUsesMetricsScript: True
- actionUsesRepoWorkingDirectory: True
- hasAllowBlocked: True
- hasReportPath: True
- hasMarkdownPath: True
- hasMetricsJsonPath: True
- hasPrometheusTextPath: True
- noExternalDelivery: True
- commandsPresent: True
- scheduledCommandKeepsBlockedMetricsVisible: True
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

- plan: npm run flowchain:ops:metrics:install:windows -- -Action Plan
- systemdPlan: npm run flowchain:ops:metrics:install:systemd -- -Action Plan
- systemdValidate: npm run flowchain:ops:metrics:install:systemd:validate
- install: npm run flowchain:ops:metrics:install:windows -- -Action Install
- status: npm run flowchain:ops:metrics:install:windows -- -Action Status
- uninstall: npm run flowchain:ops:metrics:install:windows -- -Action Uninstall
- validate: npm run flowchain:ops:metrics:install:validate
