# FlowChain Production Truth Table

Generated: 2026-05-17T23:56:15.7718929+00:00
Status: blocked-owner-input
Completion ready: False
Blocked only on known owner inputs: True

## Classification Counts

| Classification | Count |
| --- | ---: |
| passed | 13 |
| blocked-owner-input | 13 |
| blocked-repo-work | 0 |
| failed | 0 |
| stale | 0 |

## Missing Owner Inputs

- FLOWCHAIN_PILOT_OPERATOR_ACK
- FLOWCHAIN_BASE8453_RPC_URL
- FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
- FLOWCHAIN_BASE8453_SUPPORTED_TOKEN
- FLOWCHAIN_BASE8453_ASSET_DECIMALS
- FLOWCHAIN_BASE8453_FROM_BLOCK
- FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
- FLOWCHAIN_PILOT_TOTAL_CAP_WEI
- FLOWCHAIN_PILOT_CONFIRMATIONS
- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED
- FLOWCHAIN_RPC_STATE_BACKUP_PATH
- FLOWCHAIN_TESTER_WRITE_ENABLED
- FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256
- FLOWCHAIN_TESTER_MAX_SEND_UNITS
- FLOWCHAIN_BASE8453_CURSOR_STATE
- FLOWCHAIN_BASE8453_TO_BLOCK

## Next Repo-Owned Tasks

- owner-inputs: blocked-owner-input - Only known owner-input blockers remain in the current truth table.
  Command: npm run flowchain:owner-inputs -- -AllowBlocked

## Gate Table

| Gate | Classification | Raw Status | Evidence | Command |
| --- | --- | --- | --- | --- |
| service-status | passed | passed | status=passed; latestHeight=62010; finalizedHeight=62010 | `npm run flowchain:service:status` |
| service-monitor | passed | passed | status=passed; latestHeight=61752 | `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30` |
| live-product-e2e | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS,FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS | `npm run flowchain:live-product:e2e -- -AllowBlocked` |
| live-infra-check | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:live-infra:check -- -AllowBlocked` |
| wallet-live-service-e2e | passed | passed | status=passed | `npm run flowchain:wallet:live-service:e2e` |
| tester-network-e2e | passed | passed | status=passed | `npm run flowchain:wallet:live-tester:e2e` |
| owner-inputs | blocked-owner-input | blocked | status=blocked; ownerInputReady=False; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:owner-inputs -- -AllowBlocked` |
| public-rpc-readiness | blocked-owner-input | blocked | status=blocked; publicRpcReady=False; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH | `npm run flowchain:public-rpc:check -- -AllowBlocked` |
| public-rpc-validation | passed | passed | status=passed; publicRpcReady=False | `npm run flowchain:public-rpc:validate` |
| public-rpc-abuse-test | passed | passed | status=passed | `npm run flowchain:public-rpc:abuse-test` |
| public-rpc-deployment-bundle | passed | passed | status=passed | `npm run flowchain:public-rpc:deployment-bundle` |
| public-rpc-deployment-automation | passed | passed | status=passed | `npm run flowchain:public-rpc:deployment:automation` |
| backup-readiness | blocked-owner-input | blocked | status=blocked; snapshotProofStatus=not-run; restoreProofStatus=not-run; blockers=FLOWCHAIN_RPC_STATE_BACKUP_PATH | `npm run flowchain:backup:check -- -AllowBlocked` |
| backup-restore-validation | passed | passed | status=passed; backupRestoreHashRoundTrip=True; latestRestoreUsedLatestSnapshot=True; restoreTargetsLiveStateProtected=True; liveStateNonMutationProven=True; corruptedSnapshotDetected=True; manifestTamperDetected=True; missingStateArtifactDetected=True; missingSnapshotManifestDetected=True; latestPointerTamperDetected=True; wrongChainStateMismatchDetected=True | `npm run flowchain:backup:restore:validate` |
| backup-owner-path-dry-run | passed | passed | status=passed | `npm run flowchain:backup:owner-path:dry-run` |
| bridge-live-readiness | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:bridge:live:check -- -AllowBlocked` |
| bridge-infra-readiness | blocked-owner-input | blocked | status=blocked; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:bridge:infra:check -- -AllowBlocked` |
| bridge-relayer-guardrail-validation | passed | passed | status=passed | `npm run flowchain:bridge:relayer:guardrail:validate` |
| external-tester-readiness | blocked-owner-input | blocked | status=blocked; latestHeight=60281; externalSharingReady=False; localTesterRehearsalReady=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:tester:readiness -- -AllowBlocked` |
| external-tester-packet | blocked-owner-input | blocked | status=blocked; latestHeight=60281; finalizedHeight=60281; packetShareable=False; externalSharingReady=False; localTesterRehearsalReady=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:external-tester:packet -- -AllowBlocked` |
| ops-snapshot | blocked-owner-input | blocked | status=blocked; latestHeight=62010; finalizedHeight=62010 | `npm run flowchain:ops:snapshot -- -AllowBlocked` |
| incident-drill | passed | passed | status=passed | `npm run flowchain:ops:incident-drill` |
| public-deployment-contract | blocked-owner-input | blocked | status=blocked; deploymentReady=False; packetShareable=False; blockedOnlyOnKnownExternalOwnerInputs=True; blockers=FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS | `npm run flowchain:public-deployment:contract -- -AllowBlocked` |
| architecture-audit | blocked-owner-input | blocked | status=blocked; blockedOnlyOnKnownExternalOwnerInputs=True; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS,FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS,FLOWCHAIN_BASE8453_CURSOR_STATE,FLOWCHAIN_BASE8453_TO_BLOCK | `npm run flowchain:architecture:audit -- -AllowBlocked` |
| completion-audit | blocked-owner-input | blocked | status=blocked; latestHeight=62010; completionReady=False; blockers=FLOWCHAIN_PILOT_OPERATOR_ACK,FLOWCHAIN_BASE8453_RPC_URL,FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS,FLOWCHAIN_BASE8453_SUPPORTED_TOKEN,FLOWCHAIN_BASE8453_ASSET_DECIMALS,FLOWCHAIN_BASE8453_FROM_BLOCK,FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI,FLOWCHAIN_PILOT_TOTAL_CAP_WEI,FLOWCHAIN_PILOT_CONFIRMATIONS,FLOWCHAIN_RPC_PUBLIC_URL,FLOWCHAIN_RPC_ALLOWED_ORIGINS,FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE,FLOWCHAIN_RPC_TLS_TERMINATED,FLOWCHAIN_RPC_STATE_BACKUP_PATH,FLOWCHAIN_TESTER_WRITE_ENABLED,FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256,FLOWCHAIN_TESTER_MAX_SEND_UNITS | `npm run flowchain:completion:audit -- -AllowBlocked` |
| no-secret-scan | passed | passed | status=passed | `npm run flowchain:no-secret:scan` |

## Release Decision

Do not claim public production readiness yet. The current tracked blockers are known owner inputs.
