# FlowChain Windows Metrics Install

Generated: 2026-05-21T17:47:12.1657561Z
Status: passed
Action: Plan
Task: \FlowChainOpsMetrics

This runbook registers a Windows Scheduled Task that refreshes no-secret ops metrics JSON and Prometheus textfile outputs on a fixed interval. It writes local metrics only and does not store external delivery credentials.

## Commands

- plan: npm run flowchain:ops:metrics:install:windows -- -Action Plan
- validate: npm run flowchain:ops:metrics:install:validate
- install: npm run flowchain:ops:metrics:install:windows -- -Action Install
- status: npm run flowchain:ops:metrics:install:windows -- -Action Status
- uninstall: npm run flowchain:ops:metrics:install:windows -- -Action Uninstall
- metrics: npm run flowchain:ops:metrics:export -- -AllowBlocked

## Scheduled Task Action

- Execute: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- Working directory: `E:/FlowMemory/flowmemory-live-infra-rpc`
- Metrics script: `E:\FlowMemory\flowmemory-live-infra-rpc\infra\scripts\flowchain-ops-metrics-export.ps1`
- Interval minutes: 5
- Owner env file injected: False

## Status

- Task existed before: False
- Task exists after: False
- Scheduler cmdlets available: True
- WorkingDirectory supported: True
- Repetition supported: True
