# FlowChain Bridge Reconciliation Schedule Validation

Generated: 2026-05-21T08:16:33.3147010Z
Status: passed

This validation renders no-secret Windows Scheduled Task and Linux systemd timer plans for recurring bridge reconciliation checks. It does not register tasks, mutate host services, send external notifications, or store owner values.

## Commands

- validate: npm run flowchain:bridge:reconciliation:schedule:validate
- reconciliation: npm run flowchain:bridge:reconciliation
- windowsPlan: Register Windows Scheduled Task FlowChainBridgeReconciliation using the rendered action in this report
- systemdPlan: Install flowchain-bridge-reconciliation.service and flowchain-bridge-reconciliation.timer from the rendered units in this report
- status: Check the Windows task or systemd timer, then inspect docs/agent-runs/live-product-infra-rpc/scheduled-bridge-reconciliation-report.json

## Checks

- packageScriptPresent: True
- reconciliationPackageScriptPresent: True
- reconciliationScriptExists: True
- reconciliationScriptReadsRelayerEvidence: True
- reconciliationScriptReadsRuntimeEvidence: True
- intervalMinutesValid: True
- scheduledReportPathInsideRepo: True
- scheduledMarkdownPathInsideRepo: True
- windowsPlanRendered: True
- windowsPlanUsesReconciliationScript: True
- windowsPlanUsesOwnerEnvFile: True
- windowsPlanHasReportPath: True
- windowsPlanHasMarkdownPath: True
- windowsPlanUsesRepoWorkingDirectory: True
- windowsPlanDoesNotMutateHost: True
- systemdServiceRendered: True
- systemdServiceUsesOneshot: True
- systemdServiceUsesOwnerEnvFile: True
- systemdServiceHasReportPath: True
- systemdServiceHasMarkdownPath: True
- systemdServiceHardeningPresent: True
- systemdServiceWritePathsScoped: True
- systemdTimerRendered: True
- systemdTimerPersistent: True
- systemdTimerIntervalConfigured: True
- noExternalDelivery: True
- hostMutationPerformedFalse: True
- envValuesPrintedFalse: True
- secretMarkerFindingsEmpty: True
- noSecrets: True
- broadcastsFalse: True
