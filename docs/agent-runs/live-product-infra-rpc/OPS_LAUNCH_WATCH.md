# FlowChain Ops Launch Watch

Generated: 2026-05-22T01:09:11.2143204Z
Status: passed
Launch watch status: blocked-owner-input

This report ties the launch-critical service, public RPC, backup, bridge, tester UI, observability, and release-governance lanes to evidence, metrics, alert rules, and operator commands. It does not send network notifications, store delivery credentials, print owner values, or broadcast transactions.

| Lane | Status | Evidence | Metrics | Alerts | Blockers |
| --- | --- | --- | --- | --- | --- |
| service-autorecovery | passed | 4 reports | 5 metrics | 6 rules | `` |
| public-rpc-deployment | blocked-owner-input | 4 reports | 6 metrics | 4 rules | `FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED` |
| backup-restore | blocked-owner-input | 4 reports | 5 metrics | 4 rules | `FLOWCHAIN_RPC_STATE_BACKUP_PATH` |
| bridge-pilot-relayer | blocked-owner-input | 9 reports | 7 metrics | 8 rules | `FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS` |
| explorer-faucet-wallet-ui | blocked-owner-input | 6 reports | 7 metrics | 5 rules | `FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS` |
| observability-alerting | passed | 6 reports | 8 metrics | 3 rules | `` |
| release-governance | blocked-owner-input | 6 reports | 6 metrics | 3 rules | `FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS, FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH` |

## Checks

| Check | Result |
| --- | --- |
| packageScriptPresent | True |
| refreshStepsSucceeded | True |
| metricsJsonLoaded | True |
| laneCountSufficient | True |
| everyLaneHasEvidence | True |
| everyLaneHasMetrics | True |
| everyLaneHasAlertRules | True |
| everyLaneHasCommands | True |
| everyLaneCommandHasPackageScript | True |
| commandsAvoidInlineEnvAssignment | True |
| commandsAvoidUrls | True |
| opsSnapshotLoaded | True |
| opsSnapshotHasNoCriticalFindings | True |
| opsSnapshotBlockedFindingsAreExpected | True |
| opsAlertRulesPassed | True |
| opsAlertsMapCurrentFindings | True |
| activeAlertRulesPresent | True |
| opsMetricsExportPassed | True |
| monitoringBundlePassed | True |
| noSecretScanPassed | True |
| truthTableNoRepoBlocked | True |
| truthTableNoFailed | True |
| truthTableNoStale | True |
| capabilityMatrixNoRepoBlocked | True |
| blockedLanesHaveKnownOwnerInputs | True |
| noProductionReadyClaimWhileBlocked | True |
| opsCriticalMetricZero | True |
| truthFailedMetricZero | True |
| truthStaleMetricZero | True |
| truthRepoBlockedMetricZero | True |
| envValuesPrintedFalse | True |
| secretMarkerFindingsEmpty | True |
| noSecrets | True |
| broadcastsFalse | True |
