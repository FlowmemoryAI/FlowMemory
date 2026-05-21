# FlowChain Bridge No-Secret Audit

Generated: 2026-05-21T09:38:02.2054096Z
Status: passed

This audit scans generated bridge pilot evidence for secret-shaped material before owner-funded bridge activation.

## Scanned Paths

- devnet/local/bridge-live-readiness
- devnet/local/production-l1-real-funds-readiness
- services/bridge-relayer/out

## Checks

| Check | Result |
| --- | --- |
| scannedPathsPresent | True |
| scannedFileCountPositive | True |
| findingsEmpty | True |
| secretMarkerFindingsEmpty | True |
| envValuesPrintedFalse | True |
| noSecrets | True |
| broadcastsFalse | True |

Scanned files: 32
Findings: 0
