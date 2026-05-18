# FlowChain Bridge Relayer Guardrail Validation

Generated: 2026-05-18T04:31:12.2070538Z
Status: passed

This validation proves a relayer run with missing owner Base 8453 inputs exits as an allowed blocked state without mutating the final Base scan cursor, staging a cursor, queueing credits, printing env values, or broadcasting.

## Checks

- relayerCommandExitedZeroWithAllowBlocked: True
- relayerReportWritten: True
- relayerStatusBlocked: True
- relayerChildTimeoutRecorded: True
- relayerNoChildTimeouts: True
- blockedBeforeLiveReadiness: True
- externalOwnerIssueRecorded: True
- finalCursorUnchanged: True
- stagedCursorNotWritten: True
- finalCursorNotCommitted: True
- noCreditsObserved: True
- noCreditsQueued: True
- noCreditsApplied: True
- ownerEnvNotImported: True
- broadcastsFalse: True
- envValuesPrintedFalse: True
- noSecrets: True
- secretMarkerFindingsEmpty: True
