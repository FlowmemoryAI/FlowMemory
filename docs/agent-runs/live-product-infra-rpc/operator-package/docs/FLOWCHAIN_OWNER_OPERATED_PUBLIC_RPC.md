# FlowChain Owner-Operated Public RPC Runbook

Status: fail-closed operator path. This document does not claim broad public use readiness.

## What Code Provides

The repository now provides:

- `npm run flowchain:service:start` for supervised node and control-plane processes on Windows.
- `npm run flowchain:service:status` for safe process, bind, height, backup, and bridge status.
- `npm run flowchain:service:monitor` for repeated live service sampling that proves height progression over an operator-selected window.
- `npm run flowchain:service:install:systemd:validate` for a no-secret Linux systemd live-service and supervisor install plan check.
- `npm run flowchain:ops:snapshot` for one no-secret operator report that classifies critical incidents, public-readiness blockers, and incident commands.
- `npm run flowchain:ops:incident-drill` for a synthetic no-values incident drill that proves node-down, control-plane-down, stale-state, stalled-height, and no-secret failures are classified as critical while owner-input blockers stay non-critical.
- `npm run flowchain:ops:metrics:export` for no-secret JSON and Prometheus textfile metrics that owner-operated collectors can scrape locally.
- `npm run flowchain:ops:alerts:install:windows` and `npm run flowchain:ops:alerts:install:validate` for a no-secret Windows Scheduled Task install/status/uninstall path for recurring local alert refresh.
- `npm run flowchain:service:stop` and `npm run flowchain:service:restart`, which preserve runtime state.
- `npm run flowchain:public-rpc:check` for endpoint, TLS, CORS, rate-limit, health, discovery, readiness, state, and response-hygiene checks.
- `npm run flowchain:public-rpc:edge-template` for a no-values Nginx public-edge template that proxies this chain's private RPC origin through owner TLS and rate limiting.
- `npm run flowchain:public-rpc:deployment-bundle` for a placeholder-only public RPC deployment bundle with edge config, env example, verification steps, and rollback steps.
- `npm run flowchain:public-rpc:validate` for a temporary local control-plane rehearsal of the public RPC readiness script, including allowed-origin acceptance, disallowed-origin rejection, endpoint checks, and response hygiene.
- `npm run flowchain:backup:create` for manifest-backed live state snapshots.
- `npm run flowchain:backup:restore:verify` for restore rehearsal from the latest snapshot without mutating live state.
- `npm run flowchain:backup:restore:validate` for a local self-test that proves snapshot/restore round-trip integrity and detects corrupted snapshots.
- `npm run flowchain:backup:check` for owner backup path readiness, including snapshot and restore proof.
- `npm run flowchain:backup:install:windows`, `npm run flowchain:backup:install:systemd`, and `npm run flowchain:backup:install:validate` for no-secret Windows Scheduled Task and Linux systemd install/status/uninstall paths for recurring state snapshots.
- `npm run flowchain:bridge:infra:check` for Base 8453 deployment input checks.
- `npm run flowchain:bridge:relayer:once` for the no-broadcast Base 8453 observer-to-L1 queue path.
- `npm run flowchain:bridge:diagnose:tx` for read-only diagnosis of an owner-supplied Base 8453 transaction hash.
- `npm run flowchain:live-infra:check` as the aggregate gate, including owner input contract, public RPC, service status, backup, bridge, and no-secret checks.
- `npm run flowchain:wallet:live-service:e2e` for a private local RPC proof that `/wallets/send` queues into the running node inbox and the node applies the transfer in produced blocks.
- `npm run flowchain:wallet:live-tester:e2e` for a private local RPC proof that multiple isolated tester wallets can be created, funded with local test units, and used for wallet-to-wallet transfers on produced blocks.
- `npm run flowchain:tester:gateway:e2e` for a temporary local public-tester-gateway proof that `/tester/wallets/create` and `/tester/wallets/send` require bearer authorization, enforce the send cap, and settle a capped wallet transfer on produced blocks.
- `npm run flowchain:tester:readiness` for a fail-closed decision report before inviting external testers; it refreshes service and live-infra status and requires a fresh live tester-wallet network proof.
- `npm run flowchain:owner:onboarding` for a no-values owner packet that distinguishes repo-owned FlowChain RPC from the external Base 8453 RPC dependency and lists the signup/setup groups.
- `npm run flowchain:owner:signup-checklist` for a no-values owner checklist that maps public RPC edge, tester write token/cap, always-on host, backup storage, Base 8453 RPC, bridge details, and local env-file setup to exact owner actions.
- `npm run flowchain:owner:activation-plan` for the ordered launch activation plan that maps the remaining owner inputs to stages, exact validation commands, resource boundaries, and no-secret handoff instructions.
- `npm run flowchain:owner-env:template` for an ignored local owner env-file scaffold with empty assignments only.
- `npm run flowchain:owner-env:readiness:validate` for a no-values self-test proving unsafe owner env-file paths fail before live gates run.
- `npm run flowchain:owner-env:readiness` for a one-command owner env-file readiness gate that runs owner inputs, live infrastructure, and public deployment checks with redacted output.
- `npm run flowchain:owner-inputs` for a no-values owner input contract report covering public RPC, tester write gateway, backup, and Base 8453 bridge env names.
- `npm run flowchain:owner-inputs:validate` for a no-values self-test proving missing inputs block, invalid inputs fail, and structurally valid dummy inputs pass.
- `npm run flowchain:external-tester:packet` for a tester handoff packet that remains marked not shareable until the external readiness gates pass.
- `npm run flowchain:public-deployment:contract` for a no-values public deployment contract that ties origin service status, public RPC, backup, bridge, tester sharing, rollback commands, and owner inputs into one machine-readable gate.
- `npm run flowchain:architecture:audit` for a no-values architecture audit that maps runtime, RPC, wallets, bridge, backup, operations, verification, and fail-closed owner boundaries to concrete evidence.
- `npm run flowchain:dashboard:ui:readiness` for desktop and mobile browser verification of tester wallet create, faucet, send, Explorer inspection, tester launch readiness, and the L1 activation cockpit.
- `npm run flowchain:completion:audit` for the full prompt-to-artifact completion audit before claiming readiness.
- `npm run flowchain:live-product:e2e` as the product-level aggregate that runs the local production-shaped path, restores the live service profile, runs the live-service wallet transfer proofs, and then runs live-infra readiness.

