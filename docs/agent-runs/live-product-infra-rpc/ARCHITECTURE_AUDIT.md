# FlowChain Architecture Audit

Generated: 2026-05-16T00:43:26.8898375Z
Status: blocked
Blocked only on known external owner inputs: True

## Concrete Deliverables

- A live-profile L1 node produces and finalizes blocks.
- RPC clients can connect through a private service now and through a public owner-operated edge only after TLS/CORS/rate-limit checks pass.
- Public RPC exposure has a no-values owner edge template for HTTPS reverse proxying, rate limiting, and CORS-origin forwarding.
- Wallets can be created without returned secret material and can send wallet-to-wallet transfers that settle in produced blocks.
- Bridge funds are modeled through a Base 8453 observer/credit path that is local-proven and live-blocked until owner guardrails are configured.
- State backup, monitoring, service lifecycle, emergency stop, and external tester packet are explicit operational boundaries.
- Owner onboarding explicitly separates the repo-owned FlowChain RPC public edge from the external Base 8453 bridge RPC dependency.
- Owner signup checklist maps the external services and local setup values needed for public operation without requesting secrets.
- The owner-operated public deployment contract has pre-exposure and rollback commands and cannot become shareable until all public gates pass.
- Every missing production edge fails closed on exact owner input names, with no secrets, env values, or live broadcasts.

## Architecture Checklist

| Layer | Requirement | Status | Evidence |
| --- | --- | --- | --- |
| L1 runtime | The block-producing node and service lifecycle are separated from RPC, run in live profile, and expose fresh state evidence. | passed | serviceStatus=passed, liveProfile=True, maxBlocks=0, nodeRunning=True, controlPlaneRunning=True, latestHeight=25272, finalizedHeight=25272 |
| Operations | Operations has explicit status, monitor, and emergency-stop controls that do not depend on public deployment being live. | passed | monitorStatus=passed, samples=2, heightAdvanced=True |
| RPC/API | The control-plane API has explicit health/discovery/readiness/CORS/rate-limit validation before it can be exposed publicly. | passed | validationStatus=passed, corsAllowed=True, corsRejected=True, endpointChecks=True, rateLimitProbe=True, rateLimitRejected=True, rateLimitRetryAfter=True, responseHygiene=True |
| Public edge | External RPC exposure is a distinct owner-operated edge with TLS, allowed origins, rate limits, endpoint checks, and response hygiene. | blocked | publicRpcStatus=blocked, publicRpcReady=False |
| Public edge | Public RPC exposure has a no-values owner edge template for HTTPS reverse proxying, rate limiting, and CORS-origin forwarding. | passed | edgeTemplateStatus=passed, repoOwned=True, requiresTls=True, requiresRateLimit=True, forwardsOrigin=True |
| Wallets | Wallet creation and wallet-to-wallet transfer are routed through the RPC/control-plane boundary into runtime blocks without returning secret material. | passed | walletStatus=passed, testerStatus=passed, testerWalletCreates=4, testerSecretLeak=False |
| Bridge | The bridge architecture has a deterministic local proof for exact value, replay protection, wrong-chain rejection, unapproved-lockbox rejection, and no broadcast. | passed | broadcast=False, allAmountsEqual=True, wrongChainRejected=True, unapprovedContractRejected=True |
| Bridge | Live Base 8453 bridge observation is isolated behind owner guardrails, read-only diagnostics, confirmation/cap settings, and no-broadcast checks. | blocked | bridgeLive=blocked, bridgeInfra=blocked, baseTxDiagnostic=blocked, baseTxSafe=True |
| Storage/recovery | Live state backup is a separate configured storage boundary that must prove writable/readable before public operation. | blocked | backupStatus=blocked |
| Deployment | The owner-operated public deployment contract is machine-checkable, includes rollback commands, and blocks sharing until public RPC, backup, bridge, and tester gates pass. | blocked | deploymentStatus=blocked, deploymentReady=False, blockedOnlyKnown=True, blockedItems=5, failedItems=0 |
| Governance/safety | Live-only inputs are externally owned, listed by name only, self-tested for missing/invalid/valid direct env plus local owner env-file loading, and fail closed on missing or malformed owner env files without printing values. | passed | ownerInputsStatus=blocked, validationStatus=passed, ownerEnvFilePasses=True, missingOwnerEnvFileFails=True, malformedOwnerEnvFileFails=True, knownMissingInputs=15, unknownInputs=0 |
| Governance/safety | The ignored owner env file is a first-class setup boundary that can drive owner-input, live-infra, and public deployment gates through one redacted command. | blocked | readinessStatus=blocked, validationStatus=passed, missingFails=True, unignoredFails=True, gitIgnored=True, blockedOnlyKnown=True |
| Governance/safety | Owner onboarding distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency and gives no-values setup commands. | passed | onboardingStatus=passed, flowChainRpcIsOurs=True, thirdPartyFlowChainRpcProviderNeeded=False, publicRpcRequiresOwnerPublicEdge=True, base8453RpcIsExternalChainDependency=True, localEnvFileSupported=True |
| Governance/safety | Owner signup checklist maps public RPC edge, always-on host, backup storage, Base 8453 RPC, bridge details, and local env-file setup to exact owner actions without requesting secrets. | passed | signupStatus=passed, itemCount=8, externalSignupCount=3, missingCoverage=0, repoOwned=True, localEnvFileSupported=True |
| Security | Architecture reports and live-readiness commands preserve the no-secret and no-live-broadcast safety boundary. | passed | noSecretStatus=passed, liveProductNoLiveBroadcast=True, liveProductEnvValuesPrinted=False, baseTxBroadcasts=False |
| Verification | Product-level verification composes runtime, RPC, wallets, bridge, backup, public deployment contract, external tester packet, and completion evidence into one auditable path. | passed | liveInfra=blocked, liveProduct=blocked, externalTester=blocked, testerNetworkFresh=True, externalTesterPacket=blocked |

## Data Flows

- private-local-wallet-transfer: tester wallet create -> control-plane /wallets/create -> wallet public metadata -> control-plane /wallets/send -> live node inbox -> runtime block -> wallet balance/transfer reads
- public-rpc-exposure: owner TLS endpoint -> allowed-origin/rate-limit gate -> control-plane HTTP server -> JSON-RPC/REST methods -> runtime state reads
- public-rpc-edge-template: placeholder edge config -> owner DNS/TLS -> rate-limited reverse proxy -> private FlowChain RPC origin -> readiness gates
- owner-public-edge-onboarding: owner signup decisions -> public DNS/TLS/proxy -> repo-owned FlowChain RPC origin -> local-only env values -> public readiness gates
- owner-signup-checklist: owner signup/setup list -> public RPC hostname -> always-on host -> backup storage -> Base 8453 RPC -> bridge pilot values -> local env-file loader
- base8453-bridge-credit: Base 8453 lockbox event -> read-only bridge observer -> deposit validation -> bridge credit handoff -> runtime block inclusion -> wallet spend path
- state-recovery: runtime state file -> service status/readiness -> owner backup path -> write/read backup proof -> operator recovery command

## Remaining External Owner Inputs

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

## Architecture Decision

The local architecture is explicit and evidence-backed, but public RPC, backup, and/or Base 8453 live edges remain blocked until exact owner inputs are configured.
