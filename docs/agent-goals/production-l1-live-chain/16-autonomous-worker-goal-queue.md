# FlowChain Autonomous Worker Goal Queue

Status: copy-ready `/goal` prompts for long-running autonomous work on the
FlowChain L1 until it is production-live, externally testable, and proven by
machine-checkable audits.

Last aligned to local evidence from:

- `docs/agent-runs/live-product-infra-rpc/PRODUCTION_TRUTH_TABLE.md`
- `docs/agent-runs/live-product-infra-rpc/PUBLIC_DEPLOYMENT_CONTRACT.md`
- `docs/agent-runs/live-product-infra-rpc/OPS_SNAPSHOT.md`
- `docs/agent-runs/live-product-infra-rpc/COMPLETION_AUDIT.md`
- `docs/agent-goals/production-l1-live-chain/README.md`
- `docs/agent-goals/production-l1-live-chain/17-developer-ecosystem-dev-pack.md`

Do not treat this document as proof that the chain is complete. It is the work
queue for getting there.

The developer ecosystem benchmark and the expanded dev-pack worker prompt live
in `17-developer-ecosystem-dev-pack.md`. Use that prompt when the next loop is
about SDKs, CLI/devkit, generated RPC references, examples, node operator docs,
wallet integration docs, bridge integration docs, explorer/indexer visibility,
faucet/tester funds, troubleshooting, and release compatibility.

## Current Truth

FlowChain has a working local/private runtime profile with service evidence,
wallet flow evidence, block-height advancement, owner onboarding docs,
public-RPC edge templates, hardened backup/restore rehearsal tooling, ops
snapshotting, incident drills, public RPC abuse tests, and fail-closed audits.
The public RPC discovery/readiness contract now self-reports deployment mode,
`publicRpcReady`, `productionReady`, and `localOnly` consistently, and the
local public-RPC validation rehearsal proves a local endpoint stays
non-production instead of advertising itself as shareable.

The latest service status after restoring explicit live profile observed live
block height `35906`, and a direct follow-up check advanced block height from
`35906` to `35908`. Wallet-to-wallet service flow passed in the latest full
completion audit, separate tester wallets transacted, and the public deployment
contract stayed fail-closed before endpoint sharing.

The current production truth table is intentionally `stale` until the full
completion audit is rerun after the latest public RPC changes. Its current
classification is 10 gates passed, 12 blocked on known owner inputs, 0 blocked
on repo-owned work, 0 failed, and 1 stale item: `completion-audit`, because the
completion audit evidence is older than the refreshed public deployment
contract.

The latest backup/restore validation is stronger than a simple round trip. It
proves the latest manifest points at the newest snapshot, restores the latest
snapshot, avoids targeting live state during rehearsals, and rejects corrupt,
tampered, missing-artifact, missing-manifest, stale-pointer, and wrong-chain
evidence.

It is still not production-live because the latest deployment contract remains
blocked on external owner-provided deployment inputs and because several
production surfaces still need deeper buildout beyond local proof.

Known owner input blockers:

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
- `FLOWCHAIN_BASE8453_TO_BLOCK`
- `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`
- `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`
- `FLOWCHAIN_PILOT_CONFIRMATIONS`

Until those are configured locally by the owner, public exposure, live bridge
funding, state backup proof, and friends-and-family sharing must stay blocked.

## What Is Still Missing

### 1. Live Base 8453 Bridge Pilot Hardening

Current evidence shows bridge readiness is blocked until owner Base 8453 values
exist. The expensive work is turning a guarded local bridge path into a pilot
that can safely observe real Base deposits, credit FlowChain balances exactly
once, survive reorgs and restarts, enforce caps, export evidence, and stop
without fund loss.

Missing buildout:

- Real Base 8453 observer lifecycle with resumable block cursors.
- Lockbox address validation, token contract validation, decimals validation,
  and chain-id validation before any deposit crediting.
- Confirmation-depth enforcement and reorg handling.
- Duplicate deposit protection keyed by chain id, tx hash, log index, token,
  recipient, amount, and observed block.
- Pilot caps per deposit, per account, per token, and total campaign.
- Emergency stop that halts observation and crediting while preserving forensic
  evidence.
- Reconciliation report that compares observed Base logs, credited FlowChain
  deposits, pending deposits, rejected deposits, and cap rejections.
- Withdrawal or release-intent evidence with replay protection, even if the
  actual outbound release is still operator-controlled during pilot.
- Negative tests for wrong token, wrong chain id, wrong lockbox, low
  confirmations, duplicate event, reorged event, over-cap deposit, malformed
  recipient, and restart after partially processed event.
- Operator runbook that says exactly when funds may be bridged and when the
  pilot must remain blocked.

Why it is token/time expensive:

- It touches chain state, asset accounting, owner env validation, RPC
  integration, safety policy, incident operations, and tests.
- A small accounting bug can create unbacked balances or hide a stuck deposit.
- It requires both deterministic simulation and live-input fail-closed behavior.

Minimum proof:

- `npm run flowchain:bridge:live:check`
- `npm run flowchain:bridge:infra:check`
- `npm run flowchain:live-product:e2e`
- New bridge reconciliation report with no unaccounted deposits.
- New negative-test report proving rejected unsafe deposits do not mutate
  spendable balances.

### 2. Production Public RPC Deployment Automation

Current evidence has a public RPC deployment bundle, but the owner endpoint is
not configured and not shareable. The expensive work is making FlowChain's own
RPC production exposure repeatable, guarded, observable, rate limited, and easy
to roll back.

Missing buildout:

- One-command public RPC deployment checklist that validates DNS, TLS
  termination, reverse proxy config, CORS, rate limits, upstream health, and
  response hygiene.
- Automated endpoint tests against the actual configured
  `FLOWCHAIN_RPC_PUBLIC_URL`.
- Abuse tests for large payloads, invalid methods, preflight CORS, rate-limit
  enforcement, oversized batches, request timeout behavior, and sensitive data
  leaks.
- Rollback automation that removes public exposure or flips traffic to
  maintenance mode while keeping the private node alive.
