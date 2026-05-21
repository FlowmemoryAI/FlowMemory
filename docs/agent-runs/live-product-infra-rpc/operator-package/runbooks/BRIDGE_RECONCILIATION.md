# FlowChain Bridge Reconciliation

Generated: 2026-05-21T14:23:21.5982831Z
Status: passed

This report reconciles the live Base 8453 relayer state with local bridge proofs: observed credits, new credits, queued L1 transactions, applied credits, pending credits, replay rejection, cursor safety, and release evidence.

## Reconciliation

| Lane | Status | Count | Evidence |
| --- | --- | ---: | --- |
| live-observed | none-or-owner-blocked | 0 | live relayer once observed credits |
| live-new | none-or-owner-blocked | 0 | live relayer once filtered new credits |
| live-queued | none-or-owner-blocked | 0 | live relayer once queued L1 transactions |
| live-applied | none-or-owner-blocked | 0 | live relayer once applied L1 credits |
| live-pending | empty | 0 | new credits minus applied credits |
| local-runtime-applied | proved | 1 | runtime credit validation spendable proof |
| local-replay-rejected | proved | 1 | mock pilot duplicate replay rejection proof |
| release-evidence | validated | 1 | withdrawal/release evidence validation proof |

## Checks

| Check | Result |
| --- | --- |
| relayerOnceReportLoaded | True |
| relayerOnceStatusBlockedOrPassed | True |
| relayerOnceNoFailedChecks | True |
| relayerOnceNoSecrets | True |
| relayerOnceNoBroadcasts | True |
| relayerCountsNonNegative | True |
| pendingCreditsNonNegative | True |
| cursorModeStaged | True |
| cursorFinalNotCommittedWhenBlocked | True |
| relayerBlockedClassifiedOwnerInput | True |
| guardrailReportPassed | True |
| guardrailNoFailedChecks | True |
| guardrailCursorSafe | True |
| loopValidationPassedOrOwnerBlocked | True |
| runtimeCreditPassed | True |
| runtimeCreditNoFailedChecks | True |
| runtimeCreditAppliedOnce | True |
| runtimeReplayRejected | True |
| localPilotPassed | True |
| localPilotNoFailedChecks | True |
| localPilotExactValueConserved | True |
| localPilotDuplicateReplayRejected | True |
| releaseEvidenceValidationPassed | True |
| releaseEvidenceNoFailedChecks | True |
| reconciliationRowsPresent | True |
| liveReadinessBlockedOrPassed | True |
| bridgeInfraBlockedOrPassed | True |
| envValuesPrintedFalse | True |
| secretMarkerFindingsEmpty | True |
| noSecrets | True |
| broadcastsFalse | True |
