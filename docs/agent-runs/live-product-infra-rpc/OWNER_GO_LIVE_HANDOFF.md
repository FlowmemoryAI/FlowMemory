# FlowChain Owner Go-Live Handoff

Generated: 2026-05-21T03:35:24.7340848Z
Status: passed
Release ready: False

This handoff records names, statuses, resource boundaries, and validation commands only. Put real values in the ignored owner env file or the service environment.

## Needed Now

- `FLOWCHAIN_RPC_PUBLIC_URL`
- `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
- `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
- `FLOWCHAIN_RPC_TLS_TERMINATED`
- `FLOWCHAIN_RPC_STATE_BACKUP_PATH`
- `FLOWCHAIN_PILOT_OPERATOR_ACK`
- `FLOWCHAIN_BASE8453_RPC_URL`
- `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`
- `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`
- `FLOWCHAIN_BASE8453_ASSET_DECIMALS`
- `FLOWCHAIN_BASE8453_FROM_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`

## Optional Owner Inputs

These names can tune bridge scanning, but they are not required go-live blockers.
- `FLOWCHAIN_BASE8453_TO_BLOCK`

## Stage Deck

| Stage | Status | Blocking inputs | Next command |
| --- | --- | --- | --- |
| Keep the chain and private RPC running | ready | none | npm run flowchain:service:status -- -AllowBlocked |
| Fill the ignored local owner env file | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | npm run flowchain:owner-env:template |
| Expose repo-owned FlowChain RPC through a public HTTPS edge | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH | npm run flowchain:public-rpc:check -- -AllowBlocked |
| Provision durable state backup storage | needs-owner-input | FLOWCHAIN_RPC_STATE_BACKUP_PATH | npm run flowchain:backup:check -- -AllowBlocked |
| Enable capped friends-and-family tester writes | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | npm run flowchain:tester:token:setup |
| Configure capped Base 8453 bridge pilot observation | needs-owner-input | FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | npm run flowchain:bridge:live:check -- -AllowBlocked |
| Release the external tester packet only after public gates pass | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | npm run flowchain:wallet:live-tester:e2e |
| Run final no-secret production audit before public use | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | npm run flowchain:live:cutover:rehearsal -- -AllowBlocked |

## Ordered Launch Sequence

