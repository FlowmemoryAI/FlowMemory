# FlowChain Live Chain Capability Matrix

Generated: 2026-05-21T16:36:32.5791895Z
Status: passed
Launch readiness: blocked-owner-input
Production ready: False

This matrix maps the user-facing live-chain requirements to concrete reports and commands. It prints names and statuses only, not owner values.

## Current Chain

- Latest height: 113867
- Finalized height: 113867
- Capability counts: passed=10, blocked-owner-input=4, repo-blocked=0

## Capabilities

| Capability | Status | Evidence | Blockers | First command |
| --- | --- | --- | --- | --- |
| RPC servers are running | passed | serviceStatus=passed; latestHeight=113867; finalizedHeight=113867 | none | `npm run flowchain:service:status` |
| Chain is producing blocks | passed | serviceMonitor=passed; heightAdvanced=True; latestHeight=113867 | none | `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30` |
| Autorecovery and reboot persistence | passed | supervisor=passed; windowsInstall=passed; systemdInstall=passed | none | `npm run flowchain:service:supervisor:validate` |
| Wallet creation | passed | testerNetwork=passed; walletCreates=4 | none | `npm run flowchain:wallet:live-tester:e2e` |
| Wallet-to-wallet transfers | passed | liveWallet=passed; testerTransfers=4; latestHeight=113867 | none | `npm run flowchain:wallet:live-service:e2e` |
| Explorer, faucet, and wallet UI | passed | dashboardUi=passed; gateway=passed; routes=10; proofs=13 | none | `npm run flowchain:dashboard:ui:readiness` |
| Public RPC connection | blocked-owner-input | publicRpc=blocked; syntheticCanary=blocked; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED | `FLOWCHAIN_RPC_PUBLIC_URL`, `FLOWCHAIN_RPC_ALLOWED_ORIGINS`, `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`, `FLOWCHAIN_RPC_TLS_TERMINATED` | `npm run flowchain:public-rpc:check -- -AllowBlocked` |
| Real-value bridge pilot | blocked-owner-input | bridgeLive=blocked; bridgeInfra=blocked; runtimeCredit=passed; realValuePilot=passed; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_RPC_URL`, `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`, `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`, `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, `FLOWCHAIN_PILOT_CONFIRMATIONS` | `npm run flowchain:bridge:live:check -- -AllowBlocked` |
| Bridge relayer hardening | passed | guardrail=passed; loop=passed; releaseEvidence=passed | none | `npm run flowchain:bridge:relayer:guardrail:validate` |
| Backup and restore | blocked-owner-input | backupReadiness=blocked; restoreValidation=passed; ownerPathDryRun=passed; blockers=FLOWCHAIN_RPC_STATE_BACKUP_PATH | `FLOWCHAIN_RPC_STATE_BACKUP_PATH` | `npm run flowchain:backup:restore:validate` |
| Observability and alerting | passed | opsSnapshot=blocked; alerts=passed; metrics=passed; monitoringBundle=passed | none | `npm run flowchain:ops:snapshot -- -AllowBlocked` |
| External tester launch | blocked-owner-input | testerReadiness=blocked; packet=blocked; packetSmoke=True; clientValidation=passed; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `FLOWCHAIN_RPC_PUBLIC_URL`, `FLOWCHAIN_RPC_ALLOWED_ORIGINS`, `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`, `FLOWCHAIN_RPC_TLS_TERMINATED`, `FLOWCHAIN_RPC_STATE_BACKUP_PATH`, `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_RPC_URL`, `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`, `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`, `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, `FLOWCHAIN_PILOT_CONFIRMATIONS` | `npm run flowchain:tester:readiness -- -AllowBlocked` |
| Developer ecosystem | passed | devPack=passed; methodCount=82 | none | `npm run flowchain:dev-pack:e2e` |
| Owner go-live control | passed | ownerNeedsNow=passed; goLiveHandoff=passed; deploymentContract=blocked | none | `npm run flowchain:owner:needs-now` |

## Needed Now

- Public RPC connection: FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED
- Real-value bridge pilot: FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS
- Backup and restore: FLOWCHAIN_RPC_STATE_BACKUP_PATH
- External tester launch: FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS

## Guardrails

- No production-ready claim while any public launch critical capability is blocked.
- Blocked capabilities must point to known owner input names.
- Repo-blocked capabilities must remain empty before claiming the repo side is done.

## Checks

| Check | Passed |
| --- | --- |
| packageScriptPresent | True |
| requiredReportsLoaded | True |
| capabilityCountMinimumMet | True |
| userRequirementCoverageComplete | True |
| publicLaunchCriticalCapabilitiesCovered | True |
| allCriticalCapabilitiesEitherPassedOrOwnerBlocked | True |
| repoBlockedCapabilitiesEmpty | True |
| blockedCapabilitiesHaveBlockers | True |
| blockedCapabilitiesUseKnownOwnerInputs | True |
| truthTableOwnerBlockersKnown | True |
| publicRpcCapabilityBlocksOnPublicRpcInputs | True |
| bridgeCapabilityBlocksOnBridgeInputs | True |
| backupCapabilityBlocksOnBackupInput | True |
| noProductionReadyClaimWhileBlocked | True |
| ownerNeedsNowLoaded | True |
| envValuesPrintedFalse | True |
| noSecrets | True |
| broadcastsFalse | True |
| secretMarkerFindingsEmpty | True |
