# FlowChain Bridge Relayer Guardrail Validation

Generated: 2026-05-21T17:57:07.7654136Z
Status: passed

This validation proves a relayer run with missing owner Base 8453 inputs exits as an allowed blocked state without mutating the final Base scan cursor, staging a cursor, queueing credits, printing env values, or broadcasting. It also runs the bridge relayer unit suite and requires the same-process cursor concurrency test so the Base scan cursor cannot double-scan under concurrent SDK or harness calls.

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
- bridgeRelayerTestsPassed: True
- bridgeRelayerConcurrencyTestCovered: True
- bridgeCursorAsyncLockImplemented: True
- bridgeCursorLockUsesAsyncRetry: True
- broadcastsFalse: True
- envValuesPrintedFalse: True
- noSecrets: True
- secretMarkerFindingsEmpty: True
