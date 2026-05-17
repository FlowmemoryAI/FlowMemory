# FlowChain Alert Install Validation

Generated: 2026-05-17T16:24:18.6483945Z
Status: passed

This validation proves the scheduled alert refresh path is planned, no-secret, non-mutating in plan mode, and refreshes local alert evidence without external delivery.

## Checks

- installScriptExists: True
- alertsScriptExists: True
- packageScriptsPresent: True
- planCommandPassed: True
- planDidNotMutate: True
- schedulerCmdletsAvailable: True
- scheduledTaskActionSupportsWorkingDirectory: True
- scheduledTaskTriggerSupportsRepetition: True
- actionUsesAlertsScript: True
- actionUsesRepoWorkingDirectory: True
- hasAllowBlocked: True
- hasReportPath: True
- hasMarkdownPath: True
- hasOpsSnapshotPath: True
- noExternalDelivery: True
- commandsPresent: True
- scheduledCommandKeepsBlockedAlertsVisible: True
- scheduledCommandDoesNotDisableRefresh: True
- envValuesPrintedFalse: True
- noSecrets: True
- broadcastsFalse: True

## Commands

- plan: npm run flowchain:ops:alerts:install:windows -- -Action Plan
- install: npm run flowchain:ops:alerts:install:windows -- -Action Install
- status: npm run flowchain:ops:alerts:install:windows -- -Action Status
- uninstall: npm run flowchain:ops:alerts:install:windows -- -Action Uninstall
- validate: npm run flowchain:ops:alerts:install:validate
