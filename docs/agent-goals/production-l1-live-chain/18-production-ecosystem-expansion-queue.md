# FlowChain Production Ecosystem Expansion Queue

Status: copy-ready `/goal` prompt pack for continuing the FlowChain L1 buildout.
This file is a planning and worker-handoff artifact. It is not proof that the
chain is live, externally reachable, bridge-enabled, audited, or production
ready.

The queue below focuses on the largest remaining FlowChain L1 workstreams that
are likely to consume the most engineering time and Codex tokens. Each
workstream is scoped so a future worker can pick it up, inventory the repo, make
real changes, verify them, and leave behind evidence without inventing
production claims.

## Global Execution Rules

- Treat local-only behavior as local-only. Do not describe it as public mainnet,
  production, or externally live until a live endpoint and owner-provided
  infrastructure have been verified.
- Do not broadcast live bridge transactions unless the owner has explicitly
  provided the required Base 8453 inputs and the scripts have a dry-run,
  allowlist, and confirmation gate.
- Never print or commit private keys, seed phrases, mnemonics, API keys, RPC
  credentials, webhook URLs, raw token values, vault ciphertext, or owner env
  values.
- Prefer runtime-backed proof over docs-only claims. A done item should have a
  command, report, or test that proves the behavior.
- If a workstream is blocked by cloud, DNS, funding, contract deployment,
  third-party service signup, or owner secrets, document the exact owner input
  and make the local release gate fail closed instead of passing falsely.
- Do not revert unrelated changes. Multiple agents may be operating in the same
  repository.

## Queue Map

1. Live bridge pilot hardening
2. Production public RPC deployment automation
3. Backup/restore proof
4. Observability and incident operations
5. External tester launch flow
6. Developer packs and examples
7. Explorer, faucet, and wallet UX
8. Node operator packaging
9. Contracts and security
10. Release gates and production readiness evidence

## Workstream 1: Live Bridge Pilot Hardening

### Objective

Turn the Base 8453 bridge pilot from a guarded local or dry-run path into a
production-shaped bridge flow with explicit owner inputs, fail-closed live
broadcast gates, accounting proof, replay protection, emergency controls, and
operator runbooks.

### Why It Matters

An L1 is not useful for outside testers if funds cannot move into and out of the
network safely. The bridge is also the highest-risk surface because mistakes can
create unbacked credits, double credits, lost withdrawals, replayed messages, or
live broadcasts to the wrong contract. This work should be treated as security
critical.

### Concrete Files Likely Involved

- `services/bridge-relayer/`
- `services/control-plane/src/methods.ts`
- `services/control-plane/src/server.ts`
- `services/control-plane/src/types.ts`
- `services/control-plane/src/rpc-e2e.ts`
- `infra/scripts/flowchain-bridge-*.ps1`
- `infra/scripts/flowchain-live-bridge-*.ps1`
- `infra/scripts/flowchain-live-product-e2e.ps1`
- `docs/FLOWCHAIN_LIVE_L1_BRIDGE_GO_NO_GO.md`
- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- `docs/OPERATIONS/`
- `docs/agent-runs/live-product-bridge/`
- `.github/workflows/` if bridge checks need CI coverage

Future workers should verify these paths before editing; this list is a likely
map, not permission to blindly modify every file.

### Done Criteria

- Bridge configuration validates Base chain id `8453`, expected token decimals,
  lockbox address, token address, finality depth, cap settings, and emergency
  stop settings before any live action is possible.
- Local and dry-run bridge flows prove deposit detection, credit creation,
  withdrawal request creation, replay rejection, confirmation handling, and
  accounting invariants.
- Live broadcast remains disabled unless explicit owner env values and an
  intentional live flag are both present.
- Bridge lifecycle records are queryable through RPC with public-safe fields.
- Accounting proof shows every credited FlowChain amount maps to one accepted
  external deposit event, and every withdrawal is either pending, broadcast,
  confirmed, rejected, or safely expired.
- Replay tests cover duplicate deposit event ids, duplicate withdrawal ids,
  stale finality, wrong token, wrong lockbox, wrong chain id, wrong decimals,
  and emergency stop.
- Operator docs explain dry-run, pilot-live, pause, resume, emergency stop,
  reconciliation, rollback limits, and owner inputs.
- The completion audit treats missing live owner inputs as `blocked`, not
  `passed` or `failed`, when local safety proof passes.

### Verification Commands

```powershell
npm run flowchain:bridge:command-matrix
npm run flowchain:bridge:mock:e2e
npm run flowchain:bridge:live:check -- -AllowBlocked
npm run flowchain:bridge:infra:check -- -AllowBlocked
npm run flowchain:live-l1-bridge:e2e -- -AllowBlocked
npm run flowchain:live-product:e2e -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

If exact script names differ, inventory `package.json` and `infra/scripts/` and
use the repo's real bridge and completion-audit commands.

### Blockers And Owner Inputs

- Base 8453 RPC provider URL.
- Funded pilot wallet or signer policy.
- Deployed or selected lockbox contract address.
- Token contract address and decimals.
- Bridge cap policy and per-tester allocation policy.
- Confirmation depth and reorg tolerance policy.
- Emergency owner or multisig address.
- Decision on whether pilot withdrawals are enabled at first launch or deposit
  credits only.
- External contract verification and audit status.

Local work can harden dry-run, mock, accounting, and release gates. It cannot
honestly prove live bridging until those owner inputs exist and a live pilot is
executed with real evidence.

### Worker Prompt

```text
/goal FlowChain Live Bridge Pilot Hardening

Harden the FlowChain Base 8453 bridge pilot until the repo can prove all local
bridge safety invariants and can fail closed when owner-provided live bridge
inputs are missing. Do not claim the bridge is live unless a real Base 8453
pilot transaction is executed and verified through the existing owner-approved
live path.

You are not alone in the codebase. Read current git status first. Do not revert
or overwrite edits you did not make. Keep generated evidence in the repo's
existing agent-run report locations. Never print or commit secrets.

