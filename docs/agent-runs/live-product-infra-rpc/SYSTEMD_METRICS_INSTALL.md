# FlowChain Systemd Metrics Install

Generated: 2026-05-21T17:47:29.4213809Z
Status: passed
Action: Plan

This script installs, checks, or removes a Linux systemd timer that refreshes no-secret ops metrics JSON and Prometheus textfile outputs on a fixed interval. It writes local metrics only and does not store external delivery credentials.

## Commands

- plan: `npm run flowchain:ops:metrics:install:systemd -- -Action Plan`
- validate: `npm run flowchain:ops:metrics:install:systemd:validate`
- install: `npm run flowchain:ops:metrics:install:systemd -- -Action Install`
- status: `npm run flowchain:ops:metrics:install:systemd -- -Action Status`
- uninstall: `npm run flowchain:ops:metrics:install:systemd -- -Action Uninstall`
- metrics: `npm run flowchain:ops:metrics:export -- -AllowBlocked`
- journal: `journalctl -u flowchain-ops-metrics.service -u flowchain-ops-metrics.timer --since -1h --no-pager`

## Units

- Service: `flowchain-ops-metrics.service`
- Timer: `flowchain-ops-metrics.timer`
- Interval minutes: 5
- Owner env file injected: True

## Checks

- unitNamesValid: True
- metricsScriptExists: True
- intervalMinutesValid: True
- serviceUnitIncludesMetricsScript: True
- serviceUnitUsesOneshot: True
- serviceUnitUsesRepoWorkingDirectory: True
- serviceUnitHasAllowBlocked: True
- serviceUnitHasReportPath: True
- serviceUnitHasMarkdownPath: True
- serviceUnitHasMetricsJsonPath: True
- serviceUnitHasPrometheusTextPath: True
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