## What The Owner Must Provide

FlowChain RPC is implemented by this repository. The owner does not need a third-party FlowChain RPC provider. The owner must provide a public HTTPS edge in front of the private local origin and set these values in the local shell or service environment only:

```powershell
$env:FLOWCHAIN_RPC_PUBLIC_URL="<https endpoint exposed by the owner TLS proxy>"
$env:FLOWCHAIN_RPC_ALLOWED_ORIGINS="<comma-separated HTTPS origins>"
$env:FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE="<positive integer>"
$env:FLOWCHAIN_RPC_TLS_TERMINATED="true"
$env:FLOWCHAIN_RPC_STATE_BACKUP_PATH="<existing writable backup directory>"
```

To let invited friends-and-family testers create wallets or send capped
wallet-to-wallet transfers through the public edge, the owner must also create a
separate out-of-band tester bearer token, store only its SHA-256 hex digest in
the service environment, and set a small per-send cap:

```powershell
$env:FLOWCHAIN_TESTER_WRITE_ENABLED="true"
$env:FLOWCHAIN_TESTER_WRITE_TOKEN_SHA256="<64-character sha256 hex of tester bearer token>"
$env:FLOWCHAIN_TESTER_MAX_SEND_UNITS="<positive integer local test-unit cap per send>"
```

Do not commit or paste the raw tester bearer token. Give it only to approved
testers through a separate private channel. The public edge must forward the
`Authorization` header only to the authenticated tester gateway paths and must
keep the private local `/wallets/create` and `/wallets/send` routes unavailable
from the public internet.

The owner must also provide the Base 8453 bridge env contract before the bridge checks can pass. This is the separate external-chain dependency: use a Base 8453 RPC provider or an owner-operated Base node, not a FlowChain RPC provider.