| Step | Expected status | Stop on failure | Commands | Evidence reports |
| --- | --- | --- | --- | --- |
| Validate ignored owner inputs | passed | True | npm run flowchain:owner-env:readiness -- -AllowBlocked<br>npm run flowchain:owner-inputs -- -AllowBlocked<br>npm run flowchain:owner-inputs:validate | docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json<br>docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json<br>docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json |
| Render public RPC edge artifacts | passed | True | npm run flowchain:public-rpc:deployment-bundle<br>npm run flowchain:public-rpc:deployment:automation<br>powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/flowchain-public-rpc-deployment-automation.ps1 -Action Render -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -OwnerEnvFile <FLOWCHAIN_OWNER_ENV_FILE> -TlsCertificatePath <PATH_TO_TLS_CERTIFICATE> -TlsCertificateKeyPath <PATH_TO_TLS_CERTIFICATE_KEY> -NginxExe <FLOWCHAIN_NGINX_EXE><br>bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh plan<br>powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Plan | docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-bundle-report.json<br>docs/agent-runs/live-product-infra-rpc/public-rpc-deployment-automation-report.json |
| Plan reboot-persistent services | passed | True | npm run flowchain:service:install:systemd:validate<br>npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR><br>npm run flowchain:service:install:systemd -- -Action Plan -RenderDir <FLOWCHAIN_DEPLOY_RENDER_DIR> -StartBridgeRelayerLoop<br>bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh plan<br>powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Plan | docs/agent-runs/live-product-infra-rpc/systemd-service-install-validation-report.json |
| Apply owner-host public RPC edge | passed | True | bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh apply<br>powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Apply | docs/agent-runs/live-product-infra-rpc/systemd-service-install-report.json<br>docs/agent-runs/live-product-infra-rpc/service-status-report.json<br>docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json<br>docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json<br>docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json<br>docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json<br>docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json<br>docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json<br>docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json<br>docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json |
| Prove live service health | passed | True | npm run flowchain:service:status<br>npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30 | docs/agent-runs/live-product-infra-rpc/service-status-report.json<br>docs/agent-runs/live-product-infra-rpc/service-monitor-report.json |
| Validate public RPC exposure | passed | True | npm run flowchain:public-rpc:check -- -AllowBlocked<br>npm run flowchain:public-rpc:validate<br>npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked<br>npm run flowchain:public-rpc:abuse-test | docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json<br>docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json<br>docs/agent-runs/live-product-infra-rpc/public-rpc-synthetic-canary-report.json<br>docs/agent-runs/live-product-infra-rpc/public-rpc-abuse-test-report.json |
| Prove backup and restore | passed | True | npm run flowchain:backup:check -- -AllowBlocked<br>npm run flowchain:backup:restore:validate<br>npm run flowchain:backup:owner-path:dry-run | docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json<br>docs/agent-runs/live-product-infra-rpc/backup-restore-validation-report.json<br>docs/agent-runs/live-product-infra-rpc/backup-owner-path-dry-run-report.json |
| Harden bridge relayer pilot | passed | True | npm run flowchain:bridge:live:check -- -AllowBlocked<br>npm run flowchain:bridge:infra:check -- -AllowBlocked<br>npm run flowchain:bridge:relayer:guardrail:validate<br>npm run flowchain:bridge:relayer:loop:validate<br>npm run flowchain:bridge:relayer:once -- -AllowBlocked<br>npm run flowchain:bridge:reconciliation | docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json<br>docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json<br>docs/agent-runs/live-product-infra-rpc/bridge-relayer-guardrail-validation-report.json<br>docs/agent-runs/live-product-infra-rpc/bridge-relayer-loop-validation-report.json<br>docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json<br>docs/agent-runs/live-product-infra-rpc/bridge-reconciliation-report.json |
| Validate external tester launch | passed | True | npm run flowchain:tester:token:setup<br>npm run flowchain:tester:gateway:e2e<br>npm run flowchain:wallet:live-tester:e2e<br>npm run flowchain:external-tester:packet -- -AllowBlocked<br>npm run flowchain:external-tester:packet:validate<br>npm run flowchain:external-tester:client:validate<br>npm run flowchain:tester:evidence:validate | docs/agent-runs/live-product-infra-rpc/tester-write-token-setup-report.json<br>docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json<br>docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json<br>docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json<br>docs/agent-runs/live-product-infra-rpc/external-tester-packet-validation-report.json<br>docs/agent-runs/live-product-infra-rpc/external-tester-client-validation-report.json<br>docs/agent-runs/live-product-infra-rpc/external-tester-evidence-validation-report.json |
| Run release gates | passed | True | npm run flowchain:public-deployment:contract -- -AllowBlocked<br>npm run flowchain:live:cutover:rehearsal -- -AllowBlocked<br>npm run flowchain:completion:audit -- -AllowBlocked<br>npm run flowchain:truth-table -- -AllowBlocked<br>npm run flowchain:no-secret:scan | docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json<br>docs/agent-runs/live-product-infra-rpc/live-cutover-rehearsal-report.json<br>docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json<br>docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json<br>docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json |

## Rollback Commands

- npm run flowchain:ops:snapshot -- -AllowBlocked
- npm run flowchain:service:status
- npm run flowchain:service:restart -- -LiveProfile
- npm run flowchain:service:stop
- bash <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.sh rollback
- powershell -NoProfile -ExecutionPolicy Bypass -File <FLOWCHAIN_DEPLOY_RENDER_DIR>/owner-host-apply.ps1 -Action Rollback
- npm run flowchain:emergency:stop-local
- npm run flowchain:bridge:emergency-stop
- npm run flowchain:public-deployment:contract -- -AllowBlocked

## Package Script Coverage

- Launch sequence package scripts: 34
- Missing launch sequence package scripts: 0
- Rollback package scripts: 7
- Missing rollback package scripts: 0

## External Resources

