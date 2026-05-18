# FlowChain Backup Install Validation

Generated: 2026-05-17T16:34:53.5299737Z
Status: passed

This validation proves the scheduled backup install path is planned, no-secret, non-mutating in plan mode, and fails closed unless the owner backup path env is configured for actual backup runs.

## Checks

- installScriptExists: True
- backupScriptExists: True
- packageScriptsPresent: True
- planCommandPassed: True
- planDidNotMutate: True
- schedulerCmdletsAvailable: True
- scheduledTaskActionSupportsWorkingDirectory: True
- actionUsesBackupScript: True
- actionUsesRepoWorkingDirectory: True
- hasStatePath: True
- hasReportPath: True
- ownerBackupEnvRequired: True
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