```powershell
$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
$env:FLOWCHAIN_BASE8453_RPC_URL="<Base 8453 RPC endpoint>"
$env:FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS="<deployed lockbox address>"
$env:FLOWCHAIN_BASE8453_SUPPORTED_TOKEN="<0x0000000000000000000000000000000000000000 or ERC-20 address>"
$env:FLOWCHAIN_BASE8453_ASSET_DECIMALS="<decimal count>"
$env:FLOWCHAIN_BASE8453_FROM_BLOCK="<first bounded block>"
$env:FLOWCHAIN_BASE8453_CURSOR_STATE="services/bridge-relayer/out/base8453-pilot-cursor-state.json"
$env:FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI="<per-deposit cap>"
$env:FLOWCHAIN_PILOT_TOTAL_CAP_WEI="<total cap>"
$env:FLOWCHAIN_PILOT_CONFIRMATIONS="<confirmation depth>"
```

`FLOWCHAIN_BASE8453_TO_BLOCK` is optional for one-off bounded scans. The service
relayer loop uses the persisted cursor and confirmed Base head when it is not
set.

Do not commit these values.

Before deploying or controlling the Base 8453 lockbox, run:

```powershell
npm run flowchain:bridge:deploy:control:validate
```

That gate is no-broadcast and verifies deploy, pause, resume, and emergency-stop
commands fail closed until the owner intentionally provides the required local
env and broadcast acknowledgement.

## Recommended Windows Host Shape

Use a Windows machine or VM where the FlowChain control plane binds privately to `127.0.0.1:8787`. Put a TLS-terminating reverse proxy or tunnel in front of it. The public URL should point to the proxy, not directly to an unencrypted local process.

Minimum proxy controls:

- TLS termination with a valid certificate.
- Only configured CORS origins from `FLOWCHAIN_RPC_ALLOWED_ORIGINS`.
- Rejection of browser requests from origins outside `FLOWCHAIN_RPC_ALLOWED_ORIGINS`; the public RPC readiness gate probes both an allowed and a disallowed origin.
- Per-minute rate limit matching `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`; the control-plane server also enforces this env value when configured, and the proxy should apply the same or stricter limit.
- No request logging of secrets or raw signed payloads.
- Access to `/health`, `/rpc/discover`, `/rpc/readiness`, `/chain/status`, `/wallets/operator`, `/bridge/live-readiness`, `/tester/status`, and `/rpc`.
- Authenticated POST access to `/tester/wallets/create` and `/tester/wallets/send` only when the tester write env contract is configured.

Generate a no-values Nginx template before rendering host-specific config:

```powershell
npm run flowchain:public-rpc:edge-template
```

The generated `PUBLIC_RPC_EDGE_TEMPLATE.md` must stay placeholder-only. Render hostnames, certificate paths, and any provider-specific values outside the repository.

Provider-specific credentials, DNS names, tunnel URLs, tokens, and webhook URLs stay outside the repo.

For local operation, the owner can set values directly in the shell or point `FLOWCHAIN_OWNER_ENV_FILE` at an ignored local `NAME=value` file. Run `npm run flowchain:owner-env:template` to create the default ignored scaffold at `devnet/local/owner-inputs/flowchain-owner.local.env`. Run `npm run flowchain:owner-env:readiness:validate` to prove missing or unignored owner env-file paths fail before live gates run. After filling the ignored file, run `npm run flowchain:owner-env:readiness -- -AllowBlocked` to validate the local file against owner inputs, live infrastructure, and public deployment gates without printing values. The shared parser imports only known FlowChain owner env names and does not execute the file as PowerShell.

Generate the no-values signup checklist before the owner buys or configures services:

```powershell
npm run flowchain:owner:signup-checklist
npm run flowchain:owner-env:template
npm run flowchain:owner-env:readiness:validate
npm run flowchain:owner-env:readiness -- -AllowBlocked
```

The generated `OWNER_SIGNUP_CHECKLIST.md` distinguishes what the owner must get from what must never be pasted into chat or committed files.

## Start Services

Prepare local state first if this is a clean host:

```powershell
npm run flowchain:init
```

Start node and control-plane services with the live profile:

```powershell
npm run flowchain:service:start -- -LiveProfile
```

