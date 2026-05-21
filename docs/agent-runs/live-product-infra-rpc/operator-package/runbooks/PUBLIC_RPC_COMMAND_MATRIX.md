# FlowChain Public RPC Command Matrix

Generated: 2026-05-21T06:00:23.2217487Z
Status: passed

This matrix maps public RPC launch commands to phase, owner-host mutation risk, owner input names, and expected evidence paths. It prints names only, not owner values.

## Summary

- Commands: 21
- Phases: edge-apply, owner-host-plan, post-deploy-proof, preflight, release, render, rollback, service-install, tester-proof
- Owner-host commands: 6
- Mutating owner-host commands: 4
- Committed evidence paths: 21
- Failed checks: 0

## Checks

| Check | Passed |
| --- | --- |
| packageScriptPresent | True |
| allPackageScriptsPresent | True |
| phaseCoverageComplete | True |
| renderPlanApplyProofRollbackCovered | True |
| ownerHostPlanCommandsPresent | True |
| ownerHostApplyCommandsPresent | True |
| ownerHostRollbackCommandsPresent | True |
| mutatingOwnerHostCommandsHaveRollbackCoverage | True |
| deploymentAutomationReportPassed | True |
| deploymentBundleReportPassed | True |
| deploymentAutomationCommandPlanCovered | True |
| deploymentAutomationOwnerHostApplyCovered | True |
| deploymentAutomationRollbackDrillCovered | True |
| deploymentBundleRollbackRunbookCovered | True |
| requiredEnvReferencesPresent | True |
| validationSignalsPresent | True |
| commandsAvoidInlineEnvAssignment | True |
| commandsAvoidUrls | True |
| commandsAvoidKeyMaterial | True |
| ownerInputNamesOnly | True |
| committedEvidencePathsCovered | True |
| envValuesPrintedFalse | True |
| broadcastsFalse | True |
| noSecrets | True |

## Commands

| Phase | Command | Risk | Mutates Host | Evidence |
| --- | --- | --- | --- | --- |
| preflight | `flowchain:public-rpc:check` | read-only-owner-input-gate | False | docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json |
| render | `flowchain:public-rpc:edge-template` | local-render-no-mutation | False | docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json |
| render | `flowchain:public-rpc:deployment-bundle` | local-render-no-mutation | False | docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json |
| render | `flowchain:public-rpc:deployment:automation` | local-validation-no-mutation | False | docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json |
| service-install | `flowchain:service:install:systemd:validate` | local-validation-no-mutation | False | docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json |
| service-install | `flowchain:service:install:validate` | local-validation-no-mutation | False | docs/agent-runs/live-product-infra-rpc/service-install-validation-report.json |
| owner-host-plan | `owner-host-linux-plan` | owner-host-read-only-plan | False | docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json |
| owner-host-plan | `owner-host-windows-plan` | owner-host-read-only-plan | False | docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json |
| edge-apply | `owner-host-linux-apply` | owner-host-mutating-apply | True | docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json |
| edge-apply | `owner-host-windows-apply` | owner-host-mutating-apply | True | docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json |
| post-deploy-proof | `flowchain:public-rpc:validate` | read-only-proof | False | docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json |
| post-deploy-proof | `flowchain:public-rpc:synthetic-canary` | read-only-owner-input-gate | False | docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json |
| post-deploy-proof | `flowchain:public-rpc:abuse-test` | read-only-proof | False | docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json |
| tester-proof | `flowchain:tester:gateway:e2e` | local-validation-no-broadcast | False | docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json |
| tester-proof | `flowchain:wallet:live-tester:e2e` | local-validation-no-broadcast | False | docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json |
| release | `flowchain:public-deployment:contract` | release-gate | False | docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json |
| release | `flowchain:live:cutover:rehearsal` | release-gate | False | docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json |
| release | `flowchain:truth-table` | release-gate | False | docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json |
| release | `flowchain:no-secret:scan` | release-gate | False | docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json |
| rollback | `owner-host-linux-rollback` | owner-host-mutating-rollback | True | docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json |
| rollback | `owner-host-windows-rollback` | owner-host-mutating-rollback | True | docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json |

## Owner Input Names

- FLOWCHAIN_DEPLOY_RENDER_DIR
- FLOWCHAIN_RPC_ALLOWED_ORIGINS
- FLOWCHAIN_RPC_PUBLIC_URL
- FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE
- FLOWCHAIN_RPC_STATE_BACKUP_PATH
- FLOWCHAIN_RPC_TLS_TERMINATED

## Source Reports

| Report | Status |
| --- | --- |
| readiness | blocked |
| edgeTemplate | passed |
| deploymentBundle | passed |
| deploymentAutomation | passed |
| validation | passed |
| syntheticCanary | blocked |
| abuseTest | passed |
| testerGateway | passed |
| testerNetwork | passed |
| publicDeployment | blocked |
| cutover | blocked |
| truthTable | blocked-owner-input |
| noSecret | passed |
