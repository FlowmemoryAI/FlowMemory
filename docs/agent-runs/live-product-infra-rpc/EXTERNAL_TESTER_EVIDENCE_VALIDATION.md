# FlowChain External Tester Evidence Validation

Generated: 2026-05-19T14:59:16.4786341Z
Status: passed

This validates a redacted friends-and-family evidence folder before owner review. It checks required files, JSON readability, block-height advancement, wallet transfer consistency, amount cap, and no-secret boundaries.

- Evidence directory: `docs/agent-runs/live-product-infra-rpc/external-tester-evidence-sample`
- Max amount units: 1

## Checks

| Check | Result |
| --- | --- |
| packageScriptPresent | True |
| guideExists | True |
| guideListsSuggestedFiles | True |
| guideHasOwnerReviewChecklist | True |
| guideHasStopRules | True |
| evidenceDirInsideRepo | True |
| evidenceDirExists | True |
| requiredFilesPresent | True |
| requiredJsonValid | True |
| notesPresent | True |
| readinessPassed | True |
| diagnosticsPassed | True |
| diagnosticsNoSecrets | True |
| heightsNumeric | True |
| blockHeightAdvanced | True |
| sendAccepted | True |
| transferIdPresent | True |
| transactionIdPresent | True |
| transferFound | True |
| transferMatchesAccounts | True |
| transferAmountMatches | True |
| transactionIdMatches | True |
| transferBlockHeightInWindow | True |
| includedHeightMatchesTransfer | True |
| amountWithinLimit | True |
| balancesPresent | True |
| senderDebited | True |
| recipientCredited | True |
| secretMarkerFindingsEmpty | True |
| credentialUrlFindingsEmpty | True |
| envAssignmentFindingsEmpty | True |
| envValuesPrintedFalse | True |
| noSecrets | True |
| broadcastsFalse | True |

## Required Files

- `01-readiness.json`: present
- `02-status-before.json`: present
- `03-wallet-balances-before.json`: present
- `04-wallet-send.json`: present
- `05-status-after.json`: present
- `06-wallet-transfers-after.json`: present
- `07-wallet-balances-after.json`: present
- `10-diagnostics.json`: present
- `NOTES.md`: present
