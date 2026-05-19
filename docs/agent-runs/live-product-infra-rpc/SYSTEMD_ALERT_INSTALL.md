# FlowChain Systemd Alert Install

Generated: 2026-05-19T14:20:22.8767675Z
Status: passed
Action: Plan

This script installs, checks, or removes a Linux systemd timer that refreshes the no-secret ops snapshot and alert-rule reports on a fixed interval. It writes local reports only and does not store external delivery credentials.

## Commands

- plan: `npm run flowchain:ops:alerts:install:systemd -- -Action Plan`
- validate: `npm run flowchain:ops:alerts:install:systemd:validate`
- install: `npm run flowchain:ops:alerts:install:systemd -- -Action Install`
- status: `npm run flowchain:ops:alerts:install:systemd -- -Action Status`
- uninstall: `npm run flowchain:ops:alerts:install:systemd -- -Action Uninstall`
- alerts: `npm run flowchain:ops:alerts -- -AllowBlocked`
- journal: `journalctl -u flowchain-ops-alerts.service -u flowchain-ops-alerts.timer --since -1h --no-pager`

## Units

- Service: `flowchain-ops-alerts.service`
- Timer: `flowchain-ops-alerts.timer`
- Interval minutes: 15
- Owner env file injected: True

## Checks

- unitNamesValid: True
- alertsScriptExists: True
- intervalMinutesValid: True
- serviceUnitIncludesAlertsScript: True
- serviceUnitUsesOneshot: True
- serviceUnitUsesRepoWorkingDirectory: True
- serviceUnitHasAllowBlocked: True
- serviceUnitHasReportPath: True
- serviceUnitHasMarkdownPath: True
- serviceUnitHasOpsSnapshotPath: True
- serviceUnitHasNoExternalDelivery: True
- serviceUnitOwnerEnvFileInjectable: True
- serviceUnitHardeningPresent: True
- serviceUnitWritePathsScoped: True
- timerUnitTargetsService: True
- timerUnitPersistent: True
- timerUnitIntervalConfigured: True
- timerUnitInstallTarget: True
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
