# FlowChain Install Check

Generated: 2026-05-20T11:49:04.9199413Z
Status: passed

This is the owner-host install preflight for running FlowChain outside a developer-only shell. It checks tools, package commands, runbooks, no-secret service install validations, systemd install validation, and operator package verification without mutating the host.

## Checks

| Check | Result |
| --- | --- |
| repoRootResolved | True |
| packageJsonReadable | True |
| requiredPackageScriptsPresent | True |
| requiredRunbooksPresent | True |
| requiredToolsPresent | True |
| diskFreeMeetsMinimum | True |
| serviceInstallValidationReportPassed | True |
| systemdInstallValidationReportPassed | True |
| childValidationsPassed | True |
| childValidationsDidNotTimeout | True |
| ownerInputNamesOnly | True |
| ownerInputAbsenceIsNonRepoBlocker | True |
| hostMutationPerformedFalse | True |
| envValuesPrintedFalse | True |
| secretMarkerFindingsEmpty | True |
| noSecrets | True |
| broadcastsFalse | True |

## Commands

- `npm run flowchain:install:check`
- `npm run flowchain:service:install:validate`
- `npm run flowchain:service:install:systemd:validate`
- `npm run flowchain:operator:package:verify`
- `npm run flowchain:upgrade:rehearse`

## Owner Inputs Still Needed

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