Inventory first:
1. Read `AGENTS.md`.
2. Read `package.json` scripts.
3. Read `docs/FLOWCHAIN_LIVE_L1_BRIDGE_GO_NO_GO.md`.
4. Read `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`.
5. Read bridge relayer source and bridge scripts.
6. Read control-plane RPC method definitions for bridge status/readiness.
7. Identify every bridge report the completion audit consumes.

Build or harden:
1. Add strict bridge config validation for chain id, token, lockbox, decimals,
   confirmation depth, caps, emergency stop, and live broadcast flag.
2. Make live broadcast impossible unless owner env values and explicit live
   intent are present.
3. Add replay and accounting tests for duplicate deposits, duplicate
   withdrawals, wrong token, wrong chain, wrong lockbox, wrong decimals,
   insufficient confirmations, emergency stop, stale lifecycle state, and
   malformed event data.
4. Ensure local bridge e2e proves credit accounting using runtime-backed
   records, not fixture-only rows.
5. Ensure bridge RPC methods expose public-safe status, lifecycle records,
   readiness blockers, and reconciliation evidence.
6. Add or update operator docs for dry-run, pilot-live, reconciliation,
   emergency stop, and owner input setup.
7. Wire bridge proof into completion audit or release gates without allowing
   missing owner inputs to pass as production-ready.

Verification:
1. Run bridge unit and e2e commands from `package.json`.
2. Run live bridge go/no-go with `-AllowBlocked`.
3. Run the live product e2e or completion audit with `-AllowBlocked`.
4. Run no-secret scan, unsafe-claims check, parser checks for edited scripts,
   and `git diff --check`.

Exit state:
- Commit only your intended bridge hardening changes and evidence.
- Push the branch if repository credentials allow it.
- Report whether bridge status is local-proof-passed, owner-blocked, failed, or
  live-verified. Include exact blockers and exact commands run.
```

## Workstream 2: Production Public RPC Deployment Automation

### Objective

Build repeatable automation for deploying and operating public FlowChain RPC
servers with TLS, DNS, CORS, rate limits, method allowlists, health checks,
rollback, logs, and owner-safe configuration.

### Why It Matters

Testers, wallets, explorers, SDKs, and apps need a stable endpoint. A local
`127.0.0.1` RPC proves functionality on one machine, but a production L1 needs
public ingress with deliberate safety boundaries. Public RPC is also an abuse
surface, so rate limiting and method allowlists must be first-class.

### Concrete Files Likely Involved

- `services/control-plane/`
- `services/control-plane/src/methods.ts`
- `infra/scripts/flowchain-public-rpc-*.ps1`
- `infra/scripts/flowchain-service-*.ps1`
- `infra/scripts/flowchain-completion-audit.ps1`
- `docs/OPERATIONS/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md`
- `docs/FLOWCHAIN_CONTROL_PLANE_API.md`
- `docs/FLOWCHAIN_PUBLIC_RPC_DEPLOYMENT.md`
- `docs/agent-runs/live-product-infra-rpc/`
- `.github/workflows/`
- Deployment templates for the chosen host, edge proxy, reverse proxy, or cloud
  provider

### Done Criteria

- A fresh operator can provision public RPC from documented owner inputs using
  a repeatable command or infrastructure template.
- Public endpoint exposes only approved read methods and blocks local admin,
  private wallet mutation, bridge live broadcast, backup, and secret-bearing
  diagnostics.
- TLS, DNS, CORS, body size, request timeout, concurrency, rate limit, and
  structured access logs are configured.
- Health, readiness, and discovery endpoints prove method counts and fail closed
  when public profile is unsafe.
- Deployment automation supports dry-run, plan, apply, status, rollback, and
  teardown where feasible.
- Local service restart and port handoff are robust enough for repeated
  release-gate runs.
- The completion audit records public RPC status as `blocked` when DNS/cloud
  owner inputs are missing, and `passed` only when a real endpoint has been
  checked.

### Verification Commands

```powershell
npm run flowchain:service:restart -- -LiveProfile
npm run flowchain:service:status -- -AllowBlocked
npm run flowchain:public-rpc:edge-template
npm run flowchain:public-rpc:deployment-bundle
npm run flowchain:public-rpc:check -- -AllowBlocked
npm run flowchain:public-rpc:validate
npm run flowchain:public-rpc:abuse-test
npm run flowchain:public-deployment:contract -- -AllowBlocked
npm run flowchain:rpc:e2e
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Use real script names from `package.json` if these are renamed.

### Blockers And Owner Inputs

- Public domain or subdomain for RPC.
- DNS provider access.
- Hosting provider and region decision.
- TLS certificate strategy.
- Public RPC abuse policy: rate limit, WAF, CORS origins, allowed methods.
- Log retention policy.
- Budget and expected request volume.
- Decision on whether public RPC is read-only for launch or includes any
  signed transaction submission path.

Local automation can prove templates, edge config generation, method allowlists,
and readiness gates. It cannot prove external reachability until owner cloud and
DNS inputs are present.

### Worker Prompt

```text
/goal FlowChain Production Public RPC Deployment Automation

Build production public RPC deployment automation for FlowChain. The endpoint
must be safe for external testers, must expose only the approved public method
surface, and must fail closed if owner cloud, DNS, TLS, or rate-limit inputs are
missing.

You are not alone in the codebase. Inspect git status first. Do not revert
others' edits. Avoid secrets in logs, docs, reports, and command output.

Inventory:
1. Read `package.json`.
2. Read public RPC scripts and service start/status scripts.
3. Read `services/control-plane/src/methods.ts` and server ingress logic.
4. Read `docs/OPERATIONS/FLOWCHAIN_OWNER_OPERATED_PUBLIC_RPC.md`.
5. Read completion audit public RPC expectations.
6. Identify current reports that prove local RPC and public RPC readiness.

Build:
1. Add or harden infrastructure templates for the selected public RPC hosting
   path. Include dry-run/plan/apply/status/rollback behavior where practical.
2. Generate a public RPC method allowlist from code or a checked manifest so
   docs and runtime cannot drift.
3. Add public profile checks for TLS, DNS, bind address, CORS, rate limits,
   request body limits, timeout, structured access logs, and admin method
   denial.
4. Add e2e tests that call public-safe methods and confirm private/admin/write
   methods are rejected through the public surface.
5. Add deployment docs with owner inputs, expected outputs, rollback steps,
   abuse response, and endpoint verification.
6. Wire public RPC evidence into release gates, clearly distinguishing local
   proof from external endpoint proof.

Verification:
1. Restart local service with live profile and verify block production.
2. Run RPC e2e and public RPC status/plan commands.
3. Run completion audit with `-AllowBlocked`.
4. Run no-secret scan, unsafe-claims check, and `git diff --check`.
5. If owner inputs are present, verify the public URL externally and record the
   endpoint, method count, latest height, TLS status, and allowlist result.

Exit state:
- Commit and push only scoped public RPC changes.
- Report local proof, external proof if available, and exact owner blockers.
```

