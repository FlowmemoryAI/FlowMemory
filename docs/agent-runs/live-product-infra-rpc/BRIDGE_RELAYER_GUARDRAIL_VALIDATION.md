# FlowChain Bridge Relayer Guardrail Validation

Generated: 2026-05-17T16:10:10.2458673Z
Status: passed

This validation proves a relayer run with missing owner Base 8453 inputs exits as an allowed blocked state without mutating the final Base scan cursor, staging a cursor, queueing credits, printing env values, or broadcasting.

## Checks

- relayerCommandExitedZeroWithAllowBlocked: True
- relayerReportWritten: True
- relayerStatusBlocked: True
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
