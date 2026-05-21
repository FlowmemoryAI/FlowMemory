# FlowChain Bridge Command Matrix

Generated: 2026-05-21T05:10:16.7291033Z
Status: passed

This matrix maps bridge pilot commands to their phase, live-broadcast risk, owner input names, acknowledgement gates, and expected evidence paths. It prints names only, not owner values.

## Summary

- Commands: 20
- Phases: credit, deploy-control, emergency-control, local-smoke, observe, pilot-proof, preflight, release, withdraw-release
- Live-broadcast-capable commands: 4
- Committed evidence paths: 12
- Failed checks: 0

## Checks

| Check | Passed |
| --- | --- |
| allRequiredScriptsPresent | True |
| phaseCoverageComplete | True |
| deployObserveRelayerControlReleaseCovered | True |
| liveBroadcastCommandsAckGated | True |
| observeCommandOperatorAckGated | True |
| relayerOnceOperatorAckGated | True |
| controlCommandsBroadcastAckGated | True |
| deployCommandBroadcastAckGated | True |
| requiredEnvReferencesPresent | True |
| requiredAckReferencesPresent | True |
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

| Phase | Script | Risk | Ack gates | Evidence |
| --- | --- | --- | --- | --- |
| preflight | `flowchain:bridge:live:check` | read-only-owner-input-gate | FLOWCHAIN_PILOT_OPERATOR_ACK | docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json |
| preflight | `flowchain:bridge:infra:check` | read-only-owner-input-gate | FLOWCHAIN_PILOT_OPERATOR_ACK | docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json |
| deploy-control | `flowchain:bridge:deploy:base8453` | owner-live-broadcast-gated | FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_BROADCAST_ACK | devnet/local/bridge-live-readiness/base8453-deploy-readiness.json |
| deploy-control | `flowchain:bridge:deploy:control:validate` | local-validation-no-broadcast | FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_BROADCAST_ACK | docs/agent-runs/live-product-infra-rpc/bridge-deploy-control-validation-report.json |
| observe | `flowchain:bridge:observe:base8453` | read-only-owner-input-gate | FLOWCHAIN_PILOT_OPERATOR_ACK | devnet/local/bridge-live-readiness/bridge-observe-base8453-report.json |
| observe | `flowchain:bridge:relayer:once` | local-l1-credit-gated | FLOWCHAIN_PILOT_OPERATOR_ACK | docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json |
| observe | `flowchain:bridge:relayer:guardrail:validate` | local-validation-no-broadcast | FLOWCHAIN_PILOT_OPERATOR_ACK | docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json |
| observe | `flowchain:bridge:relayer:loop:validate` | local-validation-no-broadcast | none | docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json |
| credit | `flowchain:bridge:runtime-credit:validate` | local-validation-no-broadcast | none | docs/agent-runs/live-product-infra-rpc/bridge-runtime-credit-validation-report.json |
| pilot-proof | `flowchain:real-value-pilot:e2e` | local-validation-no-broadcast | none | docs/agent-runs/live-product-infra-rpc/real-value-pilot-aggregate-report.json |
| credit | `flowchain:bridge:reconciliation` | local-validation-no-broadcast | none | docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-report.json |
| withdraw-release | `flowchain:bridge:withdraw:intent` | local-evidence-no-broadcast | FLOWCHAIN_PILOT_OPERATOR_ACK | devnet/local/bridge-live-readiness/bridge-withdraw-intent-report.json |
| withdraw-release | `flowchain:bridge:release:evidence` | local-evidence-no-broadcast | none | docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-report.json |
| withdraw-release | `flowchain:bridge:release:evidence:validate` | local-validation-no-broadcast | none | docs/agent-runs/live-product-infra-rpc/bridge-release-evidence-validation-report.json |
| emergency-control | `flowchain:bridge:pause` | owner-live-broadcast-gated | FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_BROADCAST_ACK | devnet/local/bridge-live-readiness/base8453-control-report.json |
| emergency-control | `flowchain:bridge:resume` | owner-live-broadcast-gated | FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_BROADCAST_ACK | devnet/local/bridge-live-readiness/base8453-control-report.json |
| emergency-control | `flowchain:bridge:emergency-stop` | owner-live-broadcast-gated | FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_BROADCAST_ACK | devnet/local/bridge-live-readiness/base8453-control-report.json |
| local-smoke | `flowchain:bridge:local-credit:smoke` | local-validation-no-broadcast | none | command-local |
| release | `flowchain:bridge:command-matrix` | local-validation-no-broadcast | none | docs/agent-runs/live-product-infra-rpc/bridge-command-matrix-report.json |
| release | `flowchain:bridge:no-secret-audit` | local-validation-no-broadcast | none | devnet/local/bridge-live-readiness/bridge-no-secret-audit-report.json |

## Owner Input Names

- FLOWCHAIN_BASE8453_ASSET_DECIMALS
- FLOWCHAIN_BASE8453_BROADCAST_ACK
- FLOWCHAIN_BASE8453_CURSOR_STATE
- FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY
- FLOWCHAIN_BASE8453_FROM_BLOCK
- FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS
- FLOWCHAIN_BASE8453_OWNER_ADDRESS
- FLOWCHAIN_BASE8453_RELEASE_AUTHORITY_ADDRESS
- FLOWCHAIN_BASE8453_RPC_URL
- FLOWCHAIN_BASE8453_SETTLEMENT_SUBMITTER_ADDRESS
- FLOWCHAIN_BASE8453_SUPPORTED_TOKEN
- FLOWCHAIN_BASE8453_TO_BLOCK
- FLOWCHAIN_PILOT_CONFIRMATIONS
- FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI
- FLOWCHAIN_PILOT_OPERATOR_ACK
- FLOWCHAIN_PILOT_TOTAL_CAP_WEI