- Production systemd, NSSM, Docker, or VM setup guidance with explicit owner
  decision points.
- Public RPC SLOs: latency, uptime, latest height lag, finalized height lag,
  error rate, rate-limit event rate, disk usage, memory usage, and restart
  count.
- Separate private admin/control-plane endpoints from public wallet RPC
  endpoints.
- Public method allowlist and denylist with tests.

Why it is token/time expensive:

- It crosses repo scripts, deployment docs, edge config, live process
  management, security policy, and external verification.
- It must handle owner-specific infrastructure without writing secrets or
  values into git.

Minimum proof:

- `npm run flowchain:public-rpc:deployment-bundle`
- `npm run flowchain:public-rpc:validate`
- `npm run flowchain:public-rpc:check`
- `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30`
- Endpoint validation report proving HTTPS, CORS, rate limit, response hygiene,
  method allowlist, and height advancement.

### 3. Backup, Restore, and Disaster Recovery

Current evidence has hardened manifest-backed backup and restore rehearsal
tooling, but the configured owner backup path is missing. The expensive work is
production DR: owner-path proof, scheduled backups, retention,
restore-to-new-host proof, measured RPO/RTO, and runbooks that can be followed
during an incident.

Missing buildout:

- Owner-configured backup path validation using
  `FLOWCHAIN_RPC_STATE_BACKUP_PATH`.
- Scheduled snapshot automation with rotation and retention.
- Restore-to-clean-directory proof against the owner-configured path.
- Restore-to-new-host proof, or a no-secrets dry-run that documents every host
  requirement.
- Backup manifest schema versioning.
- Snapshot integrity checks for state DB, ledger, wallet test fixtures,
  runtime config, chain id, genesis hash, latest height, finalized height, and
  content hashes.
- Continued adversarial validation for missing files, modified files,
  mismatched manifests, wrong chain id, stale latest pointer, and stale
  finalized height as new backup surfaces are added.
- Recovery runbook for public RPC node, bridge observer, control plane, and
  external tester packet.
- RPO and RTO targets with a script that measures whether the current setup
  meets them.

Why it is token/time expensive:

- DR is more than making a zip file. It needs proof that the restored node can
  actually resume the chain without silent state divergence.
- The verification must be deterministic and safe on a developer machine.

Minimum proof:

- `npm run flowchain:backup:restore:validate`
- `npm run flowchain:backup:create`
- `npm run flowchain:backup:restore:verify`
- `npm run flowchain:backup:check`
- DR report showing owner-path snapshot proof, latest-snapshot restore proof,
  adversarial tamper/missing/wrong-chain rejection, measured RPO, measured RTO,
  and remaining owner blockers.

### 4. Observability and Incident Operations

Current evidence has an ops snapshot that separates critical incidents from
expected blockers. The expensive work is building production operator
visibility and incident loops that keep the chain safe while people test it.

Missing buildout:

- Continuous health monitor for private node, public RPC, bridge observer,
  backup freshness, block production, finality, disk, memory, and process
  restart count.
- Alert threshold definitions and escalation policy.
- Incident command bundle: status, diagnose, pause bridge, stop public RPC,
  restart service, export evidence, validate backup, restore rehearsal, reopen
  tester packet.
- Machine-readable status page JSON with public-safe fields.
- Log rotation and redaction checks.
- Long-running monitor that proves block production over a meaningful window.
- Incident drills for RPC down, bridge paused, backup stale, state corrupt,
  public endpoint misconfigured, and chain not advancing.
- Operator timeline evidence so every incident report includes what happened,
  when it happened, and what command changed state.

Why it is token/time expensive:

- It requires designing stable operational contracts before real testers arrive.
- The monitoring must be useful without leaking secrets or overexposing admin
  controls.

Minimum proof:

- `npm run flowchain:ops:snapshot -- -AllowBlocked`
- `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30`
- New incident-drill report proving each drill fails closed and leaves evidence.

### 5. External Tester and Friends-and-Family Launch Flow

Current evidence says local tester rehearsal is ready, but the external packet
is not shareable until public RPC, backup, and bridge gates pass. The expensive
work is turning a local demo into a safe external pilot.

Missing buildout:

- Shareable tester packet generated only when public gates pass.
- Hosted or packaged wallet path for testers.
- Wallet creation, import, backup, send, receive, and transaction history flows
  validated against the same public RPC endpoint testers will use.
- Tester faucet or pilot allocation flow with caps, abuse limits, and audit
  logs.
- Support diagnostics bundle that testers can export without secrets.
- Known-issues and emergency-stop language for pilot testers.
- Wallet-to-wallet transaction proof across separate accounts and separate
  machines if available.
- Public explorer or transaction lookup page so testers can verify block and tx
  inclusion.
- Launch readiness script that refuses to produce the packet if any gate is
  stale, blocked, or older than the allowed freshness window.

Why it is token/time expensive:

- It spans wallet UX, RPC availability, chain state, explorer reads, docs,
  diagnostics, and support operations.
- The main risk is accidentally letting testers send funds before the bridge
  and backup gates are proven.

Minimum proof:

- `npm run flowchain:tester:readiness`
- `npm run flowchain:external-tester:packet`
- `npm run flowchain:live-product:e2e`
- Generated shareable packet with `packetShareable=True` only after all public
  gates pass.

### 6. Multi-Node Runtime, Consensus, and Networking

The current local/private service evidence proves block production, but a
production L1 needs a clear path beyond one local process. The expensive work is
turning a single-node runtime into a networked chain with defined validator or
sequencer behavior, peer identity, state sync, and failure handling.

Missing buildout:

- Explicit consensus model documentation: single sequencer, permissioned
  validators, or another model.
- Node identity and peer configuration.
- Genesis and chain-id immutability checks.
- Multi-node startup in local dev.
- Peer discovery or static peer config.
- Block propagation and state sync tests.
- Finality rules and fork-choice tests.
- Network partition and reconnect tests.
- Replay and duplicate transaction protection across nodes.
- Validator or producer failover policy if applicable.
- Evidence that a node can start from genesis, catch up, restart, and agree on
  latest/finalized height.

