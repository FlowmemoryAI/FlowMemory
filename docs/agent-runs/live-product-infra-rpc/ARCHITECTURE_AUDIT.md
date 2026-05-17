# FlowChain Architecture Audit

Generated: 2026-05-17T19:41:01.5773989Z
Status: blocked
Blocked only on known external owner inputs: True

## Concrete Deliverables

- A live-profile L1 node produces and finalizes blocks.
- RPC clients can connect through a private service now and through a public owner-operated edge only after TLS/CORS/rate-limit checks pass.
- Public RPC exposure has a no-values owner edge template for HTTPS reverse proxying, rate limiting, and CORS-origin forwarding.
- Wallets can be created without returned secret material and can send wallet-to-wallet transfers that settle in produced blocks.
- Friends-and-family write access has an authenticated tester gateway with cap enforcement and a local E2E proof.
- Bridge funds are modeled through a Base 8453 observer/credit path that is local-proven, stages the Base scan cursor until L1 credit proof, can queue new relayer handoffs into the L1, and remains live-blocked until owner guardrails are configured.
- State backup, monitoring, reboot-persistent service install, service lifecycle, emergency stop, and external tester packet are explicit operational boundaries.
- Owner onboarding explicitly separates the repo-owned FlowChain RPC public edge from the external Base 8453 bridge RPC dependency.
- Owner signup checklist maps the external services and local setup values needed for public operation without requesting secrets.
- The owner-operated public deployment contract has pre-exposure and rollback commands and cannot become shareable until all public gates pass.
- Every missing production edge fails closed on exact owner input names, with no secrets, env values, or live broadcasts.

## Architecture Checklist

