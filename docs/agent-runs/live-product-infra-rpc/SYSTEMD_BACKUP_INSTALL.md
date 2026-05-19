# FlowChain Systemd Backup Install

Generated: 2026-05-19T14:24:42.0289494Z
Status: passed
Action: Plan

This script installs, checks, or removes Linux systemd timers for manifest-backed state backups and restore-drill verification. Plan mode is read-only and the scheduled units fail closed until the owner backup path env is configured.

## Commands

- plan: `npm run flowchain:backup:install:systemd -- -Action Plan`
- validate: `npm run flowchain:backup:install:systemd:validate`
- install: `npm run flowchain:backup:install:systemd -- -Action Install`
- status: `npm run flowchain:backup:install:systemd -- -Action Status`
- uninstall: `npm run flowchain:backup:install:systemd -- -Action Uninstall`
- backupCheck: `npm run flowchain:backup:check -- -AllowBlocked`
- journal: `journalctl -u flowchain-state-backup.service -u flowchain-state-backup.timer -u flowchain-state-restore-drill.service -u flowchain-state-restore-drill.timer --since -24h --no-pager`

## Units

- Backup service: `flowchain-state-backup.service`
- Backup timer: `flowchain-state-backup.timer` at `*-*-* 03:00:00`
- Restore drill service: `flowchain-state-restore-drill.service`
- Restore drill timer: `flowchain-state-restore-drill.timer` at `*-*-* 03:15:00`
- Retention count: 14
- Owner env file injected: True
- Backup root write path configured: True

## Checks

- unitNamesValid: True
- backupScriptExists: True
- restoreDrillScriptExists: True
- retentionCountValid: True
- backupServiceUsesOneshot: True
- backupServiceUsesBackupScript: True
- backupServiceHasStatePath: True
- backupServiceHasReportPath: True
- backupServiceHasRetentionCount: True
- backupServiceOmitsAllowBlocked: True
- restoreDrillServiceUsesOneshot: True
- restoreDrillServiceUsesRestoreScript: True
- restoreDrillServiceHasRestoreRoot: True
- restoreDrillServiceHasStatePath: True
- restoreDrillServiceHasReportPath: True
- restoreDrillServiceOmitsAllowBlocked: True
- servicesUseRepoWorkingDirectory: True
- servicesOwnerEnvFileInjectable: True
- servicesHardeningPresent: True
- servicesWritePathsScoped: True
- backupRootWritePathConfigurable: True
- backupTimerTargetsService: True
- restoreDrillTimerTargetsService: True
- backupTimerCalendarConfigured: True
- restoreDrillTimerCalendarConfigured: True
- backupTimerPersistent: True
- restoreDrillTimerPersistent: True
- timerInstallTargetsPresent: True
- ownerBackupEnvRequiredByRuntime: True
- restoreDrillOwnerBackupEnvRequiredByRuntime: True
- commandPlanPresent: True
- planActionReadOnly: True
- statusActionReadOnly: True
- installRequiresSystemdHost: True
- uninstallRequiresSystemdHost: True
- systemctlAvailable: <not-required-for-plan>
- journalctlAvailable: <not-required-for-plan>
- envValuesPrintedFalse: True
- noSecrets: True
- broadcastsFalse: True
- secretMarkerFindingsEmpty: True
