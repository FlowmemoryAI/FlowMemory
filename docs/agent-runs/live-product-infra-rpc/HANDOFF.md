# FlowChain Live Infra RPC Handoff

Generated: 2026-05-16T00:45Z
Worktree: `E:\FlowMemory\flowmemory-live-infra-rpc`
Branch: `agent/live-product-infra-rpc`

## Current Status

The live infrastructure goal is active and the local service path is running.

- `npm run flowchain:service:restart -- -LiveProfile` restarted the node/control-plane service path with `MaxBlocks=0`.
- `npm run flowchain:service:status` passed after service start.
- `npm run flowchain:live-infra:check` now starts with the owner input contract and is blocked only by owner-provided public RPC, backup, and Base 8453 bridge inputs.
- `npm run flowchain:live-product:e2e` exits cleanly as `blocked` instead of hanging; it runs the production-shaped local aggregate, restores the live service profile, runs a live-service wallet transfer, runs a four-tester isolated-wallet network probe, and then runs live-infra readiness.
- `npm run flowchain:production-l1:e2e` passed the mock/local path and ended as `passed-with-live-blockers`.
- `npm run flowchain:wallet:live-service:e2e` passed against the running RPC service; `/wallets/send` queued through the live node inbox and the node applied the transfer in produced blocks.
- `npm run flowchain:wallet:live-tester:e2e` passed against the running RPC service; four isolated tester wallets were created through `/wallets/create`, funded, transferred in a ring, and settled on produced blocks.
- `npm run flowchain:tester:readiness -- -AllowBlocked` wrote a fail-closed external tester readiness report; it now refreshes service/live-infra status, requires a fresh live tester-wallet network proof, keeps local tester rehearsal ready, and blocks external sharing until owner public RPC/backup/Base env names are configured.
- `npm run flowchain:owner-inputs:validate` passed the validator self-test: missing inputs block, invalid inputs fail, structurally valid dummy direct env values pass, and structurally valid dummy values loaded through `FLOWCHAIN_OWNER_ENV_FILE` pass without values in reports.
- `npm run flowchain:owner-inputs:validate` also now proves missing and malformed `FLOWCHAIN_OWNER_ENV_FILE` fail closed with `FLOWCHAIN_OWNER_ENV_FILE` named and no values printed.
- `npm run flowchain:owner-inputs -- -AllowBlocked` wrote a no-values owner input contract report for the exact public RPC, backup, and Base 8453 bridge env names.
- `npm run flowchain:owner:onboarding` wrote a no-values onboarding packet that clarifies FlowChain RPC is repo-owned, public RPC needs an owner HTTPS edge, Base 8453 RPC is only the external bridge-observer dependency, and owner values may be loaded from an ignored local `FLOWCHAIN_OWNER_ENV_FILE`.
- `npm run flowchain:owner:signup-checklist` wrote a no-values owner checklist for the exact signups/setup items needed to go public: public DNS, HTTPS tunnel/reverse proxy, allowed origins/rate limit, always-on host, backup storage, Base 8453 RPC, bridge pilot values, and local owner env-file loading.
- `npm run flowchain:public-rpc:edge-template` wrote a no-values Nginx edge template for HTTPS reverse proxying, rate limiting, forwarding browser Origin headers, and forwarding an edge-confirmed client address to the repo-owned private RPC origin.
- `npm run flowchain:public-rpc:validate` passed a temporary local control-plane rehearsal of the public RPC readiness script, including endpoint checks, allowed-origin acceptance, disallowed-origin rejection, bounded `429` rate-limit enforcement, retry-after evidence, and response hygiene.
- `npm run flowchain:external-tester:packet -- -AllowBlocked` wrote a tester packet that is explicitly not shareable while external gates are blocked.
- `npm run flowchain:owner-env:template` creates or preserves a placeholder-only local owner env scaffold at `devnet/local/owner-inputs/flowchain-owner.local.env` and proves the path is git-ignored before owner values are added.
- `npm run flowchain:owner-env:readiness:validate` proves missing owner env files and repo-local unignored env files fail before any child live gates run.
- `npm run flowchain:owner-env:readiness -- -AllowBlocked` points the live gates at that ignored owner env file, runs owner-input, live-infra, and public deployment checks, and blocks only on known owner env names without printing values.
- `npm run flowchain:public-deployment:contract -- -AllowBlocked` now refreshes its own dependency reports before deciding, writes redacted dependency-refresh evidence, and records a no-values owner deployment contract with pre-exposure commands, rollback commands, and a not-shareable decision until public RPC, backup, bridge, and tester gates pass; latest contract result is 9 passed, 5 blocked, 0 failed.
- `npm run flowchain:architecture:audit -- -AllowBlocked` wrote a code-backed architecture audit for runtime, RPC, public edge template, wallets, bridge, backup, operations, owner onboarding, verification, owner env readiness, and fail-closed owner boundaries; latest result is 11 passed, 5 blocked, 0 failed.
- `npm run flowchain:completion:audit -- -AllowBlocked` wrote the full prompt-to-artifact completion audit; latest result is 20 requirements passed, 7 blocked, 0 failed.
- The completion audit now refreshes `npm run flowchain:live-infra:check -- -AllowBlocked` before it reads live-infra evidence, so stale infra reports cannot satisfy the final audit.
- The completion audit now reruns `npm run flowchain:wallet:live-service:e2e` and `npm run flowchain:wallet:live-tester:e2e` before it reads wallet evidence, so wallet-create/send readiness is proven during the audit itself.
- The completion audit now reruns `npm run flowchain:real-value-pilot:bridge` before it reads local bridge-pilot evidence, so the no-broadcast and negative bridge checks are current.
- The completion audit now reruns `npm run flowchain:bridge:diagnose:tx` and treats missing owner tx/env inputs as a passing fail-closed safety result only when the report proves no broadcast, no env-value output, and no secrets.
- The completion audit now reruns `npm run flowchain:live-product:e2e -- -AllowBlocked` before it samples service status and child gates, so the aggregate-gate row cannot rely on a stale live-product report.
- The completion audit now reruns `npm run flowchain:owner-env:readiness -- -AllowBlocked` before deciding readiness, so the local owner env-file path is tested through owner-input, live-infra, and public deployment gates.
- The completion audit now invokes `npm run flowchain:public-deployment:contract -- -AllowBlocked -NoRefresh` only after it refreshes the contract's child dependencies itself; the contract has 0 failed items, explicit rollback commands, and a not-shareable external decision while owner inputs are absent.
- The completion audit now reruns `npm run flowchain:architecture:audit -- -AllowBlocked` and records the system-architecture gate; the architecture audit passed its safety criteria with 0 failed items while public RPC, live bridge, and backup remain blocked on owner inputs.
- The live-product aggregate now preserves child report statuses directly; expected owner-input blockers appear as `blocked`, not ambiguous `blocked-or-failed`.
- `account_list` now prioritizes explicit wallet public metadata over accumulated passive local-balance projections, so standalone wallet metadata remains visible on the default page as the live runtime grows.
- Bridge infra readiness now verifies that the read-only owner-supplied Base tx diagnostic command is discoverable: `npm run flowchain:bridge:diagnose:tx`.
- `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE` is enforced by the control-plane server when configured; tests verify JSON `429` without env-name echo and prove spoofed first-hop `X-Forwarded-For` values do not bypass the per-client bucket.
- Public RPC readiness now probes CORS allowed-origin acceptance, disallowed-origin rejection, and bounded rate-limit rejection.
- Control-plane cargo execution now resolves an installed rustup toolchain without requiring a global default, uses a stable warmed target directory for live control-plane runtime submissions, and avoids first wallet-send request timeouts after service restart.
- Runtime local test-unit transfers now validate the destination account and overflow path before debiting the sender; regression coverage proves missing-recipient rejections do not mutate sender balances, and CLI submit-tx coverage proves multi-transaction inbox batches preserve create-recipient-before-transfer order.
- `/rpc/readiness` now fails closed on malformed public RPC URL, wildcard public CORS, invalid rate-limit values, and missing TLS acknowledgement without printing env values.
- Control-plane service management now rejects/reports a port-8787 process unless it was launched from this worktree.
- `/chain/status`, `/state`, `block_get`, and `block_list` now expose the active local runtime block stream from `devnet/local/state.json`.
- `npm run flowchain:service:monitor` now records at least two service-status samples and fails if the node/control-plane stop, state goes stale, or height stops advancing.
- Windows service/runtime hardening is in place for transient atomic state-file replacement errors, cargo temp paths, direct node stop markers, and stale pid command-line checks.
- Bridge pilot negative coverage now verifies wrong-source and unapproved-lockbox credits are rejected without creating applied runtime bridge records.
- No live Base transaction was broadcast.
- No private keys, seed phrases, mnemonics, RPC URLs, API keys, webhooks, env values, or vault contents were printed or committed.

