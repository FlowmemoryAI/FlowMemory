# FlowChain Systemd Backup Install Validation

Generated: 2026-05-19T12:39:49.1978446Z
Status: passed

This validation proves the Linux systemd timer path for recurring state backup and restore-drill verification is present, no-secret, non-mutating in Plan mode, and fails closed until the owner backup path env is configured.

## Checks

- installScriptExists: True
- backupScriptExists: True
- restoreDrillScriptExists: True
- installPackageScriptPresent: True
- validationPackageScriptPresent: True
- parentValidationPackageScriptPresent: True
- planCommandPassed: True
- planReportWritten: True
- planReportPassed: True
- planActionReadOnly: True
- planDidNotMutate: True
- backupServiceUnitPlanned: True
- backupServiceOmitsAllowBlocked: True
- backupServiceHasRetentionCount: True
- backupTimerUnitPlanned: True
- backupTimerCalendarConfigured: True
- restoreDrillServiceUnitPlanned: True
- restoreDrillServiceOmitsAllowBlocked: True
- restoreDrillTimerUnitPlanned: True
- restoreDrillTimerCalendarConfigured: True
- servicesOwnerEnvFileInjectable: True
- servicesHardeningPresent: True
- backupRootWritePathConfigurable: True
- ownerBackupEnvRequiredByRuntime: True
- restoreDrillOwnerBackupEnvRequiredByRuntime: True
- commandPlanPresent: True
- planReportEnvValuesPrintedFalse: True
- planReportNoSecrets: True
- planReportBroadcastsFalse: True
- envValuesPrintedFalse: True
- secretMarkerFindingsEmpty: True
- noSecrets: True
- broadcastsFalse: True

## Commands

- plan: npm run flowchain:backup:install:systemd -- -Action Plan
- install: npm run flowchain:backup:install:systemd -- -Action Install
- status: npm run flowchain:backup:install:systemd -- -Action Status
- uninstall: npm run flowchain:backup:install:systemd -- -Action Uninstall
- validate: npm run flowchain:backup:install:systemd:validate