The live profile rejects bounded `MaxBlocks` mode. Local defaults bind to `127.0.0.1`.
The service manager also refuses to treat an existing port-8787 process as healthy
unless its command line points at this repository's control-plane server path.
When `FLOWCHAIN_RPC_ALLOWED_ORIGINS` is present in the control-plane service
environment, the server returns CORS only for those browser origins and rejects
other browser origins with `403`. Keep the reverse proxy policy at least as
strict as the service policy.

Check safe status:

```powershell
npm run flowchain:service:status
npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30
```

The local control plane reports the active runtime block stream from
`devnet/local/state.json` through:

```text
GET  /chain/status
GET  /state
POST /rpc method=block_get
POST /rpc method=block_list with params.source="active-local-runtime"
```

Use these endpoints to confirm that the local chain is still producing blocks
before exposing the proxy.

`/rpc/readiness` also validates the public RPC env contract without printing
values. It reports failed readiness for malformed public URLs, wildcard CORS in
public mode, invalid rate-limit values, or a missing TLS acknowledgement.

Stop or restart without deleting runtime data:

```powershell
npm run flowchain:service:stop
npm run flowchain:service:restart -- -LiveProfile
```

## Optional Relayer Loop

After the Base 8453 env contract is configured and checked, the owner can run a
single relayer pass or start the relayer loop:

```powershell
npm run flowchain:bridge:relayer:once
npm run flowchain:service:start -- -LiveProfile -StartBridgeRelayerLoop
```

This path advances `services/bridge-relayer/out/base8453-pilot-cursor-state.json`
only after a confirmed successful read, builds an applied runtime handoff,
filters already-seen replay keys, queues new bridge credits into the running L1,
waits for main-state credit evidence, and does not broadcast. Keep loop logs
under `devnet/local/services/logs/`.

## Base Transaction Diagnosis

After the Base 8453 env contract is configured, an owner can diagnose a specific Base transaction without providing a private key:

```powershell
$env:FLOWCHAIN_BASE8453_TX_HASH="<owner-supplied Base transaction hash>"
npm run flowchain:bridge:diagnose:tx
```

The diagnostic can also be run with an explicit argument:

```powershell
npm run flowchain:bridge:diagnose:tx -- --tx-hash <owner-supplied-base-tx-hash>
```

The diagnostic is read-only. It uses the configured Base RPC URL, lockbox address, supported token, and confirmation policy from the local environment, writes a report, and must not print RPC values, private keys, or seed material.

## Readiness Gate

Run:

```powershell
npm run flowchain:live-infra:check
```

The report is written to:

```text
docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json
```

Expected behavior:

- Owner public RPC, tester write gateway, backup, and Base 8453 bridge env names are checked first through the no-values owner input contract.
- Missing owner inputs produce `blocked` and list env names only.
- Structurally invalid owner inputs produce `failed` and list env names only.
- Missing local runtime artifacts list artifact names such as `devnet/local/state.json`.
- Stopped supervised processes list pid artifact names such as `devnet/local/services/control-plane.pid`.
- Success requires public RPC, services, backup, bridge live check, bridge infra check, and no-secret scan to pass together.
- Bridge readiness includes the relayer once gate, which must either be blocked
  only on owner Base inputs or prove that new observed credits are queued into
  the L1 main state.

For the broader product gate, run:

```powershell
npm run flowchain:live-product:e2e
```

Without owner-provided public RPC, tester write gateway, backup, and Base 8453 bridge inputs, this command exits `blocked` after writing:

```text
docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json
```

It must not be treated as public/live-ready unless both the production-shaped local aggregate and live-infra readiness are `passed`.

To verify wallet-to-wallet local transfer against the currently running private service without public exposure, run:

```powershell
npm run flowchain:wallet:live-service:e2e
```

The report is written to:

```text
docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json
```

This command creates local test-unit accounts only, uses the private `127.0.0.1` RPC service, and does not broadcast to Base.

To rehearse a small tester group against the currently running private service, run:

```powershell
npm run flowchain:wallet:live-tester:e2e
```

The report is written to:

```text
docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json
```

This command creates isolated local tester wallets through private local `/wallets/create`, excludes signing material from responses, funds the public account ids with local test units, sends a ring of wallet transfers through private local `/wallets/send`, and verifies exact final balances after the node produces blocks. Public friends-and-family writes must use `/tester/wallets/create` and `/tester/wallets/send` through the authenticated tester gateway after public RPC, tester write, backup, and bridge readiness gates pass.