## Owner Signup Needs

FlowChain RPC is implemented by this repository. Do not sign up for a third-party FlowChain RPC provider. Public RPC means putting an owner-operated HTTPS edge in front of the private origin `127.0.0.1:8787`.

What the owner needs to get or decide:

- Public RPC domain or subdomain for `FLOWCHAIN_RPC_PUBLIC_URL`.
- HTTPS tunnel or reverse proxy to the private RPC origin for `FLOWCHAIN_RPC_TLS_TERMINATED`.
- Exact allowed wallet/app origins and a positive per-minute public rate limit for `FLOWCHAIN_RPC_ALLOWED_ORIGINS` and `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`.
- Always-on host that can keep the node/control-plane service running.
- Writable persistent backup path for `FLOWCHAIN_RPC_STATE_BACKUP_PATH`.
- Base mainnet chain 8453 RPC endpoint for `FLOWCHAIN_BASE8453_RPC_URL`.
- Bridge pilot lockbox/token/block-range/cap/confirmation values for `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`, `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`, `FLOWCHAIN_BASE8453_TO_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`, `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, and `FLOWCHAIN_PILOT_CONFIRMATIONS`.
- Optional ignored local owner env file path for `FLOWCHAIN_OWNER_ENV_FILE`; `npm run flowchain:owner-env:template` creates the default scaffold at `devnet/local/owner-inputs/flowchain-owner.local.env`, `npm run flowchain:owner-env:readiness:validate` proves unsafe paths fail closed, and `npm run flowchain:owner-env:readiness -- -AllowBlocked` validates that file against the live gates. Put values there or in the service environment, not in chat or committed files.

Do not send registrar passwords, cloud dashboard passwords, tunnel tokens, TLS private keys, provider API keys, secret-bearing RPC URLs, private keys, wallet recovery material, or env-file contents in chat.

## Running Local Services

Latest observed service status:

- FlowChain node: running, PID `48108`
- Control plane: running, PID `55704`, bound to `127.0.0.1:8787`
- Latest observed service-status height: `25328`
- Latest observed external tester readiness height: `25272`
- Latest observed completion-audit height: `25272`
- Finalized height: `25328`
- Dashboard URL reported by production E2E: `http://127.0.0.1:5173/`
- Data directory: `E:\FlowMemory\flowmemory-live-infra-rpc\devnet\local`