## Workstream 3: Backup/Restore Proof

### Objective

Build a real backup and restore system for FlowChain node state, bridge
accounting, wallet metadata, configuration manifests, and release evidence, with
a rehearsal that proves a restored node can resume safely.

### Why It Matters

A chain that cannot be restored is not production-ready. Backups must prove more
than file copy success: restored state must match expected height, balances,
bridge records, wallet transfer history, and safety metadata without leaking
secrets or corrupting consensus state.

### Concrete Files Likely Involved

- `infra/scripts/flowchain-backup-*.ps1`
- `infra/scripts/flowchain-restore-*.ps1`
- `infra/scripts/flowchain-service-*.ps1`
- `infra/scripts/flowchain-completion-audit.ps1`
- `services/control-plane/`
- `services/bridge-relayer/`
- State directories documented by the existing runtime and scripts
- `docs/OPERATIONS/`
- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- `docs/agent-runs/live-product-backup/`
- `.github/workflows/` if backup checks are added to CI

### Done Criteria

- Backup manifest lists included state roots, excluded secret roots, checksums,
  schema versions, chain id, latest height, node id, bridge accounting snapshot,
  and created-at timestamp.
- Restore rehearsal runs into an isolated target directory and never overwrites
  the active node state unless an explicit restore flag is provided.
- Restored node can start, report the expected height or safe continuation
  height, produce new blocks, and answer RPC status queries.
- Restored balances, wallet transfer history, transaction ids, and bridge
  lifecycle records match pre-backup evidence.
- Corrupt backup, missing manifest, wrong chain id, stale schema, and checksum
  mismatch fail closed.
- Retention and rotation policy exists for local and owner-provided remote
  storage.
- No secrets are copied into public reports.

### Verification Commands

```powershell
npm run flowchain:service:restart -- -LiveProfile
npm run flowchain:backup:create
npm run flowchain:backup:restore:verify -- -AllowBlocked
npm run flowchain:backup:restore:validate
npm run flowchain:backup:check -- -AllowBlocked
npm run flowchain:service:status -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Use actual script names after inventory.

### Blockers And Owner Inputs

- Remote backup storage provider.
- Encryption key management policy.
- Backup retention period.
- Recovery point objective and recovery time objective.
- Whether bridge signer material is backed up, excluded, or held externally.
- Whether production restores require owner approval, multisig, or break-glass
  process.

Local work can prove backup/restore mechanics and isolated rehearsal. It cannot
prove remote durability or disaster recovery until the owner selects storage and
key management.

### Worker Prompt

```text
/goal FlowChain Backup Restore Proof

Build and verify FlowChain backup/restore proof. A future operator must be able
to create a backup, verify it, restore into an isolated directory, start the
restored node, prove state continuity, and see explicit blockers for remote
storage or owner key management.

You are not alone in the codebase. Check git status first. Do not overwrite
active state or unrelated edits. Do not copy secrets into reports.

Inventory:
1. Read runtime state path documentation and service scripts.
2. Read existing backup/restore scripts if present.
3. Read bridge relayer persistence paths.
4. Read wallet metadata and transfer history persistence paths.
5. Read completion audit backup expectations.
6. Identify which files are state, config, cache, logs, reports, and secrets.

Build:
1. Add backup manifest generation with checksums, schema version, chain id,
   latest height, included paths, excluded paths, and redacted config summary.
2. Add backup verification that catches missing files, checksum mismatch,
   wrong chain id, stale schema, corrupt JSON, and unsafe secret inclusion.
3. Add restore rehearsal into a new isolated directory. It must not mutate the
   active service state.
4. Start a restored node or validation process and prove height, balances,
   wallet transfers, transaction lookup, and bridge lifecycle records match
   pre-backup evidence.
5. Add retention/rotation docs and owner input docs for remote backup storage.
6. Wire backup/restore proof into completion audit or release gates.

Verification:
1. Run service restart/status.
2. Run backup create, backup verify, and restore rehearsal.
3. Run completion audit with `-AllowBlocked`.
4. Run no-secret scan, unsafe-claims check, parser checks for edited scripts,
   and `git diff --check`.

