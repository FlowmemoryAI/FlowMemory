# FlowChain Public RPC Canary Schedule Validation

Generated: 2026-05-21T17:53:54.9014765Z
Status: passed

This validation renders no-secret Windows Scheduled Task and Linux systemd timer plans for recurring read-only public RPC synthetic canary checks. It does not register tasks, mutate host services, send external notifications, or store owner endpoint values.

## Commands

- validate: npm run flowchain:public-rpc:canary:schedule:validate
- canary: npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked
- windowsPlan: Register Windows Scheduled Task FlowChainPublicRpcSyntheticCanary using the rendered action in this report
- systemdPlan: Install flowchain-public-rpc-canary.service and flowchain-public-rpc-canary.timer from the rendered units in this report
- status: Check the Windows task or systemd timer, then inspect docs/agent-runs/live-product-infra-rpc/scheduled-public-rpc-synthetic-canary-report.json

## Checks

- packageScriptPresent: True
- syntheticCanaryPackageScriptPresent: True
- canaryScriptExists: True
- canaryScriptReadOnlyPlan: True
- intervalMinutesValid: True
- scheduledReportPathInsideRepo: True
- scheduledMarkdownPathInsideRepo: True
- windowsPlanRendered: True
- windowsPlanUsesCanaryScript: True
- windowsPlanUsesOwnerEnvFile: True
- windowsPlanHasAllowBlocked: True
- windowsPlanHasReportPath: True
- windowsPlanHasMarkdownPath: True
- windowsPlanUsesRepoWorkingDirectory: True
- windowsPlanDoesNotMutateHost: True
- systemdServiceRendered: True
- systemdServiceUsesOneshot: True
- systemdServiceUsesOwnerEnvFile: True
- systemdServiceHasAllowBlocked: True
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