Useful commands:

```powershell
npm run flowchain:service:status
npm run flowchain:service:stop
npm run flowchain:service:restart
npm run flowchain:emergency:stop-local
```

## Reports

- Live infra aggregate: `docs/agent-runs/live-product-infra-rpc/flowchain-live-infra-check-report.json`
- Live product aggregate: `docs/agent-runs/live-product-infra-rpc/flowchain-live-product-e2e-report.json`
- Public RPC readiness: `docs/agent-runs/live-product-infra-rpc/public-rpc-readiness-report.json`
- Public RPC edge template: `docs/agent-runs/live-product-infra-rpc/public-rpc-edge-template-report.json`
- Public RPC edge template markdown: `docs/agent-runs/live-product-infra-rpc/PUBLIC_RPC_EDGE_TEMPLATE.md`
- Public RPC validation: `docs/agent-runs/live-product-infra-rpc/public-rpc-validation-report.json`
- Service status: `docs/agent-runs/live-product-infra-rpc/service-status-report.json`
- Service monitor: `docs/agent-runs/live-product-infra-rpc/service-monitor-report.json`
- Live-service wallet transfer: `docs/agent-runs/live-product-infra-rpc/live-service-wallet-e2e-report.json`
- Live-service tester network: `docs/agent-runs/live-product-infra-rpc/live-service-tester-network-e2e-report.json`
- External tester readiness: `docs/agent-runs/live-product-infra-rpc/external-tester-readiness-report.json`
- Owner input validator self-test: `docs/agent-runs/live-product-infra-rpc/owner-inputs-validation-report.json`
- Owner inputs: `docs/agent-runs/live-product-infra-rpc/owner-inputs-report.json`
- Owner inputs markdown: `docs/agent-runs/live-product-infra-rpc/OWNER_INPUTS.md`
- Owner onboarding report: `docs/agent-runs/live-product-infra-rpc/owner-onboarding-report.json`
- Owner onboarding markdown: `docs/agent-runs/live-product-infra-rpc/OWNER_ONBOARDING.md`
- Owner signup checklist report: `docs/agent-runs/live-product-infra-rpc/owner-signup-checklist-report.json`
- Owner signup checklist markdown: `docs/agent-runs/live-product-infra-rpc/OWNER_SIGNUP_CHECKLIST.md`
- Owner env template report: `docs/agent-runs/live-product-infra-rpc/owner-env-template-report.json`
- Owner env template markdown: `docs/agent-runs/live-product-infra-rpc/OWNER_ENV_TEMPLATE.md`
- Owner env readiness validation report: `docs/agent-runs/live-product-infra-rpc/owner-env-readiness-validation-report.json`
- Owner env readiness report: `docs/agent-runs/live-product-infra-rpc/owner-env-readiness-report.json`
- Owner env readiness markdown: `docs/agent-runs/live-product-infra-rpc/OWNER_ENV_READINESS.md`
- External tester packet report: `docs/agent-runs/live-product-infra-rpc/external-tester-packet-report.json`
- External tester packet markdown: `docs/agent-runs/live-product-infra-rpc/EXTERNAL_TESTER_PACKET.md`
- Public deployment contract: `docs/agent-runs/live-product-infra-rpc/public-deployment-contract-report.json`
- Public deployment contract markdown: `docs/agent-runs/live-product-infra-rpc/PUBLIC_DEPLOYMENT_CONTRACT.md`
- Architecture audit: `docs/agent-runs/live-product-infra-rpc/flowchain-architecture-audit-report.json`
- Architecture audit markdown: `docs/agent-runs/live-product-infra-rpc/ARCHITECTURE_AUDIT.md`
- Completion audit: `docs/agent-runs/live-product-infra-rpc/flowchain-completion-audit-report.json`
- Completion audit markdown: `docs/agent-runs/live-product-infra-rpc/COMPLETION_AUDIT.md`
- Base tx diagnostic: `devnet/local/live-l1-bridge-e2e/base-tx-diagnostic.json`
- Backup readiness: `docs/agent-runs/live-product-infra-rpc/backup-readiness-report.json`
- Bridge infra readiness: `docs/agent-runs/live-product-infra-rpc/bridge-infra-readiness-report.json`
- Bridge live readiness: `docs/agent-runs/live-product-infra-rpc/bridge-live-readiness-report.json`
- Local/mock production-shaped E2E: `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json`
- Evidence bundle: `devnet/local/production-l1-e2e/evidence/flowchain-production-l1-evidence.zip`