| Layer | Requirement | Status | Evidence |
| --- | --- | --- | --- |
| L1 runtime | The block-producing node and service lifecycle are separated from RPC, run in live profile, and expose fresh state evidence. | passed | serviceStatus=passed, liveProfile=True, maxBlocks=0, nodeRunning=True, controlPlaneRunning=True, latestHeight=58713, finalizedHeight=58713 |
| Operations | Operations has explicit status, monitor, ops snapshot, scheduled alert refresh, alert rules, incident drills, and emergency controls that classify incidents separately from owner-input blockers. | passed | monitorStatus=passed, samples=2, heightAdvanced=True, supervisorValidation=passed, supervisorRestartAttempts=1, opsSnapshot=blocked, criticalCount=0, alertRules=passed, alertInstall=passed, alertInstallFailedChecks=0, criticalRules=8, blockedRules=6, unmappedAlerts=0, incidentDrill=passed, incidentCases=9, incidentFailed=0 |
| Operations | Owner-host service lifecycle includes a no-secret Windows Scheduled Task install, status, and uninstall path for reboot-persistent live supervisor autorecovery. | passed | installValidation=passed, failedChecks=0, planDidNotMutate=True, liveProfileDefault=True, relayerDefaultOff=True, relayerOptIn=True, schedulerCmdlets=True |
| RPC/API | The control-plane API has explicit health/discovery/readiness/CORS/rate-limit validation and abuse rejection before it can be exposed publicly. | passed | validationStatus=passed, corsAllowed=True, corsRejected=True, endpointChecks=True, rateLimitProbe=True, rateLimitRejected=True, rateLimitRetryAfter=True, responseHygiene=True, abuseStatus=passed, abusePassed=True, abuseMissingChecks=0 |
| Public edge | External RPC exposure is a distinct owner-operated edge with TLS, allowed origins, rate limits, endpoint checks, and response hygiene. | blocked | publicRpcStatus=blocked, publicRpcReady=False |
| Public edge | Public RPC exposure has a no-values owner edge template and render-validated deployment bundle for HTTPS reverse proxying, rate limiting, verification, and rollback. | passed | edgeTemplateStatus=passed, bundleStatus=passed, renderValidation=True, repoOwned=True, requiresTls=True, requiresRateLimit=True, forwardsOrigin=True |
| Public edge | Public RPC deployment automation renders concrete owner-host Nginx, systemd, shell preflight, Windows preflight, post-deploy verification, and rollback phases without host mutation or owner-value leakage. | passed | automationStatus=passed, action=Validate, renderCommand=True, noPlaceholders=True, hostMutationFalse=True |
| Wallets | Wallet creation and wallet-to-wallet transfer are routed through the RPC/control-plane boundary into runtime blocks without returning secret material. | passed | walletStatus=passed, testerStatus=passed, testerWalletCreates=4, testerSecretLeak=False |
| Bridge | The bridge architecture has a deterministic local proof for exact value, replay protection, wrong-chain rejection, unapproved-lockbox rejection, and no broadcast. | passed | broadcast=False, allAmountsEqual=True, wrongChainRejected=True, unapprovedContractRejected=True |
| Bridge | Live Base 8453 bridge observation is isolated behind owner guardrails, read-only diagnostics, confirmation/cap settings, and no-broadcast checks. | blocked | bridgeLive=blocked, bridgeInfra=blocked, baseTxDiagnostic=blocked, baseTxSafe=True |
| Bridge | The live bridge relayer path checks owner guardrails, observes Base 8453 deposits with a staged cursor, builds runtime handoff, filters already-seen replay keys, queues new credits into the running L1, waits for main-state credit evidence, commits the Base cursor only after safe proof without broadcasts, and proves missing-owner-input runs leave cursor state untouched. | blocked | relayer=blocked, guardrail=passed, observed=0, new=0, queued=0, applied=0, cursorCommitRequired=True, cursorCommitted=False, cursorReason=not-run |
| Storage/recovery | Live state backup and restore are separate configured storage boundaries with manifest hash proof, latest-pointer proof, scheduled backup install proof, live-state protection, and adversarial tamper/missing-artifact/wrong-chain rejection before public operation. | blocked | backupStatus=blocked, validationStatus=passed, installValidation=passed, installFailedChecks=0, snapshotProof=not-run, restoreProof=not-run, requiredChecks=15, missingChecks=0 |
| Deployment | The owner-operated public deployment contract is machine-checkable, includes rollback commands, and blocks sharing until public RPC, backup, bridge, and tester gates pass. | blocked | deploymentStatus=blocked, deploymentReady=False, packetShareable=False, packetSmoke=True, blockedOnlyKnown=True, blockedItems=6, failedItems=0 |
| Governance/safety | Live-only inputs are externally owned, listed by name only, self-tested for missing/invalid/valid direct env plus local owner env-file loading, and fail closed on missing or malformed owner env files without printing values. | passed | ownerInputsStatus=blocked, validationStatus=passed, ownerEnvFilePasses=True, missingOwnerEnvFileFails=True, malformedOwnerEnvFileFails=True, knownMissingInputs=17, unknownInputs=0 |
| Governance/safety | The ignored owner env file is a first-class setup boundary that can drive owner-input, live-infra, and public deployment gates through one redacted command. | blocked | readinessStatus=blocked, validationStatus=passed, missingFails=True, unignoredFails=True, gitIgnored=True, blockedOnlyKnown=True |
| Governance/safety | Owner onboarding distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency and gives no-values setup commands. | passed | onboardingStatus=passed, flowChainRpcIsOurs=True, thirdPartyFlowChainRpcProviderNeeded=False, publicRpcRequiresOwnerPublicEdge=True, base8453RpcIsExternalChainDependency=True, localEnvFileSupported=True |
| Governance/safety | Owner signup checklist maps public RPC edge, tester write token/cap, always-on host, backup storage, Base 8453 RPC, bridge details, and local env-file setup to exact owner actions without requesting secrets. | passed | signupStatus=passed, itemCount=9, externalSignupCount=3, missingCoverage=0, repoOwned=True, localEnvFileSupported=True |
| Security | Architecture reports and live-readiness commands preserve the no-secret and no-live-broadcast safety boundary. | passed | noSecretStatus=passed, liveProductNoLiveBroadcast=True, liveProductEnvValuesPrinted=False, baseTxBroadcasts=False, devPackNoSecrets=True |
| Developer ecosystem | Developer SDK/devkit and docs connect to the real FlowChain RPC, generate a live RPC reference, read wallet data, submit a runtime-backed local wallet send, and fail closed for public readiness. | passed | devPackStatus=passed, methodCount=79, heights=43368->43369, report=E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-dev-pack\dev-pack-e2e-report.json |
| External tester launch | Friends-and-family tester sharing requires fresh tester-wallet evidence and executable packet-route smoke, and remains blocked until public RPC, backup, and Base bridge gates pass. | blocked | externalTester=blocked, testerNetworkFresh=True, packet=blocked, packetShareable=False, packetSmoke=True, smokeRoutes=13, externalSharingReady=False |
| External tester launch | Public tester write gateway has a local production-shaped E2E proof for bearer auth, public-only wallet creation, capped wallet sends, balance settlement, and over-cap rejection. | passed | gatewayStatus=passed, configured=True, transferAccepted=True, capRejected=True, report=E:\FlowMemory\flowmemory-live-infra-rpc\docs\agent-runs\live-product-infra-rpc\public-tester-gateway-e2e-report.json |
| Verification | Product-level verification composes runtime, RPC, wallets, public tester gateway, bridge, backup, public deployment contract, executable external tester packet smoke, developer dev-pack, and completion evidence into one auditable path. | passed | liveInfra=blocked, liveProduct=blocked, externalTester=blocked, testerNetworkFresh=True, externalTesterPacket=blocked, packetSmoke=True, publicTesterGateway=passed, devPack=passed |

