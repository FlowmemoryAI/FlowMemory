# FlowChain Windows Backup Install

Generated: 2026-05-19T14:24:39.7984019Z
Status: passed
Action: Plan
Backup task: \FlowChainStateBackup
Restore drill task: \FlowChainStateRestoreDrill

This runbook registers Windows Scheduled Tasks that run the manifest-backed state backup command every day, rotate old snapshots by retention count, and run a recurring restore drill against the latest snapshot. The tasks require FLOWCHAIN_RPC_STATE_BACKUP_PATH from the owner process environment or from FLOWCHAIN_OWNER_ENV_FILE.

## Commands

- Plan: npm run flowchain:backup:install:windows -- -Action Plan
- Validate: npm run flowchain:backup:install:validate
- Install: npm run flowchain:backup:install:windows -- -Action Install
- Status: npm run flowchain:backup:install:windows -- -Action Status
- Uninstall: npm run flowchain:backup:install:windows -- -Action Uninstall
- Backup check: npm run flowchain:backup:check -- -AllowBlocked

## Scheduled Task Action

- Execute: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- Working directory: `E:/FlowMemory/flowmemory-live-infra-rpc`
- Backup script: `E:\FlowMemory\flowmemory-live-infra-rpc\infra\scripts\flowchain-state-backup.ps1`
- Daily time: 03:00
- Retention count: 14
- Restore drill script: `E:\FlowMemory\flowmemory-live-infra-rpc\infra\scripts\flowchain-state-restore-verify.ps1`
- Restore drill daily time: 03:15
- Owner env file injected: False

## Status

- Task existed before: False
- Task exists after: False
- Restore drill task existed before: False
- Restore drill task exists after: False
- Scheduler cmdlets available: True
- WorkingDirectory supported: True