Exit state:
- Commit scoped backup/restore code, docs, and redacted evidence.
- Report local restore proof status and exact remote-storage owner blockers.
```

## Workstream 4: Observability And Incident Operations

### Objective

Build production-grade observability and incident operations for block
production, RPC availability, bridge lifecycle, wallet transfer flow, backup
health, resource usage, and release gate status.

### Why It Matters

When friends-and-family testers use the chain, failures need to be visible
before users report them. Operators need dashboards, alerts, runbooks, and
incident evidence for stalled block production, RPC outages, bridge pauses,
stuck transfers, high error rates, and failed backups.

### Concrete Files Likely Involved

- `services/control-plane/`
- `services/bridge-relayer/`
- `infra/scripts/flowchain-service-status.ps1`
- `infra/scripts/flowchain-observability-*.ps1`
- `infra/scripts/flowchain-completion-audit.ps1`
- `docs/OPERATIONS/`
- `docs/INCIDENTS/`
- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- `docs/agent-runs/live-product-observability/`
- Dashboard or metrics templates for the selected monitoring stack

### Done Criteria

- Metrics exist for latest height, block production rate, stalled height,
  mempool size, RPC request count, RPC error count, RPC latency, method denial,
  bridge deposit lifecycle counts, bridge credit totals, withdrawal lifecycle
  counts, backup age, backup verification status, process uptime, memory, CPU,
  disk, and release gate status.
- Logs are structured and redact secrets.
- Health and readiness endpoints distinguish local node health, public RPC
  health, bridge readiness, backup freshness, and owner-blocked live inputs.
- Alert rules exist for stalled blocks, RPC down, high RPC errors, bridge
  emergency stop, bridge reconciliation mismatch, stale backup, disk pressure,
  and release gate failure.
- Incident runbooks exist for block stall, RPC outage, bridge pause, bad
  release, backup failure, suspected key leak, and public endpoint abuse.
- A local drill script or checklist proves at least one alert/runbook path
  without needing paid monitoring services.

### Verification Commands

```powershell
npm run flowchain:service:status -- -AllowBlocked
npm run flowchain:service:monitor
npm run flowchain:ops:snapshot -- -AllowBlocked
npm run flowchain:ops:incident-drill
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Use actual script names after inventory.

### Blockers And Owner Inputs

- Monitoring provider choice.
- Alert destination: email, Slack, Discord, PagerDuty, or another system.
- Log retention and privacy policy.
- Public status page decision.
- On-call rotation or owner escalation contact.
- Budget for metrics/log ingestion.

Local work can create metrics, structured logs, dashboards as code, alert rule
templates, and incident drills. It cannot prove production alert delivery until
owner destinations and provider credentials exist.

### Worker Prompt

```text
/goal FlowChain Observability Incident Operations

Build observability and incident operations for FlowChain so an operator can
see whether blocks are advancing, RPC is healthy, bridge accounting is safe,
backups are fresh, and release gates are passing. Add local drills and
provider-neutral templates, while failing closed for missing owner monitoring
credentials.

You are not alone in the codebase. Check git status first. Do not revert others'
edits. Do not print secrets in metrics, logs, reports, or dashboards.

Inventory:
1. Read service status scripts and control-plane health/readiness code.
2. Read bridge status and lifecycle reporting code.
3. Read backup reports and completion audit evidence.
4. Identify logging format and current report schemas.
5. Identify whether metrics endpoints or dashboard templates already exist.

Build:
1. Add or standardize metrics for block height, block rate, RPC traffic,
   latency, errors, method denial, bridge lifecycle, backup freshness, process
   health, disk, memory, and release gates.
2. Add public-safe diagnostics that are useful for operators but never expose
   secrets or raw owner env values.
3. Add alert rule templates for stalled blocks, RPC down, high errors, bridge
   emergency stop, accounting mismatch, stale backup, disk pressure, and failed
   completion audit.
4. Add incident runbooks for block stall, RPC outage, bridge pause, bad release,
   backup failure, suspected key leak, and public endpoint abuse.
5. Add a local incident drill command or documented drill that proves at least
   one alert/runbook path.
6. Wire observability readiness into completion audit or go/no-go docs.

Verification:
1. Run service status and observability check commands.
2. Run an incident drill or checklist command.
3. Run completion audit with `-AllowBlocked`.
4. Run no-secret scan, unsafe-claims check, and `git diff --check`.

Exit state:
- Commit scoped observability code, docs, and redacted reports.
- Report which metrics and alerts are locally proven and which require owner
   monitoring provider setup.
```

## Workstream 5: External Tester Launch Flow

### Objective

Create a friends-and-family tester launch flow that lets real users create or
connect wallets, obtain pilot funds through an approved path, connect to the
chain, send wallet-to-wallet transactions, inspect balances/history, report
issues, and understand safety boundaries.

### Why It Matters

A chain is not live in a useful sense until external people can successfully use
it. Testers need a clear, safe path that does not require reading internal
scripts or guessing which endpoint, wallet, faucet, explorer, or bridge flow is
active.

### Concrete Files Likely Involved

- `docs/TESTERS/`
- `docs/developer/`
- `docs/OPERATIONS/`
- `services/control-plane/`
- Wallet UI or CLI packages
- Faucet service or scripts
- Explorer/indexer service or docs
- `infra/scripts/flowchain-external-tester-*.ps1`
- `infra/scripts/flowchain-completion-audit.ps1`
- `docs/agent-runs/live-product-external-testers/`

### Done Criteria

- Tester packet includes network name, chain id, RPC URL, explorer URL, faucet
  or funding path, wallet setup, send/receive steps, bridge status, known
  limitations, support channel, and risk warning.
- A local or staging tester rehearsal proves wallet creation, funding, send,
  block inclusion, balance update, transfer history, explorer lookup, and issue
  report creation.
- Public endpoints in the tester packet are generated from verified deployment
  evidence, not handwritten guesses.
- Tester funding has caps, abuse prevention, rate limits, and audit records.
- Support triage docs classify common failures: RPC unreachable, wallet
  mismatch, insufficient balance, transaction pending, bridge paused, faucet
  exhausted, explorer lag, and owner-blocked public launch.
- Launch checklist blocks external sharing until public RPC, faucet/funding,
  explorer, wallet flow, incident contact, and rollback/pause controls pass.

### Verification Commands

```powershell
npm run flowchain:tester:readiness -- -AllowBlocked
npm run flowchain:external-tester:packet -- -AllowBlocked
npm run flowchain:wallet:live-tester:e2e
npm run flowchain:dev-pack:e2e
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Use real script names or add them if this workstream owns them.

### Blockers And Owner Inputs

- Public RPC URL.
- Explorer URL.
- Faucet or allocation funding source.
- Tester list or invitation policy.
- Support channel.
- Terms/risk language.
- Whether bridge is enabled for testers or local-chain-only at first.
- Rate limits and per-tester funding caps.

Local work can build packet generation, local rehearsal, and checklist gates. It
cannot invite external testers honestly until public endpoints and owner launch
decisions are ready.

### Worker Prompt

```text
/goal FlowChain External Tester Launch Flow

