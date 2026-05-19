# FlowChain Systemd Alert Install Validation

Generated: 2026-05-19T14:20:23.2870459Z
Status: passed

This validation proves the Linux systemd timer path for recurring ops alert refresh is present, no-secret, non-mutating in Plan mode, and writes only local alert evidence.

## Checks

- installScriptExists: True
- alertsScriptExists: True
- installPackageScriptPresent: True
- validationPackageScriptPresent: True
- parentValidationPackageScriptPresent: True
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

- plan: npm run flowchain:ops:alerts:install:systemd -- -Action Plan
- install: npm run flowchain:ops:alerts:install:systemd -- -Action Install
- status: npm run flowchain:ops:alerts:install:systemd -- -Action Status
- uninstall: npm run flowchain:ops:alerts:install:systemd -- -Action Uninstall
- validate: npm run flowchain:ops:alerts:install:systemd:validate