Why it is token/time expensive:

- Consensus and networking are architecture-heavy. A shallow implementation can
  look alive while hiding finality or state-divergence bugs.
- Every wallet, RPC, bridge, and explorer assumption depends on the final chain
  model.

Minimum proof:

- New `flowchain:multinode:e2e` command.
- New multi-node report showing two or more nodes converge on block height,
  state root, account balances, and transaction inclusion.
- Architecture audit updated with the production consensus model.

### 7. Wallet Security, Custody, and Signing

Wallet flows exist, but production wallet behavior needs stronger custody,
signing, recovery, and transaction safety. The expensive work is making wallet
creation and transfer usable by real testers without leaking keys or signing
the wrong payload.

Missing buildout:

- Production-shaped wallet key storage strategy.
- Import/export/recovery flow with explicit secret handling.
- Transaction signing domain separation with chain id, nonce, account, method,
  amount, fee, and recipient.
- Nonce management and duplicate-send protection.
- Address validation and checksum rules.
- Offline or local-only signing boundary if the RPC is public.
- Wallet diagnostics that redact seeds, private keys, mnemonics, and raw secret
  material.
- Negative tests for wrong chain id, stale nonce, replayed transaction, bad
  recipient, insufficient balance, malformed signature, and RPC mismatch.
- Clear wallet-to-wallet e2e evidence using independently created wallets.

Why it is token/time expensive:

- Wallet mistakes become user-facing loss or confusion quickly.
- It touches cryptography, UX, RPC contracts, state transitions, and support
  tooling.

Minimum proof:

- `npm run flowchain:wallet:e2e`
- `npm run flowchain:service-wallet:e2e`
- New signing negative-test report.
- No-secret scan proving generated diagnostics and docs contain no private
  material.

### 8. Ledger Indexer, Explorer, and Transaction Visibility

Testers need to see blocks, transactions, balances, and bridge events. The
current control-plane and explorer path needs production completeness.

Missing buildout:

- Stable block, transaction, account, token, and bridge-event index.
- Backfill and reindex command.
- Public-safe explorer API that reads committed chain state.
- Transaction lookup by hash, account, block, bridge deposit id, and status.
- Balance history and nonce history.
- Indexer restart and crash recovery proof.
- Explorer stale-data detection.
- Reorg or finality marker handling if the chain model supports it.
- API response shape documented for wallets and SDKs.

Why it is token/time expensive:

- Indexers often drift from chain truth unless they are tested against state
  roots, block heights, and restart behavior.
- Wallet support and public trust depend on reliable transaction visibility.

Minimum proof:

- New `flowchain:indexer:e2e` command.
- New explorer report proving a wallet transfer appears in the indexed API and
  matches runtime state.

### 9. Release, Installer, and Upgrade Automation

The chain cannot be called production-ready if it only runs from a developer
checkout. The expensive work is packaging, installing, upgrading, rolling back,
and validating the same runtime on the owner host.

Missing buildout:

- Owner-host install script for the chosen runtime target.
- Service registration with least-privilege user guidance.
- Environment file scaffolding and validation.
- Upgrade command that preserves state and runs migrations.
- Rollback command that restores the previous runtime binary or package.
- Versioned state schema and migration proofs.
- Release notes generated from audits.
- Clean-checkout bootstrap test.
- Host prerequisites check for Node, npm, PowerShell, disk, firewall, port
  availability, and write permissions.

Why it is token/time expensive:

- Deployment bugs are often outside app code and only show up when the owner
  tries to run the system on a fresh host.
- The scripts must be safe, idempotent, and no-secret by default.

Minimum proof:

- New `flowchain:install:check` command.
- New install report proving fresh-host prerequisites and state-preserving
  upgrade/rollback rehearsal.

### 10. Security, Fuzzing, and Load Testing

Production readiness needs adversarial checks, not just happy-path e2e. The
expensive work is building tests that try to break RPC, wallet transactions,
bridge accounting, state restore, and explorer indexing.

Missing buildout:

- RPC method fuzzing and schema validation.
- Transaction parser fuzzing.
- Signature verification negative tests.
- Bridge event parser fuzzing.
- Large batch, large payload, timeout, and concurrency load tests.
- Rate-limit tests against public RPC edge.
- No-secret scans over generated reports, packets, logs, and templates.
- Static unsafe-claim checks for docs.
- Threat model for wallet, bridge, public RPC, state backup, and tester launch.
- Load profile that measures throughput, latency, block lag, memory growth,
  error rates, and recovery after restart.

Why it is token/time expensive:

- Security and load tests require a meaningful harness, careful fixtures, and
  repeatable evidence.
- The results can force changes across RPC, chain runtime, wallet, and ops.

Minimum proof:

- New `flowchain:security:audit` command.
- New `flowchain:load:test` command.
- Reports proving no critical findings remain before public sharing.

### 11. SDK and Developer Tooling

If people are going to connect to the chain, the developer surface needs stable
SDKs, examples, and compatibility checks.

Missing buildout:

- Minimal TypeScript SDK for wallet creation, balance lookup, transfer submit,
  transaction lookup, bridge status, and endpoint health.
- CLI for create wallet, inspect account, send transaction, watch blocks, and
  export diagnostics.
- Example app using the public RPC.
- Typed RPC schema and generated client if the repo tooling supports it.
- Version compatibility matrix between node, wallet, explorer, and SDK.
- SDK tests against local private RPC and configured public RPC.

Why it is token/time expensive:

- Good SDKs encode the real system contracts and reveal inconsistencies across
  RPC, wallet, explorer, and docs.

Minimum proof:

- New `flowchain:sdk:e2e` command.
- SDK examples that pass against local runtime and fail closed on missing public
  RPC env.

### 12. Final Completion Audit

The completion audit is currently the highest-priority repo-owned freshness
gap. It was fresh earlier, but after public RPC hardening the truth table now
marks it stale because the completion-audit evidence predates the refreshed
public deployment contract. A timed parent audit run also showed why timeout
handling matters: the aggregate can stop the live service before completing, so
the audit loop must either finish, restart cleanly, or leave unmistakable
recovery evidence. The service has since been restarted in explicit live
profile and block production was rechecked.

