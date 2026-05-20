# FlowChain Install Upgrade Rollback

Generated: 2026-05-20T11:48:22.1757964Z
Status: passed

This runbook and report prove the local upgrade path preserves FlowChain state by copying the current state into a previous-release backup, applying a next-release rehearsal, and restoring rollback state with matching hashes. It does not mutate the owner host.

## Operator Commands

- preflight: `npm run flowchain:install:check`
- stop: `npm run flowchain:service:stop`
- backup: `npm run flowchain:backup:create`
- upgrade: `git pull --ff-only && npm install && npm run flowchain:service:start -- -LiveProfile`
- verify: `npm run flowchain:service:status -- -AllowBlocked && npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30`
- rollback: `restore the previous package checkout and backup state, then run npm run flowchain:service:restart -- -LiveProfile`
- reAudit: `npm run flowchain:completion:audit -- -AllowBlocked`

## Checks

| Check | Result |
| --- | --- |
| stateSourceExists | True |
| sourceStateReadable | True |
| previousReleaseStateCopied | True |
| backupStateCopied | True |
| nextReleaseStateCopied | True |
| rollbackStateCopied | True |
| sourceStateHashPresent | True |
| previousStateHashMatchesSource | True |
| nextStateHashMatchesSource | True |
| rollbackStateHashMatchesSource | True |
| chainIdPreserved | True |
| genesisHashPreserved | True |
| nextBlockNumberPreserved | True |
| packageManifestCaptured | True |
| migrationManifestWritten | True |
| rollbackManifestWritten | True |
| rollbackCommandsPresent | True |
| verifyCommandsPresent | True |
| workDirInsideRepo | True |
| hostMutationPerformedFalse | True |
| envValuesPrintedFalse | True |
| secretMarkerFindingsEmpty | True |
| noSecrets | True |
| broadcastsFalse | True |