## Data Flows

- private-local-wallet-transfer: tester wallet create -> control-plane /wallets/create -> wallet public metadata -> control-plane /wallets/send -> live node inbox -> runtime block -> wallet balance/transfer reads
- owner-host-service-lifecycle: Windows Scheduled Task -> repo working directory -> live service supervisor -> service status check -> restart with live profile -> private node/control-plane recovery
- public-tester-gateway: tester bearer token -> public edge /tester/wallets/create -> public-only wallet metadata -> public edge /tester/wallets/send -> cap enforcement -> runtime block -> balance proof
- developer-dev-pack: developer CLI/SDK -> control-plane /rpc -> rpc_discover -> wallet balance/history reads -> control-plane /wallets/send -> runtime block -> generated RPC reference
- public-rpc-exposure: owner TLS endpoint -> allowed-origin/rate-limit gate -> control-plane HTTP server -> JSON-RPC/REST methods -> runtime state reads
- public-rpc-edge-template: placeholder edge config -> owner DNS/TLS -> rate-limited reverse proxy -> private FlowChain RPC origin -> readiness gates
- owner-public-edge-onboarding: owner signup decisions -> public DNS/TLS/proxy -> repo-owned FlowChain RPC origin -> local-only env values -> public readiness gates
- owner-signup-checklist: owner signup/setup list -> public RPC hostname -> tester write token hash and cap -> always-on host -> backup storage -> Base 8453 RPC -> bridge pilot values -> local env-file loader
- base8453-bridge-credit: Base 8453 lockbox event -> staged scan cursor -> read-only bridge observer -> deposit validation -> bridge credit handoff -> runtime block inclusion -> safe cursor commit -> wallet spend path
- state-recovery: runtime state file -> service status/readiness -> owner backup path -> write/read backup proof -> operator recovery command

## Remaining External Owner Inputs

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

## Architecture Decision

The local architecture is explicit and evidence-backed, but public RPC, tester write gateway, backup, and/or Base 8453 live edges remain blocked until exact owner inputs are configured.
