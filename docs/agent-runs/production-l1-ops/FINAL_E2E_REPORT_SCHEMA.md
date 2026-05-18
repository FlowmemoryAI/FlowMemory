# Final E2E Report Schema

Report path:

```text
devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json
```

Required top-level fields now written by `npm run flowchain:production-l1:e2e`:

| Field | Meaning |
| --- | --- |
| `schema` | Report schema id. |
| `timestamp` | UTC report time. |
| `repoPath` | Local repository root. |
| `git.branch`, `git.commit` | Current branch and commit when available. |
| `os.platform`, `os.version`, `os.shell` | Local OS and shell metadata. |
| `toolVersions` | Git, Node, npm, Cargo, Rust, Foundry, Cast, and Python discovery. |
| `portsUsed` | Control-plane and dashboard port status. |
| `localUrls` | Dashboard and control-plane URLs. |
| `dataDirectory` | Local devnet data directory. |
| `chainId` | Local chain id. |
| `genesisHash` | First local block hash when available. |
| `latestHeight`, `latestHash`, `finalizedHeight`, `stateRoot` | Current local chain head and state root. |
| `walletE2EStatus`, `transferE2EStatus` | Wallet and local transfer status. |
| `tokenE2EStatus`, `dexE2EStatus`, `productE2EStatus` | Product/token/DEX status. |
| `bridgeMockStatus`, `bridgeLiveReadinessStatus` | Mock bridge and live-readiness status. |
| `rpcSmokeStatus` | Control-plane smoke status. |
| `dashboardBuildOrBrowserStatus` | Dashboard build or browser verification status. |
| `exportImportStatus`, `restartRecoveryStatus` | Backup/restore and restart recovery status. |
| `noSecretScanStatus`, `unsafeClaimScanStatus` | Security scan status. |
| `missingEnvNamesForLiveMode` | Env names only, never values. |
| `missingSubsystemCommands` | Owner, reason, log path, report path, and blocker class for missing strict live-pilot proof commands. |
| `failureBlockerDetails` | Failure/blocker rows with subsystem, owner, command, status, log path, report path, blocker class, and mock/live impact booleans. |
| `commandList` | Commands run or verified by the wrapper. |
| `subsystemSteps` | Per-step status, owner, command, log path, report path, and blocker class. |
| `localLogPaths`, `healthEndpoint`, `reportPaths` | Observability paths. |
| `restartCommands`, `emergencyCommands` | Operator commands for recovery and stop paths. |
| `evidencePaths` | Evidence bundle, report, and export bundle paths. |
| `passFailSummary` | Overall, mock path, live readiness, live broadcast, failures, and blockers. |
