# FlowChain Production Truth Table

Generated: 2026-05-16T11:44:35.6080447+00:00
Status: stale
Completion ready: False
Blocked only on known owner inputs: False

## Classification Counts

| Classification | Count |
| --- | ---: |
| passed | 10 |
| blocked-owner-input | 12 |
| blocked-repo-work | 0 |
| failed | 0 |
| stale | 1 |

## Missing Owner Inputs

- FLOWCHAIN_PILOT_OPERATOR_ACK
- FLOWCHAIN_BASE8453_RPC_URL
- FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
- FLOWCHAIN_BASE8453_SUPPORTED_TOKEN
- FLOWCHAIN_BASE8453_ASSET_DECIMALS
- FLOWCHAIN_BASE8453_FROM_BLOCK
- FLOWCHAIN_BASE8453_TO_BLOCK
- FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
- FLOWCHAIN_PILOT_TOTAL_CAP_WEI
- FLOWCHAIN_PILOT_CONFIRMATIONS
- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED
- FLOWCHAIN_RPC_STATE_BACKUP_PATH

## Next Repo-Owned Tasks

- completion-audit: stale - older-than-public-deployment-contract
  Command: npm run flowchain:completion:audit -- -AllowBlocked

## Gate Table

| Gate | Classification | Raw Status | Evidence | Command |
| --- | --- | --- | --- | --- |
| service-status | passed | passed | status=passed; latestHeight=36082; finalizedHeight=36082 | `npm run flowchain:service:status` |
| service-monitor | passed | passed | status=passed; latestHeight=36082 | `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30` |
| live-product-e2e | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS,FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH | `npm run flowchain:live-product:e2e -- -AllowBlocked` |
| live-infra-check | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:live-infra:check -- -AllowBlocked` |
| wallet-live-service-e2e | passed | passed | status=passed | `npm run flowchain:wallet:live-service:e2e` |
| tester-network-e2e | passed | passed | status=passed | `npm run flowchain:wallet:live-tester:e2e` |
| owner-inputs | blocked-owner-input | blocked | status=blocked; ownerInputReady=False; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:owner-inputs -- -AllowBlocked` |
| public-rpc-readiness | blocked-owner-input | blocked | status=blocked; publicRpcReady=False; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH | `npm run flowchain:public-rpc:check -- -AllowBlocked` |
| public-rpc-validation | passed | passed | status=passed; publicRpcReady=False | `npm run flowchain:public-rpc:validate` |
| public-rpc-abuse-test | passed | passed | status=passed | `npm run flowchain:public-rpc:abuse-test` |
| public-rpc-deployment-bundle | passed | passed | status=passed | `npm run flowchain:public-rpc:deployment-bundle` |
| backup-readiness | blocked-owner-input | blocked | status=blocked; snapshotProofStatus=not-run; restoreProofStatus=not-run; blockers=FLOWCHAIN_RPC_STATE_BACKUP_PATH | `npm run flowchain:backup:check -- -AllowBlocked` |
| backup-restore-validation | passed | passed | status=passed; backupRestoreHashRoundTrip=True; latestRestoreUsedLatestSnapshot=True; restoreTargetsLiveStateProtected=True; liveStateNonMutationProven=True; corruptedSnapshotDetected=True; manifestTamperDetected=True; missingStateArtifactDetected=True; missingSnapshotManifestDetected=True; latestPointerTamperDetected=True; wrongChainStateMismatchDetected=True | `npm run flowchain:backup:restore:validate` |
| bridge-live-readiness | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:bridge:live:check -- -AllowBlocked` |
| bridge-infra-readiness | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:bridge:infra:check -- -AllowBlocked` |
| external-tester-readiness | blocked-owner-input | blocked | status=blocked; latestHeight=35521; externalSharingReady=False; localTesterRehearsalReady=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:tester:readiness -- -AllowBlocked` |
| external-tester-packet | blocked-owner-input | blocked | status=blocked; latestHeight=35521; packetShareable=False; externalSharingReady=False; localTesterRehearsalReady=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:external-tester:packet -- -AllowBlocked` |
| ops-snapshot | blocked-owner-input | blocked | status=blocked; latestHeight=35521; finalizedHeight=35521 | `npm run flowchain:ops:snapshot -- -AllowBlocked` |
| incident-drill | passed | passed | status=passed | `npm run flowchain:ops:incident-drill` |
| public-deployment-contract | blocked-owner-input | blocked | status=blocked; deploymentReady=False; packetShareable=False; blockedOnlyOnKnownExternalOwnerInputs=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:public-deployment:contract -- -AllowBlocked` |
| architecture-audit | blocked-owner-input | blocked | status=blocked; blockedOnlyOnKnownExternalOwnerInputs=True; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS,FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH | `npm run flowchain:architecture:audit -- -AllowBlocked` |
| completion-audit | stale | blocked | status=blocked; latestHeight=35521; completionReady=False; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_BASE8453_TO_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS,FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH | `npm run flowchain:completion:audit -- -AllowBlocked` |
| no-secret-scan | passed | passed | status=passed | `npm run flowchain:no-secret:scan` |

## Release Decision

Do not claim public production readiness yet. At least one required report is stale or missing.
