# FlowChain Windows Backup Install

Generated: 2026-05-17T15:19:33.5586850Z
Status: passed
Action: Plan
Task: \FlowChainStateBackup

This runbook registers a Windows Scheduled Task that runs the manifest-backed state backup command every day. The task requires FLOWCHAIN_RPC_STATE_BACKUP_PATH from the owner process environment or from FLOWCHAIN_OWNER_ENV_FILE.

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
- Owner env file injected: False

## Status

- Task existed before: False
- Task exists after: False
- Scheduler cmdlets available: True
- WorkingDirectory supported: True
