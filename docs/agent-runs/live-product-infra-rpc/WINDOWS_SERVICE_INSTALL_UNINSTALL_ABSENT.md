# FlowChain Windows Service Install

Generated: 2026-05-18T05:11:23.4803343Z
Status: passed
Action: Uninstall
Task: \FlowChainLiveSupervisor-ValidationAbsent

This runbook registers the live service supervisor as a Windows Scheduled Task at owner startup and logon by default. It keeps the private node and control-plane RPC recovered after reboot or logon, while preserving the private local origin.

## Commands

- Plan: npm run flowchain:service:install:windows -- -Action Plan
- Validate: npm run flowchain:service:install:validate
- Install: npm run flowchain:service:install:windows -- -Action Install
- Status: npm run flowchain:service:install:windows -- -Action Status
- Uninstall: npm run flowchain:service:install:windows -- -Action Uninstall

## Scheduled Task Action

- Execute: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- Working directory: `E:/FlowMemory/flowmemory-live-infra-rpc`
- Supervisor: `E:\FlowMemory\flowmemory-live-infra-rpc\infra\scripts\flowchain-service-supervisor.ps1`
- Trigger mode: Both
- Triggers: AtLogOn, AtStartup
- Bridge relayer loop enabled: False
- Live profile default: True

## Status

- Task existed before: False
- Task exists after: False
- Scheduler cmdlets available: True
- WorkingDirectory supported: True