## Verified Commands

```powershell
npm run flowchain:doctor
npm run flowchain:node:status
npm run flowchain:rpc:e2e
npm run flowchain:wallet:e2e
npm run flowchain:wallet:transfer:e2e
npm run flowchain:wallet:live-service:e2e
npm run flowchain:wallet:live-tester:e2e
npm run flowchain:tester:readiness -- -AllowBlocked
npm run flowchain:owner:onboarding
npm run flowchain:owner:signup-checklist
npm run flowchain:owner-env:template
npm run flowchain:owner-env:readiness:validate
npm run flowchain:owner-env:readiness -- -AllowBlocked
npm run flowchain:owner-inputs:validate
npm run flowchain:owner-inputs -- -AllowBlocked
npm run flowchain:public-rpc:edge-template
npm run flowchain:public-rpc:validate
npm run flowchain:external-tester:packet -- -AllowBlocked
npm run flowchain:public-deployment:contract -- -AllowBlocked
npm run flowchain:architecture:audit -- -AllowBlocked
npm run flowchain:completion:audit -- -AllowBlocked
npm test --prefix services/control-plane
npm run flowchain:control-plane:smoke
npm run flowchain:bridge:live:check
npm run flowchain:real-value-pilot:bridge
npm run flowchain:service:start -- -LiveProfile
npm run flowchain:service:status
npm run flowchain:service:monitor -- -DurationSeconds 20 -PollSeconds 5 -MaxStateAgeSeconds 90
npm run flowchain:live-infra:check
npm run flowchain:live-product:e2e
npm run flowchain:production-l1:e2e
npm run flowchain:no-secret:scan
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Results:

- Control-plane tests: passed after audit hardening; 32 tests passed, including active runtime block status/list/get, configured CORS rejection, per-client rate-limit coverage, spoofed-forwarded-client hardening, repo-contained cargo target checks, and cargo-backed runtime submission without a rustup default.
- Bridge-relayer tests: passed after diagnostic readiness update; 23 tests passed, including Base 8453 tx diagnosis, wrong-chain rejection, unapproved-lockbox rejection, cap checks, and no-secret bridge artifacts.
- Control-plane smoke: passed.
- Public RPC readiness local-config rehearsal: blocked, not failed; chain checks passed while blocks were moving; allowed/disallowed CORS and bounded rate-limit probes passed; CORS header values were not printed.
- Control-plane CORS enforcement: `FLOWCHAIN_RPC_ALLOWED_ORIGINS` is honored by the server when configured; disallowed browser origins receive `403`.
- Service stop hardening: pid files are rechecked against expected FlowChain command lines before any process is terminated.
- Local RPC E2E: passed.
- Wallet create/sign/submit E2E: passed; local wallet proof stayed public-only and did not export secret material.
- Wallet-to-wallet transfer E2E: passed; transfer included in block `0xcc36dd0a25006afe94f6e26c3c55d3fb4f858dd56f15ed0008d4dad4fbaf4b75`.
- Live-service wallet transfer E2E: passed during the latest completion audit; generated `2026-05-16T00:33:24.5259958Z`, chain advanced from block `25061` to `25081`, and balances settled at `75/25`.
- Live-service tester network E2E: passed during the latest completion audit; generated `2026-05-16T00:34:50.8670505Z`; four isolated tester wallets were created with `secretMaterialReturned=false`, chain advanced from block `25088` to `25111`, and balances settled at `108/98/96/98`.
- External tester readiness: blocked as expected; generated `2026-05-16T00:43:21.0996378Z`; local tester rehearsal ready, tester-wallet evidence fresh, external sharing false until public RPC/backup/Base env names are configured.
- Owner input validator self-test: passed; missing, invalid, valid-structure/direct-env, valid-owner-env-file, missing-owner-env-file, and malformed-owner-env-file scenarios behaved as expected, and no env values were printed.
- Owner inputs: blocked as expected; exact env names are listed without values in `OWNER_INPUTS.md`.
- Owner onboarding: passed; `OWNER_ONBOARDING.md` states FlowChain RPC is repo-owned, a third-party FlowChain RPC provider is not needed, public RPC needs an owner HTTPS edge, Base 8453 RPC is a separate bridge-observer dependency, and `FLOWCHAIN_OWNER_ENV_FILE` can point at an ignored local `NAME=value` file.
- Owner signup checklist: passed; `OWNER_SIGNUP_CHECKLIST.md` lists the public DNS, HTTPS edge, allowed origins/rate limit, always-on host, backup storage, Base 8453 RPC, bridge pilot values, and local owner env-file setup needed to go public.
- Owner env template: passed; generated `2026-05-15T22:15:03.0697817Z`; `devnet/local/owner-inputs/flowchain-owner.local.env` is git-ignored and covers all 15 owner env names with empty assignments only.
- Owner env readiness validation: passed; generated `2026-05-15T22:13:14.7761465Z`; missing owner env files and repo-local unignored owner env files fail before child live gates run, with no values printed.
- Owner env readiness: blocked as expected; generated `2026-05-15T22:17:31.6017789Z`; `devnet/local/owner-inputs/flowchain-owner.local.env` is git-ignored, owner-input/live-infra/public-deployment gates run under one redacted command, and the only blockers are the 15 owner env names.
- Public RPC edge template: passed; generated `2026-05-15T23:11:02.5659063Z`; `PUBLIC_RPC_EDGE_TEMPLATE.md` provides a placeholder-only HTTPS reverse-proxy/rate-limit/CORS-origin-forwarding Nginx template for `127.0.0.1:8787` and sets `X-Forwarded-For` from the edge remote address.
- Public RPC validation: passed; generated `2026-05-16T00:39:14.8199390Z`; local rehearsal confirmed endpoint checks, allowed-origin acceptance, disallowed-origin rejection, bounded rate-limit rejection with retry-after, and response hygiene.
- External tester packet: blocked as expected; generated `2026-05-15T23:13:17.2664183Z`; `EXTERNAL_TESTER_PACKET.md` is generated but marked `Shareable externally: False`.
- Public deployment contract: blocked as expected; generated `2026-05-16T00:43:24.7047737Z`; 9 deployment gates passed, 5 were blocked, 0 failed, deployment ready `false`, packet shareable `false`, and `blockedOnlyOnKnownExternalOwnerInputs=true`.
- Architecture audit: blocked as expected; generated `2026-05-16T00:43:26.8898375Z`; 11 architecture boundaries passed, 5 were blocked, 0 failed, and `blockedOnlyOnKnownExternalOwnerInputs=true`.
- Completion audit: blocked as expected; generated `2026-05-16T00:43:28.0428635Z`; latest audit found 20 requirements passed, 7 blocked, 0 failed, completion ready `false`, latest audit height `25272`.
- Real-value pilot bridge mock coordination: passed during the latest completion audit; generated `2026-05-15T16:21:06.360Z`; no broadcast occurred; replay, wrong-chain, and unapproved-contract negative checks passed.
- Base tx diagnostic: failed closed as expected during the latest completion audit; generated `2026-05-15T16:21:07.285Z`; report status `blocked`, safe reason `missing-env`, `broadcasts=false`, `printsEnvValues=false`, `noSecrets=true`.
- Service status: passed after live-profile restore; latest observed node PID `48108`, control-plane PID `55704`, height `25328`.
- Service monitor: passed during the completion audit; sampled 2 times and height advanced from `25167` to `25174`.
- Live infra aggregate: blocked, not failed; owner input contract/public RPC/backup/bridge checks are blocked, service/no-secret passed, `blockedProcessNames` is empty, and invalid owner env count is `0`.
- Live product aggregate: blocked, not failed; generated `2026-05-16T00:31:11.4275054Z`; production local aggregate `passed-with-live-blockers`, live-service wallet transfer passed, live-service tester network passed, live infra `blocked`; 5 steps passed, 2 blocked, 0 failed.
- Production L1 E2E: passed-with-live-blockers.
- No-secret scan: passed.
- Unsafe-claim scan: passed.
- Whitespace check: passed.

## Remaining Owner Inputs

Public RPC / backup:

- `FLOWCHAIN_RPC_PUBLIC_URL`
- `FLOWCHAIN_RPC_ALLOWED_ORIGINS`
- `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`
- `FLOWCHAIN_RPC_TLS_TERMINATED`
- `FLOWCHAIN_RPC_STATE_BACKUP_PATH`

Base 8453 bridge:

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

## Next Resume Step

Keep the parent FlowChain L1 readiness loop active. If owner inputs are not available, continue integrating this workstream's reports back into the HQ readiness matrix and keep the local/mock production L1 path green. If owner inputs become available, rerun:

```powershell
npm run flowchain:live-infra:check
npm run flowchain:owner-inputs:validate
npm run flowchain:owner-inputs
npm run flowchain:public-rpc:validate
npm run flowchain:bridge:live:check
npm run flowchain:production-l1:e2e
npm run flowchain:external-tester:packet
npm run flowchain:live-product:e2e
```

Do not broadcast on Base unless the owner explicitly provides live env values and the required acknowledgement.