Build the friends-and-family tester launch flow for FlowChain. A real tester
should be able to follow one packet to connect, receive pilot funds, send funds
to another wallet, inspect the result, and report an issue. The packet must be
generated from verified evidence and must block launch when public owner inputs
are missing.

You are not alone in the codebase. Inspect git status first. Do not overwrite
others' edits. Keep private keys, raw env values, and invitation lists out of
commits unless they are explicitly public fixtures.

Inventory:
1. Read developer quickstart and SDK docs.
2. Read public RPC deployment docs and reports.
3. Read wallet creation/send docs and runtime paths.
4. Read bridge go/no-go docs.
5. Read explorer/faucet status if present.
6. Identify current completion audit launch blockers.

Build:
1. Create a tester packet template generated from verified RPC, explorer,
   faucet/funding, wallet, bridge, and support-channel evidence.
2. Add local/staging tester rehearsal that creates or imports a safe test
   wallet, funds it through the approved local path, sends to another wallet,
   waits for block inclusion, checks balances/history, and links explorer data.
3. Add launch checklist gates for public RPC, chain height advancing, faucet or
   funding, explorer lookup, wallet send, support channel, incident rollback,
   bridge status, and no-secret proof.
4. Add support triage docs for common tester failures.
5. Make owner-blocked launch inputs explicit and machine-readable.

Verification:
1. Run tester packet generation with `-AllowBlocked`.
2. Run local tester e2e.
3. Run dev-pack e2e.
4. Run completion audit with `-AllowBlocked`.
5. Run no-secret scan, unsafe-claims check, and `git diff --check`.

Exit state:
- Commit tester launch flow docs, generator, e2e proof, and redacted reports.
- Report whether external sharing is ready, locally rehearsed only, or blocked
  by owner/public infrastructure inputs.
```

## Workstream 6: Developer Packs And Examples

### Objective

Expand the FlowChain developer ecosystem so builders have an SDK, CLI/devkit,
generated RPC reference, example apps, tutorials, compatibility matrix,
troubleshooting guide, and release-tested dev-pack e2e.

### Why It Matters

Developers will not build on an L1 if they cannot quickly discover methods,
query state, submit transactions, handle errors, and inspect results. Dev packs
also act as regression tests for the public API and prevent docs from drifting
away from runtime behavior.

### Concrete Files Likely Involved

- `services/flowchain-sdk/`
- `docs/developer/`
- `docs/sdk/`
- `examples/flowchain-*`
- `tools/flowchain-*`
- `services/control-plane/src/methods.ts`
- `services/control-plane/src/rpc-e2e.ts`
- `infra/scripts/flowchain-dev-pack-*.ps1`
- `docs/agent-runs/live-product-dev-pack/`
- `package.json` scripts for dev-pack commands

### Done Criteria

- SDK covers discovery, readiness, status, finality, blocks, transactions,
  accounts, wallet balances, wallet transfers, wallet send path, bridge
  readiness/status, and diagnostics.
- CLI supports JSON output and human output for the same core flows.
- Example app or script starts from a clean checkout and demonstrates connect,
  query, send, wait, and inspect using the real local RPC.
- Generated RPC reference is checked against `rpc_discover`.
- Troubleshooting docs include common local, public RPC, wallet, bridge, and
  explorer failure modes.
- Dev-pack e2e proves height advancement and a runtime-backed wallet send.
- Docs clearly label local, public-read-only, owner-blocked-live, and
  unsupported behavior.

### Verification Commands

```powershell
npm test --prefix services/flowchain-sdk
npm run flowchain:dev-pack:e2e
npm run flowchain:service:status -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

### Blockers And Owner Inputs

- Public RPC URL for public examples.
- Final supported wallet format and branding.
- Which languages receive official SDK support after the first JavaScript or
  TypeScript package.
- Package publishing account and namespace.
- Versioning and compatibility policy.

Local work can fully build SDK, CLI, examples, generated docs, and local e2e.
Publishing packages and public endpoint examples require owner accounts and live
infrastructure.

### Worker Prompt

```text
/goal FlowChain Developer Packs Examples

Expand the FlowChain developer pack into a complete builder experience. A
developer should be able to install the SDK/devkit, connect to local RPC, query
chain state, send a wallet-to-wallet transfer, wait for inclusion, inspect
history, check bridge readiness, and troubleshoot failures using generated docs
that match the real runtime.

You are not alone in the codebase. Check git status first. Do not revert others'
edits. Do not change package files unless this workstream requires a script or
workspace entry and you have verified no other agent is editing them.

Inventory:
1. Read existing SDK package and dev-pack docs.
2. Read control-plane RPC discovery and method registry.
3. Read wallet runtime send path.
4. Read bridge readiness/status RPC methods.
5. Read current dev-pack e2e report schema.
6. Read completion audit expectations for developer-dev-pack.

Build:
1. Expand SDK typed clients and tagged errors.
2. Expand CLI commands with `--json` support.
3. Add generated RPC reference validation against `rpc_discover`.
4. Add an example app or example scripts that use real local RPC.
5. Add tutorials for connect, query, send, wait, bridge readiness, and
   diagnostics.
6. Add troubleshooting docs and compatibility matrix.
7. Ensure dev-pack e2e proves height advancement and runtime-backed wallet send.

Verification:
1. Run SDK tests.
2. Run dev-pack e2e.
3. Run service status.
4. Run completion audit with `-AllowBlocked`.
5. Run no-secret scan, unsafe-claims check, and `git diff --check`.

Exit state:
- Commit scoped SDK/dev-pack docs and evidence.
- Report exactly which developer flows are local-proven, public-proven, or
  owner-blocked.
```

## Workstream 7: Explorer, Faucet, And Wallet UX

### Objective

Build the user-facing chain surfaces: explorer for blocks/transactions/accounts,
faucet or pilot allocation flow for test funds, and wallet UX for create,
backup, connect, send, receive, and history.

