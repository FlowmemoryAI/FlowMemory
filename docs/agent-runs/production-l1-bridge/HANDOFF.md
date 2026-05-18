# Handoff

Status: capped Base `8453` owner pilot bridge path implemented, deterministic-fixture proved, and live-gated.

## Contract Events

- `BridgeDeposit(bytes32 indexed depositId, uint256 indexed sourceChainId, address indexed sender, address lockbox, address token, uint256 amount, bytes32 flowchainRecipient, uint256 nonce, bytes32 metadataHash, bytes32 pilotModeTag)`
- `BridgeRelease(bytes32 indexed releaseId, bytes32 indexed depositId, address indexed recipient, address token, uint256 amount, bytes32 evidenceHash)`
- `EmergencyStopSet(bool stopped)`

## Schema Paths

- `schemas/flowmemory/bridge-deposit.schema.json`
- `schemas/flowmemory/bridge-observation.schema.json`
- `schemas/flowmemory/bridge-credit.schema.json`
- `schemas/flowmemory/bridge-runtime-credit-application.schema.json`
- `schemas/flowmemory/bridge-runtime-credit-application-state.schema.json`
- `schemas/flowmemory/bridge-pilot-evidence.schema.json`
- `schemas/flowmemory/bridge-withdrawal-intent.schema.json`
- `schemas/flowmemory/bridge-withdrawal-authorization.schema.json`
- `schemas/flowmemory/bridge-release-evidence.schema.json`
- `schemas/flowmemory/bridge-local-usage-proof.schema.json`
- `schemas/flowmemory/bridge-runtime-handoff.schema.json`

## Operator Root Commands

- `flowchain:bridge:live:check`
- `flowchain:bridge:deploy:base8453`
- `flowchain:bridge:observe:base8453`
- `flowchain:bridge:pause`
- `flowchain:bridge:resume`
- `flowchain:bridge:emergency-stop`
- `flowchain:bridge:withdraw:intent`
- `flowchain:bridge:release:evidence`
- `flowchain:bridge:local-credit:smoke`
- `flowchain:bridge:command-matrix`
- `flowchain:bridge:no-secret-audit`
- `flowchain:bridge:evidence:export`
- `flowchain:real-value-pilot:bridge`

## Env Names

- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_DEPLOYER_PRIVATE_KEY`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`
- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- broadcast only: `FLOWCHAIN_BASE8453_BROADCAST_ACK`
- optional guardrail: `FLOWCHAIN_PILOT_MAX_USD`

## Evidence Paths

- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-exact-value-report.json`
- `services/bridge-relayer/out/real-value-pilot-e2e/bridge-real-value-pilot-e2e-report.json`
- `services/bridge-relayer/out/base8453-live-readiness-check.json`
- `devnet/local/bridge-live-readiness/bridge-live-readiness-report.json`
- `devnet/local/bridge-live-readiness/base8453-deploy-readiness.json`
- `devnet/local/bridge-live-readiness/bridge-command-matrix-report.json`
- `devnet/local/bridge-live-readiness/bridge-no-secret-audit-report.json`
- `devnet/local/bridge-live-readiness/base8453-bridge-evidence-export-report.json`
- `fixtures/bridge/local-runtime-bridge-handoff.json`
- `devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json`

## RPC Fields

Bridge handoff objects expose:

- observations
- credits
- runtimeApplications
- withdrawalIntents
- pilotEvidence
- releaseEvidences
- replayProtection
- explorerSections
- workbenchTimeline

## Dashboard Fields

The bridge handoff provides dashboard/control-plane fields through:

- `explorerSections`
- `workbenchTimeline`
- `summary`
- `limitations`
- `nextCommands`
- `replayProtection`
- `runtimeApplications`

Dashboard implementation was not edited in this task.

## Remaining Blocker

Live Base deploy, deposit, observe, and release cannot be executed without owner-provided local env values:

- RPC URL
- deployer private key
- supported asset
- asset decimals
- caps
- confirmation depth
- lockbox address after deploy
- bounded block range after deposit
- operator acknowledgement
- broadcast acknowledgement for irreversible control or deploy transactions

The code fails closed when these values are missing or unsafe.
