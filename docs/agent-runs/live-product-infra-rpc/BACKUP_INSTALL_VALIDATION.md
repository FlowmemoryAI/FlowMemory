# FlowChain Backup Install Validation

Generated: 2026-05-21T02:14:09.0890404Z
Status: passed

This validation proves the Windows Scheduled Task and Linux systemd timer install paths are planned, no-secret, non-mutating in plan mode, rotate snapshots by retention count, schedule recurring restore drills, and fail closed unless the owner backup path env is configured for actual backup and restore runs.

## Checks

- installScriptExists: True
- systemdInstallScriptExists: True
- systemdValidationScriptExists: True
- backupScriptExists: True
- restoreDrillScriptExists: True
- packageScriptsPresent: True
- planCommandPassed: True
- planDidNotMutate: True
- schedulerCmdletsAvailable: True
- scheduledTaskActionSupportsWorkingDirectory: True
- taskNamesDistinct: True
- retentionCountValid: True
- actionUsesBackupScript: True
- actionUsesRetentionCount: True
- actionUsesRepoWorkingDirectory: True
- hasStatePath: True
- hasReportPath: True
- restoreDrillUsesRestoreScript: True
- restoreDrillUsesRepoWorkingDirectory: True
- restoreDrillHasRestoreRoot: True
- restoreDrillHasStatePath: True
- restoreDrillHasReportPath: True
- ownerBackupEnvRequired: True
- restoreDrillOwnerBackupEnvRequired: True
- commandsPresent: True
- commandOmitsAllowBlocked: True
- envValuesPrintedFalse: True
- noSecrets: True
- broadcastsFalse: True
- systemdValidationCommandPassed: True
- systemdValidationPassed: True
- systemdFailedChecksEmpty: True
- systemdPlanDidNotMutate: True
- systemdBackupServiceUnitPlanned: True
- systemdBackupTimerUnitPlanned: True
- systemdRestoreServiceUnitPlanned: True
- systemdRestoreTimerUnitPlanned: True
- systemdCommandOmitsAllowBlocked: True
- systemdOwnerBackupEnvRequired: True
- systemdOwnerEnvInjectable: True
- systemdServicesHardeningPresent: True
- systemdBackupRootWritePathConfigurable: True
- systemdChildReportNoSecrets: True

## Commands

- plan: npm run flowchain:backup:install:windows -- -Action Plan
- systemdPlan: npm run flowchain:backup:install:systemd -- -Action Plan
- install: npm run flowchain:backup:install:windows -- -Action Install
- systemdInstall: npm run flowchain:backup:install:systemd -- -Action Install
- status: npm run flowchain:backup:install:windows -- -Action Status
- systemdStatus: npm run flowchain:backup:install:systemd -- -Action Status
- uninstall: npm run flowchain:backup:install:windows -- -Action Uninstall
- systemdUninstall: npm run flowchain:backup:install:systemd -- -Action Uninstall
- systemdValidate: npm run flowchain:backup:install:systemd:validate
- validate: npm run flowchain:backup:install:validate