### Why It Matters

External users need more than RPC commands. They need to see blocks moving,
verify transactions, get test funds safely, and send funds without touching
internal scripts. Explorer, faucet, and wallet UX are the difference between a
technical local chain and a usable ecosystem.

### Concrete Files Likely Involved

- `services/control-plane/`
- Explorer service or frontend package if present
- Wallet frontend or CLI package if present
- Faucet service or scripts if present
- `docs/developer/`
- `docs/TESTERS/`
- `docs/OPERATIONS/`
- `infra/scripts/flowchain-explorer-*.ps1`
- `infra/scripts/flowchain-faucet-*.ps1`
- `infra/scripts/flowchain-wallet-*.ps1`
- `docs/agent-runs/live-product-ux/`
- Public deployment templates for explorer/faucet if used

### Done Criteria

- Explorer can show latest height, block list, block detail, transaction list,
  transaction detail, account detail, balance, transfer history, bridge
  lifecycle status, and finality or confirmation state.
- Faucet or pilot allocation flow has per-user and per-address caps, rate
  limiting, abuse logs, funding balance checks, and pause controls.
- Wallet UX supports create, import/connect where safe, backup warning, receive
  address display, send, fee/status display if applicable, transaction pending
  state, inclusion confirmation, balance refresh, and history.
- UX never exposes private keys or seed phrases after creation except through a
  deliberate backup flow with clear no-custody boundary.
- Local e2e proves create/fund/send/inspect.
- Public launch gate blocks if explorer, faucet, or wallet deployment is not
  externally reachable.

### Verification Commands

```powershell
npm run flowchain:dashboard:verify
npm run flowchain:wallet:e2e
npm run flowchain:wallet:transfer:e2e
npm run flowchain:dex:e2e
npm run flowchain:dev-pack:e2e
npm run flowchain:service:status -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

If this includes a browser frontend, also run the repo's frontend tests and use
browser verification against the local dev server.

### Blockers And Owner Inputs

- Branding and naming.
- Public explorer domain.
- Public faucet domain.
- Funding source and faucet amount/cap policy.
- Abuse prevention policy.
- Wallet custody and backup policy.
- Terms/risk copy for testers.
- Whether mobile is required for first launch.

Local work can build and verify the UI against local RPC. Public availability
requires domains, hosting, and funding policy.

### Worker Prompt

```text
/goal FlowChain Explorer Faucet Wallet UX

Build the user-facing FlowChain surfaces needed for external testers: explorer,
faucet or pilot allocation, and wallet UX. Prove the local flow from wallet
creation to funding to send to explorer inspection. Keep public launch blocked
until owner endpoints, domains, and funding policy are provided.

You are not alone in the codebase. Check git status first. Do not overwrite
others' frontend, runtime, or generated edits. If editing a frontend, follow the
repo's existing design system and verify it in a browser.

Inventory:
1. Find existing explorer, faucet, wallet, or dashboard packages.
2. Read control-plane RPC methods for blocks, transactions, accounts, balances,
   wallet metadata, transfers, and bridge lifecycle.
3. Read current dev-pack wallet send flow.
4. Read public RPC allowlist and external tester docs.
5. Identify deployment and completion-audit expectations.

Build:
1. Implement or complete explorer views for latest blocks, block detail,
   transactions, transaction detail, accounts, balances, transfer history,
   bridge lifecycle, and finality.
2. Implement or complete faucet/pilot allocation with caps, rate limits, pause,
   funding balance checks, audit logs, and public-safe status.
3. Implement or complete wallet create/connect/backup/send/receive/history UX
   using existing safe wallet APIs.
4. Add local e2e that proves create/fund/send/wait/inspect.
5. Add tester-facing docs and operator docs.
6. Wire UX readiness into release gates without passing public launch when
   domains or funding are missing.

Verification:
1. Run frontend tests and local browser verification if a frontend is edited.
2. Run UX e2e and dev-pack e2e.
3. Run service status and completion audit with `-AllowBlocked`.
4. Run no-secret scan, unsafe-claims check, and `git diff --check`.

Exit state:
- Commit scoped UX, docs, and redacted evidence.
- Report local UX proof, public deployment blockers, and any security-sensitive
  decisions still needed from the owner.
```

## Workstream 8: Node Operator Packaging

### Objective

Package FlowChain node operation into a repeatable operator experience with
install, configure, start, stop, restart, status, upgrade, rollback, backup,
restore, logs, metrics, public RPC, and validator or sequencer role guidance as
applicable.

### Why It Matters

Production chains require repeatable operations. If only one development
checkout can run the node, the system is fragile. Operators need scripts,
packages, docs, and recovery paths that work on clean machines.

### Concrete Files Likely Involved

- `infra/scripts/flowchain-service-*.ps1`
- `infra/scripts/flowchain-node-*.ps1`
- `infra/scripts/flowchain-operator-*.ps1`
- `infra/scripts/flowchain-backup-*.ps1`
- `infra/scripts/flowchain-public-rpc-*.ps1`
- `docs/OPERATIONS/`
- `docs/developer/`
- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- Installer or package manifests if present
- System service templates if present
- `docs/agent-runs/live-product-operator/`

### Done Criteria

- Clean-machine prerequisites are documented and checked.
- Operator can install dependencies, configure local or live profile, start the
  node, verify block production, expose private or public RPC according to
  profile, restart safely, stop safely, and inspect logs.
- Upgrade and rollback procedures exist and are rehearsed locally.
- Service manager templates exist for the target production OS where possible.
- Ports, firewall rules, disk sizing, CPU/memory sizing, log paths, state paths,
  backup paths, and monitoring endpoints are documented.
- Operator packaging works without committing secrets.
- Release gates include a clean-start or near-clean-start operator rehearsal.

### Verification Commands

```powershell
npm run flowchain:prereq
npm run flowchain:doctor
npm run flowchain:service:restart -- -LiveProfile
npm run flowchain:service:status -- -AllowBlocked
npm run flowchain:node:smoke
npm run flowchain:second-computer:bundle
npm run flowchain:second-computer:verify -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Use actual script names after inventory.

