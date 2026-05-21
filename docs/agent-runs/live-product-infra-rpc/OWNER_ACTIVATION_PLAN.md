# FlowChain Owner Activation Plan

Generated: 2026-05-20T23:05:40.5458704+00:00
Status: passed
Activation ready: False

This plan is the current launch handoff. It records names, statuses, and commands only. Put real values in the ignored owner env file or the service environment; do not paste secrets into chat, GitHub, or generated reports.

## Current Missing Owner Inputs

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

## Activation Stages

| Stage | Status | Blocking inputs | Blocked reports | Validate with |
| --- | --- | --- | --- | --- |
| Keep the chain and private RPC running | ready | none | none | npm run flowchain:service:status -- -AllowBlocked; npm run flowchain:service:monitor |
| Fill the ignored local owner env file | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | ownerEnvReadiness | npm run flowchain:owner-env:template; npm run flowchain:owner-env:readiness:validate; npm run flowchain:owner-env:readiness -- -AllowBlocked |
| Expose repo-owned FlowChain RPC through a public HTTPS edge | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH | publicRpc, publicDeploymentContract | npm run flowchain:public-rpc:check -- -AllowBlocked; npm run flowchain:public-rpc:validate; npm run flowchain:public-rpc:abuse-test |
| Provision durable state backup storage | needs-owner-input | FLOWCHAIN_RPC_STATE_BACKUP_PATH | backup | npm run flowchain:backup:check -- -AllowBlocked; npm run flowchain:backup:restore:validate; npm run flowchain:backup:owner-path:dry-run |
| Enable capped friends-and-family tester writes | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | externalTester, externalTesterPacket, publicDeploymentContract | npm run flowchain:tester:token:setup; npm run flowchain:tester:gateway:e2e; npm run flowchain:external-tester:packet -- -AllowBlocked; npm run flowchain:external-tester:packet:validate |
| Configure capped Base 8453 bridge pilot observation | needs-owner-input | FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | bridgeLive, bridgeInfra, publicDeploymentContract | npm run flowchain:bridge:live:check -- -AllowBlocked; npm run flowchain:bridge:infra:check -- -AllowBlocked; npm run flowchain:bridge:relayer:guardrail:validate; npm run flowchain:bridge:relayer:loop:validate |
| Release the external tester packet only after public gates pass | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | externalTester, externalTesterPacket, publicDeploymentContract | npm run flowchain:wallet:live-tester:e2e; npm run flowchain:external-tester:packet -- -AllowBlocked; npm run flowchain:external-tester:packet:validate; npm run flowchain:dashboard:ui:readiness |
| Run final no-secret production audit before public use | needs-owner-input | FLOWCHAIN_RPC_PUBLIC_URL, FLOWCHAIN_RPC_ALLOWED_ORIGINS, FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE, FLOWCHAIN_RPC_TLS_TERMINATED, FLOWCHAIN_RPC_STATE_BACKUP_PATH, FLOWCHAIN_PILOT_OPERATOR_ACK, FLOWCHAIN_BASE8453_RPC_URL, FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS, FLOWCHAIN_BASE8453_SUPPORTED_TOKEN, FLOWCHAIN_BASE8453_ASSET_DECIMALS, FLOWCHAIN_BASE8453_FROM_BLOCK, FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI, FLOWCHAIN_PILOT_TOTAL_CAP_WEI, FLOWCHAIN_PILOT_CONFIRMATIONS | completionAudit, truthTable | npm run flowchain:live:cutover:rehearsal -- -AllowBlocked; npm run flowchain:completion:audit -- -AllowBlocked; npm run flowchain:truth-table -- -AllowBlocked; npm run flowchain:no-secret:scan |

## Owner Actions

### Keep the chain and private RPC running
- Choose the host that will stay online and keep the FlowChain node/control-plane running.
- Resources: Always-on Windows host, Linux host, or VPS
### Fill the ignored local owner env file
- Run the template command, fill real values only on the launch host, and point FLOWCHAIN_OWNER_ENV_FILE at that file.
- Resources: Local ignored env file or service environment
### Expose repo-owned FlowChain RPC through a public HTTPS edge
- Create DNS or a tunnel hostname for the FlowChain RPC edge.
- Terminate TLS at the edge.
- Set exact allowed browser origins and a positive per-minute rate limit.
- Resources: DNS provider or existing domain, TLS edge, reverse proxy, or tunnel
### Provision durable state backup storage
- Create a writable persistent directory available to the FlowChain service process.
- Keep the path local to the launch host or mounted as durable storage.
- Resources: Persistent local disk, mounted volume, or owner-managed backup directory
### Enable capped friends-and-family tester writes
- Run the tester token setup command to create or preserve the raw bearer token in ignored local storage.
- Store only its SHA-256 digest in the owner env file.
- Choose a small positive per-send test-unit cap.
- Resources: Owner password manager or secret store
### Configure capped Base 8453 bridge pilot observation
- Provide a Base chain 8453 HTTPS endpoint.
- Provide deployed lockbox and supported-token addresses.
- Choose the bootstrap from-block, confirmations, max deposit, total cap, and explicit capped-pilot acknowledgement.
- Resources: Base RPC provider or owner-operated Base node, Deployed pilot bridge contract details
### Release the external tester packet only after public gates pass
- Share wallet/tester instructions only after the packet report marks external sharing ready.
- Keep per-send caps low for the first pilot.
- Resources: Friends-and-family tester list
### Run final no-secret production audit before public use
- Run the aggregate gates after all owner values are configured.
- Do not announce public readiness until completionReady is true and the truth table has no owner blockers.
- Resources: None beyond the configured launch resources

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

## Next Commands

- npm run flowchain:owner-env:template
- npm run flowchain:owner-env:readiness -- -AllowBlocked
- npm run flowchain:owner-inputs -- -AllowBlocked
- npm run flowchain:public-rpc:check -- -AllowBlocked
- npm run flowchain:bridge:live:check -- -AllowBlocked
- npm run flowchain:wallet:live-tester:e2e
- npm run flowchain:live:cutover:rehearsal -- -AllowBlocked
- npm run flowchain:completion:audit -- -AllowBlocked
