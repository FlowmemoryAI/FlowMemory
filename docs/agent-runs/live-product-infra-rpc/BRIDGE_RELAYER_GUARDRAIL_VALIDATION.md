# FlowChain Bridge Relayer Guardrail Validation

Generated: 2026-05-19T19:27:19.6016266Z
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
- directObserveFailedClosed: True
- directObserveReportWritten: True
- directObserveStatusBlocked: True
- directObserveUsesStagedCursorByDefault: True
- directObserveCursorNotFinal: True
- directObserveFinalCursorUnchanged: True
- directObserveStagedCursorNotWritten: True
- directObserveBroadcastsFalse: True
- directObserveEnvValuesPrintedFalse: True
- directObserveNoSecrets: True
- broadcastsFalse: True
- envValuesPrintedFalse: True
- noSecrets: True
- secretMarkerFindingsEmpty: True