### Blockers And Owner Inputs

- Target production OS and hosting provider.
- Whether deployment uses a VM, container, managed process, or edge service.
- Domain, firewall, and ingress decisions.
- Hardware sizing budget.
- Service account and secret storage policy.
- Upgrade window and rollback policy.

Local work can produce Windows and repo-local operator packaging. Production OS
service integration may require owner hosting decisions.

### Worker Prompt

```text
/goal FlowChain Node Operator Packaging

Build the FlowChain node operator package so a future operator can install,
configure, run, restart, observe, backup, restore, upgrade, and rollback the L1
using documented commands and release-gated rehearsals. Keep live hosting
blocked until owner infrastructure decisions are present.

You are not alone in the codebase. Check git status first. Do not revert others'
edits. Do not run destructive cleanup against state directories unless the
script proves the target path and uses an explicit isolated test path.

Inventory:
1. Read service start/stop/restart/status scripts.
2. Read node start scripts and runtime requirements.
3. Read public RPC and backup docs.
4. Read package scripts and current operator docs.
5. Identify supported OS assumptions and missing prerequisites.

Build:
1. Add operator doctor checks for prerequisites, ports, disk, state path,
   config, env blockers, public RPC profile, backup path, and monitoring hooks.
2. Add clean-start or isolated rehearsal that starts the node, verifies height
   advancement, checks RPC, restarts, and verifies continuity.
3. Add upgrade and rollback docs and, where practical, rehearsal scripts.
4. Add service manager templates or docs for the chosen target OS.
5. Add port/firewall/sizing/log/state/backup documentation.
6. Wire operator rehearsal into completion audit or release gates.

Verification:
1. Run operator doctor.
2. Run service restart/status.
3. Run operator rehearsal.
4. Run completion audit with `-AllowBlocked`.
5. Run no-secret scan, unsafe-claims check, parser checks, and `git diff --check`.

Exit state:
- Commit scoped operator packaging changes and redacted evidence.
- Report which operator path is proven locally and which production deployment
  choices remain owner-blocked.
```

## Workstream 9: Contracts And Security

### Objective

Harden FlowChain contracts, bridge interfaces, signing rules, key custody
boundaries, RPC authorization, replay protection, dependency posture, threat
model, and audit evidence.

### Why It Matters

Security failures on an L1 can destroy funds or trust. The project needs a
security baseline before wider testing: threat modeling, least privilege, input
validation, replay resistance, no-custody boundaries, dependency checks, and
clear contract deployment evidence.

### Concrete Files Likely Involved

- Contracts directory if present
- Bridge contract interfaces or ABI files
- `services/bridge-relayer/`
- `services/control-plane/`
- Wallet signing and runtime files
- RPC method registry and authorization/allowlist files
- `infra/scripts/flowchain-security-*.ps1`
- `infra/scripts/flowchain-completion-audit.ps1`
- `docs/SECURITY/`
- `docs/FLOWCHAIN_LIVE_L1_BRIDGE_GO_NO_GO.md`
- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- Dependency lockfiles only if the security work requires dependency changes

### Done Criteria

- Threat model covers assets, actors, trust boundaries, bridge risks, wallet
  custody, RPC abuse, backups, monitoring, deployment, and incident response.
- RPC authorization and public allowlists deny private/admin/write methods on
  public surfaces.
- Signing and transaction envelope checks cover nonce, replay, malformed input,
  chain id, expiration if supported, and account ownership.
- Bridge contract or ABI verification checks exist for expected chain, token,
  lockbox, decimals, events, and permissions.
- Dependency audit and license posture are documented.
- Security tests cover malformed JSON-RPC, method denial, replay, invalid
  signature, wrong chain id, unauthorized bridge action, unsafe env exposure,
  and redaction.
- A security go/no-go document clearly separates internal local testnet, public
  read-only pilot, bridge pilot, and production launch.

### Verification Commands

```powershell
npm audit --omit=dev
npm run contracts:hardening
npm run bridge:test
npm run flowchain:rpc:e2e
npm run flowchain:bridge:mock:e2e
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Use the repo's actual security/test commands after inventory.

### Blockers And Owner Inputs

- Final bridge contract address and deployment transaction.
- Audit vendor or external reviewer decision.
- Bug bounty policy.
- Key custody policy and signer storage.
- Emergency admin or multisig policy.
- Security contact email.
- Production dependency upgrade policy.

Local work can complete threat model, tests, allowlists, redaction, and
contract-interface validation. It cannot claim external audit completion or
final contract verification without owner-provided deployments and reviewers.

### Worker Prompt

```text
/goal FlowChain Contracts Security Hardening

Harden FlowChain contracts and security boundaries for a production-shaped L1.
Focus on threat modeling, RPC authorization, signing and replay safety, bridge
contract validation, dependency posture, no-secret proof, and release gates.
Do not claim an external audit or final live contract deployment unless real
owner-provided evidence exists.

You are not alone in the codebase. Check git status first. Do not revert others'
edits. Do not print secrets, private keys, mnemonics, or raw owner env values.

Inventory:
1. Locate contracts, ABI files, bridge interfaces, and deployment docs.
2. Read RPC method registry and public/private allowlist logic.
3. Read wallet signing and transaction envelope validation.
4. Read bridge relayer validation and live broadcast gates.
5. Read no-secret scan and unsafe-claims checks.
6. Read existing security docs, if any.

Build:
1. Create or update threat model covering assets, actors, trust boundaries,
   attack paths, mitigations, and residual risks.
2. Add tests for JSON-RPC method denial, malformed input, replay, invalid
   signatures, wrong chain id, unauthorized bridge action, and redaction.
3. Add contract or ABI verification checks for bridge live config.
4. Add dependency audit and license posture docs or scripts.
5. Add security go/no-go stages for local testnet, public read-only pilot,
   bridge pilot, and production launch.
6. Wire security proof into completion audit without passing owner-blocked
   audit/vendor/deployment items.