To prove the public tester gateway path itself with a temporary local server and
dummy in-process token, run:

```powershell
npm run flowchain:tester:gateway:e2e
```

The report is written to:

```text
docs/agent-runs/live-product-infra-rpc/public-tester-gateway-e2e-report.json
```

This command does not use real owner tokens. It starts a localhost-only
control-plane with a temporary tester token hash, creates two tester wallets via
`/tester/wallets/create`, funds them with local test units, sends a capped
transfer through `/tester/wallets/send`, verifies final balances, and confirms
an over-cap send fails closed.

Before sharing the network with external testers, run:

```powershell
npm run flowchain:owner-inputs:validate
npm run flowchain:owner:signup-checklist
npm run flowchain:owner-env:template
npm run flowchain:owner-env:readiness:validate
npm run flowchain:owner-env:readiness -- -AllowBlocked
npm run flowchain:owner-inputs
npm run flowchain:public-rpc:validate
npm run flowchain:tester:gateway:e2e
npm run flowchain:public-deployment:contract
npm run flowchain:architecture:audit
npm run flowchain:tester:readiness
npm run flowchain:external-tester:packet
```

Without owner-provided public RPC, tester write gateway, backup, and Base 8453 bridge inputs, this command exits blocked after writing:

```text
docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json
docs/agent-runs/live-product-infra-rpc/OWNER_INPUTS.md
docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json
docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json
docs/agent-runs/live-product-infra-rpc/OWNER_SIGNUP_CHECKLIST.md
docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json
docs/agent-runs/live-product-infra-rpc/OWNER_ENV_TEMPLATE.md
docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json
docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json
docs/agent-runs/live-product-infra-rpc/OWNER_ENV_READINESS.md
docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json
docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json
docs/agent-runs/live-product-infra-rpc/PUBLIC_DEPLOYMENT_CONTRACT.md
docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json
docs/agent-runs/live-product-infra-rpc/ARCHITECTURE_AUDIT.md
docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json
docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json
docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET.md
```

Use `npm run flowchain:tester:readiness -- -AllowBlocked` only when you want to refresh the report while keeping the blocked status as evidence.
Use `npm run flowchain:external-tester:packet -- -AllowBlocked` to refresh the tester packet while preserving its not-shareable decision.
Use `npm run flowchain:public-deployment:contract -- -AllowBlocked` to refresh the public deployment contract while preserving the blocked exposure decision.
Use `npm run flowchain:architecture:audit -- -AllowBlocked` to refresh the architecture evidence while preserving owner-input blockers.

For a full completion audit, run:

```powershell
npm run flowchain:completion:audit
```

Without owner-provided public RPC, tester write gateway, backup, and Base 8453 bridge inputs, this command exits blocked after writing:

```text
docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json
docs/agent-runs/live-product-infra-rpc/COMPLETION_AUDIT.md
```

Use `npm run flowchain:completion:audit -- -AllowBlocked` only when you want to refresh the audit report while preserving the blocked completion decision.

## Evidence For Review

Use these paths for handoff:

```text
docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json
docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json
docs/agent-runs/live-product-infra-rpc/service-status-report.json
docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json
docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json
docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json
docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json
docs/agent-runs/live-product-infra-rpc/OWNER_INPUTS.md
docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json
docs/agent-runs/live-product-infra-rpc/OWNER_SIGNUP_CHECKLIST.md
docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json
docs/agent-runs/live-product-infra-rpc/OWNER_ENV_TEMPLATE.md
docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json
docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json
docs/agent-runs/live-product-infra-rpc/OWNER_ENV_READINESS.md
docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json
docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET.md
docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json
docs/agent-runs/live-product-infra-rpc/COMPLETION_AUDIT.md
docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json
docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json
docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json
docs/agent-runs/live-product-infra-rpc/bridge-relayer-once-report.json
docs/agent-runs/live-product-infra-rpc/no-secret-scan-report.json
docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json
docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json
```