Missing buildout:

- Completion audit refresh that includes latest backup/restore, ops snapshot,
  public RPC bundle, owner inputs, bridge checks, tester packet, public
  deployment contract, no-secret scan, unsafe-claim scan, and service monitor.
- Timeout handling that does not leave orphan audit processes or leave the live
  service stopped after parent interruption.
- Freshness windows for every evidence file.
- Clear distinction between failed repo-owned checks and blocked owner-input
  checks.
- Release decision summary that cannot say ready while any public gate is
  blocked.
- Fast path for local-only audit and full path for owner-configured public
  audit.

Why it is token/time expensive:

- A real completion audit has to coordinate many scripts without hiding stale
  results or hanging indefinitely.

Minimum proof:

- `npm run flowchain:completion:audit -- -AllowBlocked`
- No orphan audit process after timeout or failure.
- `Completion ready: True` only when all production gates pass.

## Dependency Order

1. Run the coordinator first to refresh the truth table and assign ownership.
2. Build backup/DR and observability in parallel. They reduce operational risk
   for every later task.
3. Build public RPC automation and tester launch flow in parallel, but keep the
   tester packet blocked until public RPC, backup, and bridge are ready.
4. Build bridge hardening before any live funded pilot.
5. Build wallet security, indexer/explorer, SDK, and load/security harnesses in
   parallel with disjoint write sets.
6. Build multi-node/consensus only after the current single-node contracts are
   documented, unless the coordinator decides the production architecture must
   change first.
7. Run the completion audit worker after every major worker lands, and again
   before any public sharing.

## Shared Worker Rules

Every worker must follow these rules:

- You are not alone in the codebase. Do not revert edits made by others.
- Own only the files and modules named in your prompt unless you first inspect
  and document why another file must be changed.
- Do not print or commit secrets, private keys, mnemonics, RPC credentials,
  webhook URLs, bearer tokens, API keys, vault ciphertext, or owner env values.
- Do not ask the owner to paste secret values into chat.
- Use owner env variable names only, never values.
- Make implementation changes, not docs-only placeholders, unless the prompt is
  explicitly a docs/runbook prompt.
- Add or update verification scripts for every new production claim.
- Leave machine-readable JSON evidence and a short markdown summary.
- Keep every live-funds path fail-closed until owner inputs and pilot
  acknowledgements exist.
- Commit and push only after tests pass or after clearly documenting the exact
  blocker.

## /goal Prompt: L1 Coordinator and Truth Table

