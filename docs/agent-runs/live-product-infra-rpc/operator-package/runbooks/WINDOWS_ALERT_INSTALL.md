# FlowChain Windows Alert Install

Generated: 2026-05-21T10:55:50.1093183Z
Status: passed
Action: Plan
Task: \FlowChainOpsAlerts

This runbook registers a Windows Scheduled Task that refreshes the no-secret ops snapshot and alert rules on a fixed interval. It writes local reports only and does not store external delivery credentials.

## Commands

- Plan: npm run flowchain:ops:alerts:install:windows -- -Action Plan
- Validate: npm run flowchain:ops:alerts:install:validate
- Install: npm run flowchain:ops:alerts:install:windows -- -Action Install
- Status: npm run flowchain:ops:alerts:install:windows -- -Action Status
- Uninstall: npm run flowchain:ops:alerts:install:windows -- -Action Uninstall
- Alerts: npm run flowchain:ops:alerts -- -AllowBlocked

## Scheduled Task Action

- Execute: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- Working directory: `E:/FlowMemory/flowmemory-live-infra-rpc`
- Alerts script: `E:\FlowMemory\flowmemory-live-infra-rpc\infra\scripts\flowchain-ops-alerts.ps1`
- Interval minutes: 15
- Owner env file injected: False

## Status

- Task existed before: False
- Task exists after: False
- Scheduler cmdlets available: True
- WorkingDirectory supported: True
- Repetition supported: True
