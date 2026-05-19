# FlowChain Backup Install Validation

Generated: 2026-05-19T02:17:17.4258914Z
Status: passed

This validation proves the scheduled backup install path is planned, no-secret, non-mutating in plan mode, rotates snapshots by retention count, schedules a recurring restore drill, and fails closed unless the owner backup path env is configured for actual backup and restore runs.

## Checks

- installScriptExists: True
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

## Commands

- plan: npm run flowchain:backup:install:windows -- -Action Plan
- install: npm run flowchain:backup:install:windows -- -Action Install
- status: npm run flowchain:backup:install:windows -- -Action Status
- uninstall: npm run flowchain:backup:install:windows -- -Action Uninstall
- validate: npm run flowchain:backup:install:validate
