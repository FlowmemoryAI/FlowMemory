# FlowChain Bridge Release Evidence Validation

Generated: 2026-05-20T04:48:00.4302556Z
Status: passed

## Cases

| Case | Status | Expected | Actual | Exit |
| --- | --- | --- | --- | --- |
| matching-release-evidence | passed | passed | passed | 0 |
| missing-inputs-blocked | passed | blocked | blocked | 1 |
| amount-mismatch-failed | passed | failed | failed | 1 |
| token-mismatch-failed | passed | failed | failed | 1 |
| recipient-mismatch-failed | passed | failed | failed | 1 |
| chain-mismatch-failed | passed | failed | failed | 1 |
| asset-mismatch-failed | passed | failed | failed | 1 |
| release-broadcast-rejected | passed | failed | failed | 1 |
| withdrawal-broadcast-rejected | passed | failed | failed | 1 |

## Checks

| Check | Result |
| --- | --- |
| releaseEvidenceScriptExists | True |
| matchingEvidencePasses | True |
| missingInputsBlock | True |
| amountMismatchFails | True |
| tokenMismatchFails | True |
| recipientMismatchFails | True |
| chainMismatchFails | True |
| assetMismatchFails | True |
| releaseBroadcastRejected | True |
| withdrawalBroadcastRejected | True |
| allRequiredCasesCovered | True |
| failedCasesAbsent | True |
| noSecretScanPassed | True |
| broadcastsFalse | True |
| envValuesPrintedFalse | True |
| noSecrets | True |
| secretMarkerFindingsEmpty | True |