- Always-on Windows host, Linux host, or VPS
- Local ignored env file or service environment
- DNS provider or existing domain
- TLS edge, reverse proxy, or tunnel
- Persistent local disk, mounted volume, or owner-managed backup directory
- Owner password manager or secret store
- Base RPC provider or owner-operated Base node
- Deployed pilot bridge contract details
- Friends-and-family tester list
- None beyond the configured launch resources

## Do Not Send

- Host login password
- SSH private key
- Owner env file contents
- Provider URLs that carry account tokens
- Registrar password
- tunnel token
- TLS private key
- Storage account secret
- cloud backup credentials
- Raw tester bearer token
- token hash together with the raw token
- Wallet private key
- wallet recovery words
- provider dashboard password
- Raw tester token in GitHub or chat
- owner env file contents
- Any secret-bearing provider URL
- wallet recovery material

## Validation Commands

- npm run flowchain:owner-env:template
- npm run flowchain:owner-env:readiness -- -AllowBlocked
- npm run flowchain:owner-inputs -- -AllowBlocked
- npm run flowchain:public-rpc:check -- -AllowBlocked
- npm run flowchain:bridge:live:check -- -AllowBlocked
- npm run flowchain:wallet:live-tester:e2e
- npm run flowchain:live:cutover:rehearsal -- -AllowBlocked
- npm run flowchain:completion:audit -- -AllowBlocked
- npm run flowchain:owner-inputs:validate
- npm run flowchain:owner:onboarding
- npm run flowchain:owner:signup-checklist
- npm run flowchain:owner:activation-plan
- npm run flowchain:owner:go-live-handoff
- npm run flowchain:owner-env:readiness:validate
- npm run flowchain:owner-inputs
- npm run flowchain:doctor -- -ReportPath docs/agent-runs/live-product-infra-rpc/operator-doctor-report.json
- npm run flowchain:public-rpc:edge-template
- npm run flowchain:public-rpc:deployment-bundle
- npm run flowchain:public-rpc:deployment:automation
- npm run flowchain:operator:package
- npm run flowchain:operator:package:verify
- npm run flowchain:public-rpc:validate
- npm run flowchain:public-rpc:synthetic-canary -- -AllowBlocked
- npm run flowchain:public-rpc:abuse-test
- npm run flowchain:tester:gateway:e2e
- npm run flowchain:dashboard:ui:readiness
- npm run flowchain:second-computer:readiness
- npm run flowchain:backup:restore:validate
- npm run flowchain:backup:owner-path:dry-run
- npm run flowchain:backup:create
- npm run flowchain:backup:restore:verify
- npm run flowchain:backup:check
- npm run flowchain:service:monitor
- npm run flowchain:service:supervisor:validate
- npm run flowchain:service:install:validate
- npm run flowchain:dev-pack:e2e
- npm run flowchain:bridge:relayer:guardrail:validate
- npm run flowchain:bridge:relayer:loop:validate
- npm run flowchain:bridge:runtime-credit:validate
- npm run flowchain:real-value-pilot:e2e -- -SkipBaseline -ChildTimeoutSeconds 1800
- npm run flowchain:bridge:release:evidence:validate
- npm run flowchain:ops:snapshot
- npm run flowchain:ops:alerts
- npm run flowchain:ops:alerts:install:systemd:validate
- npm run flowchain:ops:alerts:install:validate
- npm run flowchain:ops:metrics:export
- npm run flowchain:ops:metrics:install:systemd:validate
- npm run flowchain:ops:metrics:install:validate
- npm run flowchain:ops:escalation:dry-run
- npm run flowchain:ops:incident-drill
- npm run flowchain:live-infra:check
- npm run flowchain:bridge:diagnose:tx
- npm run flowchain:tester:readiness
- npm run flowchain:external-tester:packet
- npm run flowchain:external-tester:client:validate
- npm run flowchain:tester:evidence:validate
- npm run flowchain:public-deployment:contract
- npm run flowchain:architecture:audit
- npm run flowchain:live-product:e2e
- npm run flowchain:public-deployment:contract -- -AllowBlocked
- npm run flowchain:truth-table -- -AllowBlocked
- npm run flowchain:no-secret:scan
