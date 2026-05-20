# FlowChain Operator Package

Generated: 2026-05-20T16:52:36.6762384Z
Status: passed

## Package

- Directory: `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\operator-package`
- Manifest: `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\operator-package\OPERATOR_PACKAGE_MANIFEST.json`
- Command matrix: `E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\operator-package\OPERATOR_COMMAND_MATRIX.json`
- Runbooks copied: 45
- Evidence reports copied: 51

## Checks

| Check | Result |
| --- | --- |
| packageScriptsPresent | True |
| commandMatrixWritten | True |
| readmeWritten | True |
| manifestWritten | True |
| runbookDocsCopied | True |
| evidenceReportsCopied | True |
| copiedFileHashesWritten | True |
| copiedFileHashesMatch | True |
| ownerInputNamesOnly | True |
| flowChainRpcIsRepoOwned | True |
| thirdPartyFlowChainRpcProviderNeededFalse | True |
| noSecretScanPassed | True |
| secretMarkerFindingsEmpty | True |
| envValuesPrintedFalse | True |
| broadcastsFalse | True |
| noSecrets | True |

## Owner Inputs

- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_TLS_TERMINATED
- FLOWCHAIN_RPC_STATE_BACKUP_PATH
- FLOWCHAIN_TESTER_WRITE_ENABLED
- FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256
- FLOWCHAIN_TESTER_MAX_SEND_UNITS
- FLOWCHAIN_PILOT_OPERATOR_ACK
- FLOWCHAIN_BASE8453_RPC_URL
- FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
- FLOWCHAIN_BASE8453_SUPPORTED_TOKEN
- FLOWCHAIN_BASE8453_ASSET_DECIMALS
- FLOWCHAIN_BASE8453_FROM_BLOCK
- FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
- FLOWCHAIN_PILOT_TOTAL_CAP_WEI
- FLOWCHAIN_PILOT_CONFIRMATIONS

## First Operator Commands

- `npm run flowchain:prereq`
- `npm run flowchain:doctor`
- `npm run flowchain:install:check`
- `npm run flowchain:service:start -- -LiveProfile`
- `npm run flowchain:service:status -- -AllowBlocked`
- `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30`
- `npm run flowchain:service:restart -- -LiveProfile`
- `npm run flowchain:upgrade:rehearse`
- `npm run flowchain:service:stop`
- `npm run flowchain:service:supervisor:validate`
- `npm run flowchain:service:install:windows -- -Action Plan`
- `npm run flowchain:service:install:validate`
