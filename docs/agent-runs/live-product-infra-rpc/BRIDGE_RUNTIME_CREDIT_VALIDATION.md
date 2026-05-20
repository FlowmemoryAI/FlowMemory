# FlowChain Bridge Runtime Credit Validation

Generated: 2026-05-20T14:06:59.4922642Z
Status: passed

This validation runs the production-shaped Base 8453 runtime credit proof in an isolated local state, verifies a bridge handoff becomes spendable within the settlement target, rejects replay, spends from the credited wallet, survives restart/export/import, and records no-secret/no-broadcast boundaries.

## Checks

- childCommandPassed: True
- childDidNotTimeout: True
- proofReportWritten: True
- proofClassificationReady: True
- proofFailedChecksEmpty: True
- requiredRuntimeChecksCovered: True
- requiredRuntimeChecksPassed: True
- sourceChainBase8453: True
- creditAppliedOnce: True
- creditedBalanceTransferable: True
- replayRejected: True
- restartPreservesCreditHistory: True
- exportImportPreservesReplayProtection: True
- latencyRecorded: True
- latencyGatePassed: True
- transferLatencyUnderTarget: True
- proofBroadcastsFalse: True
- proofEnvValuesPrintedFalse: True
- proofNoSecrets: True
- handoffReportReadable: True
- handoffNoReleaseBroadcast: True
- handoffNoWithdrawalBroadcast: True
- secretMarkerFindingsEmpty: True
- broadcastsFalse: True
- envValuesPrintedFalse: True
- noSecrets: True
