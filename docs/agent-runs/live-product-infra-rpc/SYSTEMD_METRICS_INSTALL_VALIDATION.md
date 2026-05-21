# FlowChain Systemd Metrics Install Validation

Generated: 2026-05-21T10:56:25.6328759Z
Status: passed

This validation proves the Linux systemd timer path for recurring ops metrics export is present, no-secret, non-mutating in Plan mode, and writes only local JSON plus Prometheus textfile metrics.

## Checks

- installScriptExists: True
- metricsScriptExists: True
- installPackageScriptPresent: True
- validationPackageScriptPresent: True
- parentValidationPackageScriptPresent: True
- exportPackageScriptPresent: True
- planCommandPassed: True
- planReportWritten: True
- planReportPassed: True
- planActionReadOnly: True
- planDidNotMutate: True
- serviceUnitPlanned: True
- serviceUnitHasAllowBlocked: True
- serviceUnitHasReportPaths: True
- serviceUnitOwnerEnvFileInjectable: True
- serviceUnitHardeningPresent: True
- timerUnitPlanned: True
- timerUnitIntervalConfigured: True
- noExternalDelivery: True
- commandPlanPresent: True
- planReportEnvValuesPrintedFalse: True
- planReportNoSecrets: True
- planReportBroadcastsFalse: True
- envValuesPrintedFalse: True
- secretMarkerFindingsEmpty: True
- noSecrets: True
- broadcastsFalse: True

## Commands

- plan: npm run flowchain:ops:metrics:install:systemd -- -Action Plan
- install: npm run flowchain:ops:metrics:install:systemd -- -Action Install
- status: npm run flowchain:ops:metrics:install:systemd -- -Action Status
- uninstall: npm run flowchain:ops:metrics:install:systemd -- -Action Uninstall
- validate: npm run flowchain:ops:metrics:install:systemd:validate