```text
/goal FlowChain L1 Coordinator and Truth Table

You are coordinating the FlowChain production L1 build. Keep working until the
repo has a fresh, machine-checkable truth table showing what is complete, what
is blocked only by owner inputs, and what is still repo-owned work.

You are not alone in the codebase. Do not revert edits made by others. Before
editing, inspect `git status --short --branch` and the latest reports under
`docs/agent-runs/live-product-infra-rpc`.

Ownership:
- `docs/agent-runs/live-product-infra-rpc/PRODUCTION_TRUTH_TABLE.md`
- `docs/agent-runs/live-product-infra-rpc/production-truth-table-report.json`
- Any new coordinator script under `infra/scripts/*truth*` if needed
- Minimal README or package script updates required to expose the command

Build:
1. Create or update a command that reads the latest service, public deployment,
   owner inputs, backup, bridge, tester, ops, no-secret, and completion reports.
2. Classify every gate as `passed`, `blocked-owner-input`, `blocked-repo-work`,
   `failed`, or `stale`.
3. Include freshness timestamps and command names for regenerating stale
   evidence.
4. Include the exact owner input names still missing, without values.
5. Include the next three highest-impact repo-owned tasks.
6. Fail closed if any required report is missing, stale, malformed, or contains
   secret-looking material.
7. Update docs so later workers can read the truth table instead of guessing.

Verify:
- `npm run flowchain:no-secret:scan`
- `node infra/scripts/check-unsafe-claims.mjs`
- The new truth-table command
- `git diff --check`

Stop condition:
Commit and push the truth-table work only after the generated markdown and JSON
accurately reflect the latest repo state and do not claim public readiness while
owner inputs are missing.
```

## /goal Prompt: Live Bridge Pilot Hardening Worker

```text
/goal FlowChain Live Bridge Pilot Hardening

Build the Base 8453 bridge pilot from guarded readiness checks into a
production-shaped, fail-closed bridge observer and accounting subsystem.

You are not alone in the codebase. Do not revert edits made by others. Own the
bridge code, bridge scripts, bridge tests, and bridge evidence docs only. If
you must touch runtime ledger/accounting files, document the reason in your
final report.

Likely write scope:
- `infra/scripts/*bridge*`
- FlowChain bridge runtime modules
- Bridge tests and fixtures
- `docs/agent-runs/live-product-infra-rpc/BRIDGE_PILOT_HARDENING.md`
- `docs/agent-runs/live-product-infra-rpc/bridge-pilot-hardening-report.json`
- Package scripts needed for bridge hardening checks

Build:
1. Inspect current bridge readiness scripts and reports.
2. Add resumable Base 8453 observation with explicit cursor persistence, but
   keep it disabled unless all owner env names are configured locally.
3. Validate chain id, lockbox, supported token, decimals, from/to block window,
   confirmation depth, pilot cap, total cap, and operator acknowledgement.
4. Implement duplicate deposit protection and restart-safe processing.
5. Implement reorg-safe handling. A deposit below the confirmation threshold
   must not be spendable.
6. Add rejection paths for wrong chain, wrong token, wrong lockbox, malformed
   recipient, over-cap amount, duplicate event, stale block, and reorged event.
7. Add bridge reconciliation output that lists observed, credited, pending,
   rejected, duplicate, and capped deposits.
8. Add emergency-stop evidence export for the bridge observer.
9. Keep all live-funds behavior fail-closed until owner inputs exist.

Verify:
- `npm run flowchain:bridge:live:check -- -AllowBlocked`
- `npm run flowchain:bridge:infra:check -- -AllowBlocked`
- New bridge hardening negative-test command
- `npm run flowchain:no-secret:scan`
- `node infra/scripts/check-unsafe-claims.mjs`
- `git diff --check`

Stop condition:
Do not claim live bridge readiness unless the configured Base 8453 endpoint and
lockbox pass validation. If owner values are missing, the final state should be
`blocked-owner-input` with all repo-owned bridge simulations and negative tests
passing.
```

## /goal Prompt: Public RPC Deployment Automation Worker

```text
/goal FlowChain Production Public RPC Deployment Automation

Make FlowChain's own public RPC deployment repeatable, validated, rate-limited,
observable, and reversible. The RPC is ours because this is our own chain, but
the owner must still provide DNS/TLS/edge details and local env values.

You are not alone in the codebase. Do not revert edits made by others. Own
public RPC scripts, public RPC deployment docs, public RPC validation tests, and
public RPC evidence reports only.

Likely write scope:
- `infra/scripts/*public-rpc*`
- `docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_*`
- `docs/agent-runs/live-product-infra-rpc/public-rpc-*`
- Package scripts for public RPC deployment, validation, rollback, and abuse
  tests

Build:
1. Inspect current public RPC edge template, deployment bundle, validation, and
   readiness scripts.
2. Add one command that checks private origin health, public URL reachability,
   HTTPS/TLS termination flag, CORS, rate limit, method allowlist, response
   hygiene, block height advancement, and rollback commands.
3. Add public RPC abuse tests for invalid method, oversized payload, oversized
   batch, timeout, denied origin, missing origin, repeated requests above rate
   limit, and sensitive response fields.
4. Generate a no-secret deployment packet with exact owner tasks, exact commands,
   exact rollback steps, and expected success evidence.
5. Add a maintenance/closed mode or documented rollback path that stops public
   sharing while keeping the private node safe.
6. Keep the public endpoint not shareable until `FLOWCHAIN_RPC_PUBLIC_URL`,
   `FLOWCHAIN_RPC_ALLOWED_ORIGINS`, `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`, and
   `FLOWCHAIN_RPC_TLS_TERMINATED` are set and validated locally.

Verify:
- `npm run flowchain:service:status`
- `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30`
- `npm run flowchain:public-rpc:deployment-bundle`
- `npm run flowchain:public-rpc:validate`
- `npm run flowchain:public-rpc:check -- -AllowBlocked`
- New public RPC abuse-test command
- `npm run flowchain:no-secret:scan`
- `git diff --check`

Stop condition:
Commit and push when repo-owned deployment automation is complete and the
public RPC gate either passes with owner inputs or blocks only on named missing
owner inputs.
```

## /goal Prompt: Backup Restore Disaster Recovery Worker

```text
/goal FlowChain Backup Restore Disaster Recovery

Turn the existing backup/restore rehearsal into a production disaster-recovery
system with retention, restore proof, corruption detection, and incident
runbooks.

You are not alone in the codebase. Do not revert edits made by others. Own
backup scripts, DR reports, and backup docs only unless a runtime state schema
change is required and documented.

Likely write scope:
- `infra/scripts/*backup*`
- `infra/scripts/*restore*`
- `infra/scripts/*disaster*`
- `docs/agent-runs/live-product-infra-rpc/BACKUP_DR.md`
- `docs/agent-runs/live-product-infra-rpc/backup-dr-report.json`
- Package scripts for backup scheduling, restore drill, and DR audit

Build:
1. Inspect current backup create, restore verify, and backup-restore validation
   scripts.
2. Add scheduled backup plan generation for Windows Task Scheduler or the repo's
   chosen service runner, without enabling it silently.
3. Validate `FLOWCHAIN_RPC_STATE_BACKUP_PATH` when present and fail closed when
   missing.
4. Add retention policy checks and dry-run deletion reporting.
5. Add restore-to-clean-directory and restore-to-new-host rehearsal modes.
6. Measure RPO and RTO from generated evidence.
7. Validate chain id, genesis hash, latest height, finalized height, manifest
   hash, file hashes, and state schema version.
8. Add corruption cases for modified manifest, missing state file, wrong chain
   id, stale height, and changed file content.
9. Add incident runbook commands for backup stale, restore needed, corrupt
   snapshot, and backup path unavailable.

Verify:
- `npm run flowchain:backup:restore:validate`
- `npm run flowchain:backup:create -- -AllowBlocked`
- `npm run flowchain:backup:restore:verify -- -AllowBlocked`
- `npm run flowchain:backup:check -- -AllowBlocked`
- New DR audit command
- `npm run flowchain:no-secret:scan`
- `git diff --check`

Stop condition:
If the owner backup path is missing, final state must be `blocked-owner-input`
with local DR simulation passing. If configured, prove an actual snapshot and
restore rehearsal from that path.
```

## /goal Prompt: Observability Incident Operations Worker

```text
/goal FlowChain Observability and Incident Operations

Build production operator visibility for FlowChain: continuous health checks,
incident drills, status output, log hygiene, and emergency commands.

You are not alone in the codebase. Do not revert edits made by others. Own ops,
monitoring, incident, and status scripts plus their reports.

Likely write scope:
- `infra/scripts/*ops*`
- `infra/scripts/*monitor*`
- `infra/scripts/*incident*`
- `docs/agent-runs/live-product-infra-rpc/OPS_*`
- `docs/agent-runs/live-product-infra-rpc/INCIDENT_DRILLS.md`
- Package scripts for ops status, drills, and long monitors

Build:
1. Inspect current service status, service monitor, ops snapshot, emergency stop,
   and public deployment contract scripts.
2. Add a continuous health report covering private node, public RPC gate, bridge
   gate, backup freshness, latest height, finalized height, process id, restart
   count, disk, memory, and report freshness.
3. Add incident drills for RPC down, chain not advancing, backup stale, bridge
   paused, public RPC blocked, and corrupt backup.
4. Add public-safe status JSON for testers and private operator JSON for local
   diagnostics.
5. Add log redaction or scanning for generated logs and incident bundles.
6. Add threshold configuration with safe defaults and owner env names only.
7. Make every incident drill leave markdown and JSON evidence.

Verify:
- `npm run flowchain:ops:snapshot -- -AllowBlocked`
- `npm run flowchain:service:monitor -- -DurationSeconds 300 -PollSeconds 30`
- New incident-drill command
- `npm run flowchain:no-secret:scan`
- `node infra/scripts/check-unsafe-claims.mjs`
- `git diff --check`

Stop condition:
Commit and push when an operator can run one status command and see whether the
chain is healthy, blocked by owner inputs, or failed because of repo-owned
problems.
```

## /goal Prompt: External Tester Launch Worker

```text
/goal FlowChain External Tester Launch Flow

Build the friends-and-family launch flow so testers can create wallets, connect
to the chain, receive pilot funds only when allowed, send wallet-to-wallet
transactions, and export diagnostics without secrets.

You are not alone in the codebase. Do not revert edits made by others. Own the
tester packet, tester readiness scripts, launch docs, and tester diagnostics
only.

Likely write scope:
- `infra/scripts/*tester*`
- `docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_*`
- `docs/agent-runs/live-product-infra-rpc/tester-*`
- Wallet tester fixtures only if required
- Package scripts for tester launch and diagnostics

Build:
1. Inspect current tester readiness, external tester packet, wallet e2e, and
   service wallet e2e evidence.
2. Add a shareable packet generator that refuses to produce public instructions
   unless public RPC, backup, bridge, owner acknowledgement, and no-secret gates
   pass.
3. Add tester steps for create wallet, connect RPC, receive pilot funds, send to
   another wallet, view tx status, view block height, and export diagnostics.
4. Add a local rehearsal mode that proves the same flow against private RPC
   without claiming public readiness.
5. Add support diagnostics redaction tests.
6. Add launch freshness checks so old reports cannot be reused.
7. Add emergency wording and rollback instructions for pausing the pilot.

Verify:
- `npm run flowchain:tester:readiness -- -AllowBlocked`
- `npm run flowchain:external-tester:packet -- -AllowBlocked`
- `npm run flowchain:service-wallet:e2e`
- `npm run flowchain:no-secret:scan`
- `git diff --check`

Stop condition:
The packet may be generated as local rehearsal while blocked, but it must not be
marked shareable until all production public gates pass with fresh evidence.
```

## /goal Prompt: Multi-Node Consensus Worker

```text
/goal FlowChain Multi-Node Consensus and Networking

Define and build the production path beyond a single local process. Prove that
multiple FlowChain nodes can start, connect, exchange or verify blocks, restart,
and converge on the same chain state according to the chosen consensus model.

You are not alone in the codebase. Do not revert edits made by others. Own the
node networking, consensus docs, multi-node harness, and multi-node reports.
Coordinate carefully before changing shared runtime state transition code.

Likely write scope:
- FlowChain node runtime and networking modules
- Multi-node test harness files
- `infra/scripts/*multinode*`
- `docs/agent-runs/live-product-infra-rpc/MULTINODE_CONSENSUS.md`
- `docs/agent-runs/live-product-infra-rpc/multinode-consensus-report.json`
- Architecture docs that describe the selected production model

Build:
1. Inspect current chain runtime, service scripts, RPC server, and architecture
   audit.
2. Document the selected production model: single sequencer, permissioned
   validators, or another explicit model. Do not leave this ambiguous.
3. Add node identity and static peer config for local multi-node rehearsal.
4. Add genesis and chain-id consistency checks.
5. Add multi-node start, stop, restart, and status commands.
6. Add block propagation or state sync according to the selected model.
7. Add finality and fork-choice rules according to the selected model.
8. Add tests for restart, catch-up, duplicate transaction, stale peer, partition,
   and reconnect.
9. Generate evidence that two or more nodes agree on latest height, finalized
   height, state root or equivalent digest, balances, and transaction inclusion.

Verify:
- New `npm run flowchain:multinode:e2e`
- `npm run flowchain:architecture:audit -- -AllowBlocked`
- `npm run flowchain:no-secret:scan`
- `git diff --check`

Stop condition:
Do not claim decentralized production readiness unless the consensus model and
multi-node proof support that exact claim. If the product remains a single
sequencer pilot, document that honestly and make the audits enforce it.
```

## /goal Prompt: Wallet Security and Custody Worker

```text
/goal FlowChain Wallet Security Custody and Signing

Harden wallet creation, key handling, signing, transaction submission,
diagnostics, and wallet-to-wallet transfer proof for real external testers.

You are not alone in the codebase. Do not revert edits made by others. Own
wallet modules, wallet tests, signing validation, diagnostics redaction, and
wallet evidence reports.

Likely write scope:
- Wallet packages/modules
- Wallet e2e tests and fixtures
- `infra/scripts/*wallet*`
- `docs/agent-runs/live-product-infra-rpc/WALLET_SECURITY.md`
- `docs/agent-runs/live-product-infra-rpc/wallet-security-report.json`

Build:
1. Inspect current wallet creation, import/export, signing, send, and service
   wallet e2e flows.
2. Define wallet key storage boundaries and ensure diagnostics never include
   private material.
3. Add transaction signing domain separation with chain id, nonce, recipient,
   amount, fee, method, and payload hash.
4. Add nonce management and duplicate-submit protection.
5. Add address validation and checksum handling.
6. Add negative tests for wrong chain id, stale nonce, replay, malformed
   signature, bad recipient, insufficient balance, and mismatched RPC endpoint.
7. Add two-wallet or multi-wallet e2e evidence proving send and receive using
   independent accounts.
8. Add diagnostic export with explicit redaction tests.

Verify:
- `npm run flowchain:wallet:e2e`
- `npm run flowchain:service-wallet:e2e`
- New wallet security command
- `npm run flowchain:no-secret:scan`
- `git diff --check`

Stop condition:
Commit and push only when wallet-to-wallet send works against the live private
service and all signing negative tests fail closed.
```

## /goal Prompt: Ledger Indexer Explorer Worker

```text
/goal FlowChain Ledger Indexer Explorer

Build reliable transaction visibility for testers and operators: blocks,
transactions, accounts, balances, bridge events, and transaction lookup must be
indexed from committed runtime state and recover after restart.

You are not alone in the codebase. Do not revert edits made by others. Own
indexer, explorer API, explorer tests, and explorer evidence reports.

Likely write scope:
- Control-plane and explorer modules
- Indexer modules and scripts
- `infra/scripts/*indexer*`
- `infra/scripts/*explorer*`
- `docs/agent-runs/live-product-infra-rpc/INDEXER_EXPLORER.md`
- `docs/agent-runs/live-product-infra-rpc/indexer-explorer-report.json`

Build:
1. Inspect current control-plane, explorer, ledger, transaction, and block APIs.
2. Add or harden indexes for blocks, tx hashes, accounts, balances, bridge
   deposits, statuses, and finalized markers.
3. Add backfill and reindex commands.
4. Add restart recovery proof for the indexer.
5. Add stale-data detection by comparing indexed latest/finalized height against
   runtime RPC height.
6. Add transaction lookup by hash, account, block, and bridge deposit id.
7. Add an e2e test where a wallet transfer is submitted, included in a block,
   indexed, and returned by explorer API with matching balances.
8. Document public-safe explorer API response shapes.

Verify:
- New `npm run flowchain:indexer:e2e`
- `npm run flowchain:live-product:e2e -- -AllowBlocked`
- `npm run flowchain:no-secret:scan`
- `git diff --check`

Stop condition:
Commit and push when explorer/indexer evidence matches committed runtime state
after a restart and no stale-data path reports healthy by mistake.
```

## /goal Prompt: Release Installer Upgrade Worker

```text
/goal FlowChain Release Installer Upgrade Rollback

Make FlowChain installable and upgradeable outside a developer checkout. Build
owner-host prerequisite checks, service install guidance, state-preserving
upgrade rehearsal, and rollback proof.

You are not alone in the codebase. Do not revert edits made by others. Own
installer scripts, release scripts, upgrade/rollback rehearsal, and install docs.

Likely write scope:
- `infra/scripts/*install*`
- `infra/scripts/*upgrade*`
- `infra/scripts/*release*`
- `docs/agent-runs/live-product-infra-rpc/INSTALL_UPGRADE.md`
- `docs/agent-runs/live-product-infra-rpc/install-upgrade-report.json`
- Package scripts for install checks and upgrade rehearsal

Build:
1. Inspect current service start, stop, restart, status, owner env template, and
   deployment bundle scripts.
2. Add owner-host prerequisite checks for Node, npm, PowerShell, disk, ports,
   firewall hints, write permissions, and env-file path.
3. Add service install plan for the chosen Windows service runner or documented
   deployment mode.
4. Add state-preserving upgrade rehearsal using a copied state directory.
5. Add rollback rehearsal that restores previous runtime/package files and
   proves the chain state remains readable.
6. Add version and state-schema recording in reports.
7. Generate release notes from current audit reports without secrets.

Verify:
- New `npm run flowchain:install:check`
- New `npm run flowchain:upgrade:rehearse`
- `npm run flowchain:service:status`
- `npm run flowchain:no-secret:scan`
- `git diff --check`

Stop condition:
Commit and push when a fresh operator can run the install check and see exact
next actions without guessing and without any secret values written to git.
```

## /goal Prompt: Security Load Fuzz Worker

```text
/goal FlowChain Security Load Fuzz Audit

Build adversarial verification for RPC, transaction parsing, wallet signing,
bridge event parsing, backup integrity, public endpoint abuse, and sustained
load.

You are not alone in the codebase. Do not revert edits made by others. Own
security tests, fuzz/load scripts, threat model docs, and security evidence
reports.

Likely write scope:
- `infra/scripts/*security*`
- `infra/scripts/*fuzz*`
- `infra/scripts/*load*`
- Security test fixtures
- `docs/agent-runs/live-product-infra-rpc/SECURITY_LOAD_AUDIT.md`
- `docs/agent-runs/live-product-infra-rpc/security-load-audit-report.json`

Build:
1. Inspect RPC handlers, transaction parsing, wallet signing, bridge parsers,
   public RPC validation, no-secret scan, and unsafe-claim scan.
2. Add RPC schema fuzzing for malformed methods, params, batch requests, huge
   payloads, bad content types, and unknown methods.
3. Add transaction parser and signature verifier negative tests.
4. Add bridge event parser fuzz cases.
5. Add load test for sustained block production and RPC reads/writes with
   latency, error rate, memory, and height-lag metrics.
6. Add public RPC abuse tests when public env values exist, and blocked-owner
   status when they do not.
7. Add threat model covering wallet custody, bridge accounting, RPC exposure,
   backups, explorer, tester launch, and operator incidents.
8. Make the audit fail on any critical issue and produce a JSON severity list.

Verify:
- New `npm run flowchain:security:audit`
- New `npm run flowchain:load:test`
- `npm run flowchain:no-secret:scan`
- `node infra/scripts/check-unsafe-claims.mjs`
- `git diff --check`

Stop condition:
Commit and push when the security/load audit produces actionable severity-coded
evidence and cannot pass with critical findings.
```

## /goal Prompt: SDK Developer Tooling Worker

```text
/goal FlowChain SDK CLI Developer Tooling

Build the developer surface people need to connect to FlowChain: typed SDK,
CLI, examples, RPC schema, and compatibility checks.

You are not alone in the codebase. Do not revert edits made by others. Own SDK,
CLI, examples, docs, and SDK evidence reports.

Likely write scope:
- SDK package or module
- CLI package or module
- Example app or example scripts
- `infra/scripts/*sdk*`
- `docs/agent-runs/live-product-infra-rpc/SDK_DEVELOPER_TOOLING.md`
- `docs/agent-runs/live-product-infra-rpc/sdk-developer-tooling-report.json`

Build:
1. Inspect current RPC contracts, wallet functions, explorer APIs, and developer
   goal docs.
2. Add a minimal TypeScript SDK for health, block height, create wallet where
   appropriate, import/connect wallet, balance, submit transfer, transaction
   lookup, and bridge status.
3. Add CLI commands for health, watch blocks, create wallet, inspect account,
   send transaction, lookup transaction, and export diagnostics.
4. Add examples that run against local private RPC and configured public RPC.
5. Add typed response schemas or generated types if the repo pattern supports
   it.
6. Add compatibility checks between node, wallet, explorer, and SDK versions.
7. Keep secret material out of example outputs and diagnostics.

Verify:
- New `npm run flowchain:sdk:e2e`
- `npm run flowchain:service:status`
- `npm run flowchain:no-secret:scan`
- `git diff --check`

Stop condition:
Commit and push when a developer can use the SDK or CLI to connect, inspect
height, check balance, submit a transfer in local rehearsal, and lookup the tx.
```

## /goal Prompt: Completion Audit Worker

```text
/goal FlowChain Completion Audit Release Gate

Make the completion audit the single strict release gate for FlowChain public
readiness. It must refresh evidence, detect stale reports, avoid orphan
processes, distinguish owner blockers from repo failures, and refuse unsafe
claims.

You are not alone in the codebase. Do not revert edits made by others. Own the
completion audit script, completion audit reports, freshness checks, and package
script wiring.

Likely write scope:
- `infra/scripts/*completion*`
- `infra/scripts/*audit*`
- `docs/agent-runs/live-product-infra-rpc/COMPLETION_AUDIT.md`
- `docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json`
- Package scripts related to completion audit

Build:
1. Inspect the current completion audit and the latest service, public
   deployment, backup, ops, bridge, tester, owner input, no-secret, and unsafe
   claim reports.
2. Add freshness windows and report provenance for every evidence file.
3. Add timeout handling so failed or timed-out audits do not leave orphan child
   processes.
4. Add a fast local audit mode and a full owner-configured public audit mode.
5. Add release decision logic:
   - `ready` only when every production gate passes with fresh evidence.
   - `blocked-owner-input` only when repo-owned checks pass and named owner
     inputs are missing.
   - `failed` when any repo-owned check fails.
   - `stale` when any report is too old for the release decision.
6. Include latest block height, finalized height, wallet e2e status, public RPC
   status, backup proof, bridge status, tester packet status, and no-secret
   status.
7. Make the audit fail closed on unsafe public-ready wording.

Verify:
- `npm run flowchain:completion:audit -- -AllowBlocked`
- `npm run flowchain:no-secret:scan`
- `node infra/scripts/check-unsafe-claims.mjs`
- `git diff --check`

Stop condition:
Commit and push only when the audit can complete or block cleanly without
orphan processes and without claiming completion while owner inputs are absent.
```

## /goal Prompt: Nightly Autonomous Loop

```text
/goal FlowChain Nightly Autonomous Build Loop

Keep working autonomously on FlowChain production readiness. Do not stop at a
plan. Repeatedly choose the highest-impact unblocked repo-owned task, implement
it, verify it, commit it, push it, and refresh the truth table until the chain
is production-live or the only remaining blockers are owner inputs that cannot
be safely invented.

You are not alone in the codebase. Do not revert edits made by others. Start
each loop by inspecting `git status --short --branch`, the latest truth table,
the public deployment contract, ops snapshot, and completion audit.

Loop:
1. Refresh the truth table.
2. Pick the highest-impact unblocked repo-owned gap from this queue.
3. State the owned write scope before editing.
4. Build the smallest production-shaped slice that materially moves the chain
   toward live readiness.
5. Add or update verification scripts and evidence reports.
6. Run the relevant targeted tests, no-secret scan, unsafe-claim scan, and
   `git diff --check`.
7. Commit and push a coherent change.
8. Refresh the public deployment contract or completion audit if the change
   affects launch readiness.
9. Repeat.

Prioritize in this order unless a fresh audit proves another task is more
urgent:
1. Completion audit reliability and truth table.
2. Backup/DR production proof.
3. Public RPC deployment automation and abuse tests.
4. Observability and incident drills.
5. Bridge pilot hardening.
6. External tester launch flow.
7. Wallet security and custody.
8. Indexer/explorer transaction visibility.
9. Multi-node consensus and networking.
10. Security/load/fuzz audit.
11. Release installer and upgrade rehearsal.
12. SDK and CLI developer tooling.
13. Full developer ecosystem dev pack from
    `17-developer-ecosystem-dev-pack.md`.

Hard safety rules:
- Do not broadcast transactions on Base 8453 unless owner env values exist and
  the pilot operator acknowledgement is explicitly set.
- Do not expose or share the public RPC endpoint until the public deployment
  contract says deployment ready and packet shareable.
- Do not create fake owner values.
- Do not claim the goal is complete until the completion audit says ready from
  fresh evidence.

Stop condition:
The earliest valid stop is when all production gates pass and the completion
audit says ready. If owner inputs are missing, keep improving repo-owned
systems until the only remaining blockers are accurately classified
`blocked-owner-input`.
```

## Final Completion Criteria

The whole L1 chain is not complete until all of these are true from fresh
evidence:

1. Wallets can be created, imported, backed up, and used to sign transactions.
2. Users can connect through the configured public FlowChain RPC endpoint.
3. The chain is producing blocks and finality evidence over a sustained window.
4. Wallet-to-wallet transfers work and are visible in explorer/indexer output.
5. Bridge deposits from Base 8453 are observed, validated, capped, credited, and
   reconciled, or the pilot remains blocked with exact owner-input reasons.
6. Backups are created to the configured owner path and restored in rehearsal.
7. Public RPC has TLS, CORS, rate limiting, method allowlist, health checks,
   abuse tests, monitoring, and rollback proof.
8. External tester packet is generated only when it is safe to share.
9. Security, load, fuzz, no-secret, and unsafe-claim audits pass.
10. Installer, upgrade, rollback, and incident runbooks are proven.
11. Completion audit reports `ready` from fresh evidence and no blocked or
    failed production gates remain.

If any item above is missing, the correct status is not complete.