Verification:
1. Run security check and relevant unit/e2e tests.
2. Run bridge e2e and RPC e2e.
3. Run completion audit with `-AllowBlocked`.
4. Run no-secret scan, unsafe-claims check, and `git diff --check`.

Exit state:
- Commit scoped security changes and evidence.
- Report local security proof, remaining external audit needs, and owner
  blockers.
```

## Workstream 10: Release Gates And Production Readiness Evidence

### Objective

Unify all production readiness checks into a reliable release gate that proves
block production, wallet sends, RPC readiness, bridge safety, public deployment
status, backup/restore, observability, dev-pack, external tester flow, security,
and no-secret posture.

### Why It Matters

The project needs one honest source of truth. Without a strong completion audit,
agents can keep adding features while missing the fact that public RPC is not
deployed, bridge live inputs are missing, backups are unproven, or tester launch
is blocked. Release gates turn "it seems done" into evidence.

### Concrete Files Likely Involved

- `infra/scripts/flowchain-completion-audit.ps1`
- `infra/scripts/flowchain-architecture-audit.ps1`
- `infra/scripts/flowchain-live-product-e2e.ps1`
- `infra/scripts/flowchain-*-go-no-go.ps1`
- `docs/FLOWCHAIN_PRODUCTION_L1_GO_NO_GO.md`
- `docs/ARCHITECTURE_AUDIT.md`
- `docs/agent-runs/live-product-infra-rpc/`
- `docs/agent-runs/live-product-dev-pack/`
- Other existing report directories consumed by release gates
- `.github/workflows/`
- `package.json` scripts only if new release-gate commands are needed

### Done Criteria

- Completion audit emits a single machine-readable report with `passed`,
  `blocked`, or `failed`, and item-level evidence for every production
  readiness surface.
- Audit distinguishes local proof, public endpoint proof, owner-blocked live
  inputs, and real failures.
- Release gate verifies block height advancement, wallet-to-wallet send, RPC
  discovery/readiness, public RPC allowlist, bridge local safety, live bridge
  blockers, backup/restore proof, observability status, dev-pack e2e, external
  tester launch status, security checks, and no-secret scan.
- Architecture audit maps components, data flows, trust boundaries, failure
  modes, and owner blockers.
- Reports are redacted and stable enough for CI.
- CI can run the non-live subset and fail on regressions.
- Docs summarize exact next owner inputs needed for production launch.

### Verification Commands

```powershell
npm run flowchain:architecture:audit -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
npm run flowchain:live-product:e2e -- -AllowBlocked
npm run flowchain:dev-pack:e2e
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

### Blockers And Owner Inputs

- Which gates are required for first public read-only launch.
- Which gates are required for bridge pilot launch.
- Which gates are required for full production launch.
- CI runner environment and secrets policy.
- Public endpoint and live bridge inputs for non-blocked production status.

Local work can create the audit framework and prove local gates. It cannot make
the final release status `passed` until owner/live requirements are actually
satisfied.

### Worker Prompt

```text
/goal FlowChain Release Gates Production Readiness Evidence

Build the FlowChain release gates into a single honest production readiness
system. The audit must prove local chain behavior, wallet sends, RPC readiness,
bridge safety, backup/restore, observability, dev-pack, tester launch, security,
and no-secret posture. It must mark missing live owner inputs as blocked, not
passed.

You are not alone in the codebase. Check git status first. Do not overwrite
reports or scripts another agent is actively editing. Do not relax gates just to
get a green result.

Inventory:
1. Read completion audit and architecture audit scripts.
2. Read live product e2e and all go/no-go scripts.
3. Read current generated reports and report schemas.
4. Read production go/no-go docs and owner input docs.
5. Read package scripts and CI workflows.

Build:
1. Define a stable release readiness schema with top-level status and item-level
   evidence.
2. Add or harden gate items for block production, wallet send, RPC discovery,
   public RPC, bridge, backup/restore, observability, dev-pack, external tester
   launch, security, no-secret scan, and unsafe-claims check.
3. Ensure every item can be `passed`, `blocked`, or `failed` with clear
   rationale and evidence paths.
4. Ensure missing owner inputs are reported by variable name or input category
   only, never raw values.
5. Add CI-safe non-live gate commands and local/live gate commands.
6. Update production readiness docs with exact owner next steps.

Verification:
1. Run architecture audit with `-AllowBlocked`.
2. Run completion audit with `-AllowBlocked`.
3. Run live product e2e and dev-pack e2e.
4. Run no-secret scan, unsafe-claims check, parser checks, and `git diff --check`.

Exit state:
- Commit scoped release-gate changes and redacted reports.
- Report final audit status, failed items, blocked owner inputs, and exact
  commands run.
```

## Suggested Autonomous Loop

Use this loop for future agents when the owner asks for continuous work:

```text
1. Check git status and active processes.
2. Pick the highest-priority unowned workstream from this queue.
3. Read only the files needed for that workstream.
4. Implement a narrow but real slice.
5. Verify with the workstream commands.
6. Run no-secret and unsafe-claims checks.
7. Commit and push scoped changes.
8. Update docs or reports with honest status:
   - local-proof-passed
   - externally-live-verified
   - owner-blocked
   - failed
9. Move to the next workstream.
```

Do not use the loop to claim production readiness. Use it to keep reducing the
gap between local proof and externally live operation.

## Current Honest Boundary

The repo can keep improving local L1 behavior, SDK/devkit coverage, public RPC
templates, bridge dry-run safety, backup rehearsal, and release gates without
additional owner input. The following cannot be honestly completed by code alone:

- Public DNS and externally reachable RPC.
- Live Base 8453 bridge pilot transactions.
- Production TLS and hosting account setup.
- Remote backup storage and key management.
- Monitoring alert delivery to real owner channels.
- Package publishing accounts.
- External tester invitations and funding policy.
- External security audit or contract verification.

Future workers should turn every missing owner input into a precise blocked item
with a command that proves the rest of the system is ready to accept that input.
