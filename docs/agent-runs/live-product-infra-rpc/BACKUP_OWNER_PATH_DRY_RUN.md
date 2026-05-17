# FlowChain Backup Owner Path Dry Run

Generated: 2026-05-17T20:22:22.7898628Z
Status: passed

This dry run sets FLOWCHAIN_RPC_STATE_BACKUP_PATH to an ignored local directory and runs the same backup readiness gate used for production. It does not use or record the owner's real backup path.

## Checks

- dryRunRootInsideIgnoredLocalState: True
- ownerBackupEnvRestored: True
- childReadinessCommandPassed: True
- readinessReportWritten: True
- readinessStatusPassed: True
- backupRootConfigured: True
- backupRootValuePrintedFalse: True
- snapshotProofPassed: True
- restoreProofPassed: True
- writeVerified: True
- latestPointerVerified: True
- latestPointerWrittenAtomically: True
- stateRootCompared: True
- stateRootMatch: True
- stateFileHashMatch: True
- restoreVerified: True
- backupReportPassed: True
- restoreReportPassed: True
- backupSnapshotCreated: True
- restoreLiveStateProtected: True
- restoreDidNotMutateLiveState: True
- liveStateStillReadable: True
- envValuesPrintedFalse: True
- noSecrets: True
- broadcastsFalse: True
