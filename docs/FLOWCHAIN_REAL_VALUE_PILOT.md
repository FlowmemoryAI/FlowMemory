# FlowChain Real-Value Pilot

Status: HQ coordination spec for a capped owner pilot.

Last updated: 2026-05-14.

## Purpose

The FlowChain real-value pilot is a capped owner-only bridge validation path
that builds on the current local FlowChain product testnet and L1 baseline.
It is meant to prove a tiny supported-asset deposit on Base public network
chain ID `8453` can be observed, converted into a deterministic local credit,
shown to the owner, and recovered or stopped with explicit evidence.

This is not a public launch, not open-validator readiness, not tokenomics, not
a broad bridge readiness claim, and not a custody claim. It stays blocked until
the proof rows below have owning agents, commands, evidence, and owner go/no-go
approval.

## Current Baseline

Current `main` at the start of this HQ pass:

- `npm run flowchain:product-e2e` exists as the local product testnet gate.
- `npm run flowchain:full-smoke` exists as the private/local L1 baseline gate.
- `npm run flowchain:l1-e2e` is added here as the current L1 baseline alias to
  `flowchain:full-smoke`; it can be tightened by the ops branch when the
  dedicated L1 wrapper is merged.
- `npm run flowchain:real-value-pilot:e2e` is added here as the final pilot
  gate. It fails by default while required subsystem proof commands are missing.

GitHub source-of-truth state checked for this pass:

- Draft PR #129 adds the copy-ready real-value pilot goal pack.
- Issue #130 defines the required gate work before public-network pilot work.
- Open PRs #110, #112 through #117, #71, and #73 remain useful context only
  until merged.

## Final Gate

Run the pilot gate from the repo root:

```powershell
npm run flowchain:real-value-pilot:e2e
```

During coordination, run the same gate in report-only mode:

```powershell
npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete
```

The script writes:

```text
devnet/local/real-value-pilot/flowchain-real-value-pilot-e2e-report.json
```

The report must show `status: "passed"` before the owner can mark the capped
pilot go. Until then, missing proof rows are blockers, not warnings.

## Release-Gate Boundary

This section is the issue #130 boundary for real-value pilot PRs. It does not
approve live operation by itself; it defines the minimum evidence that must be
present before a PR may claim a capped owner-pilot step is ready.

| Activity | Merge requirement before claiming ready | Approval owner |
| --- | --- | --- |
| Base public-network observer reads. | Observer command verifies `eth_chainId == 0x2105`, rejects broad ranges, rejects unapproved lockbox addresses, records confirmation depth, and writes no-secret evidence. | Bridge + Ops + HQ |
| Supported-asset deposit. | Contracts prove allowlist, per-deposit cap, total pilot cap, pause, replay, and deterministic event inputs; ops proves tiny nonzero cap env and exact owner acknowledgement. | Contracts + Ops + Owner |
| Bridge release or recovery path. | Contracts prove authorized release/recovery and replay blocking; wallet proves signed release evidence; ops proves emergency stop and revoke/recovery command path. | Contracts + Wallet + Ops + Owner |
| Local credit application. | Runtime proves each pilot credit applies exactly once, duplicate replay is rejected or idempotent with evidence, and restart/export/import preserve deterministic roots. | Chain runtime + Bridge |
| Control-plane and dashboard display. | API/dashboard prove capped owner labels, live/degraded/error state, exact next command, redaction, and no browser secret storage. | Control plane/dashboard + Wallet |
| Token launch, tokenomics, broad DEX liquidity, or open swap claims. | Out of scope for the capped owner pilot. A separate accepted issue, docs update, threat model, and owner approval are required before any PR may make these claims. | Owner + HQ + Security |
| Open validators, public L1/mainnet readiness, audited cryptography, or production bridge custody. | Out of scope for this pilot. A separate production-readiness review, security review, and accepted release plan are required before any PR may make these claims. | Owner + HQ + Security |

Every PR touching a pilot proof row must list the exact issue, allowed folders,
forbidden folders, commands run, report paths, unresolved blockers, and whether
the proof is branch-local or verified from `main`.

## Integration Matrix

| Required proof | Owning agent | Required command | Current state |
| --- | --- | --- | --- |
| Existing product testnet gate remains green. | HQ/Ops | `npm run flowchain:product-e2e` | Existing command; run before PR when practical. |
| L1 baseline gate remains green. | HQ/Ops | `npm run flowchain:l1-e2e` | Added as current alias to `flowchain:full-smoke`. |
| Base chain ID `8453` is verified before any live observer or deployment action. | Contracts + Bridge + Ops | `npm run flowchain:real-value-pilot:contracts`; `npm run flowchain:real-value-pilot:bridge`; `npm run flowchain:real-value-pilot:ops` | Missing dedicated pilot commands. |
| Lockbox address is loaded from ignored local config or env, not hardcoded as a blanket endorsement. | Contracts + Ops | `npm run flowchain:real-value-pilot:contracts`; `npm run flowchain:real-value-pilot:ops` | Missing dedicated pilot commands. |
| Per-deposit cap, total pilot cap, supported-asset allowlist, pause, release, recovery, and replay protection are covered by tests and dry-run deployment evidence. | Contracts | `npm run flowchain:real-value-pilot:contracts` | Missing dedicated pilot command. |
| Deposit observation writes deterministic observation, credit, and evidence files. | Bridge relayer | `npm run flowchain:real-value-pilot:bridge` | Missing dedicated pilot command. |
| Duplicate Base event replay is rejected or idempotent with explicit evidence. | Bridge relayer + Chain runtime | `npm run flowchain:real-value-pilot:bridge`; `npm run flowchain:real-value-pilot:runtime` | Missing dedicated pilot commands. |
| Local runtime applies each pilot bridge credit exactly once and preserves state across restart/export/import. | Chain runtime | `npm run flowchain:real-value-pilot:runtime` | Missing dedicated pilot command. |
| Operator wallet can sign pilot acknowledgements, withdrawal intents, release evidence, and emergency messages without committing secrets. | Wallet/operator | `npm run flowchain:real-value-pilot:wallet` | Missing dedicated pilot command. |
| Wallet verification rejects wrong chain ID, wrong contract, wrong operator, mutated payload, replay nonce, expired message, and missing cap fields. | Wallet/operator | `npm run flowchain:real-value-pilot:wallet` | Missing dedicated pilot command. |
| API exposes pilot status, observations, credits, withdrawal intents, release evidence, cap status, pause status, retry state, and emergency state. | Control plane/dashboard | `npm run flowchain:real-value-pilot:control-dashboard` | Missing dedicated pilot command. |
| Dashboard labels the flow as capped owner testing and shows live/degraded/error state plus exact next operator commands. | Control plane/dashboard | `npm run flowchain:real-value-pilot:control-dashboard` | Missing dedicated pilot command. |
| Browser stores no private keys or RPC credentials. | Control plane/dashboard + Wallet/operator | `npm run flowchain:real-value-pilot:control-dashboard`; `npm run flowchain:real-value-pilot:wallet` | Missing dedicated pilot commands. |
| Ops path verifies required env, tiny caps, explicit owner ack, emergency stop, export evidence, restart recovery, and no-secret scans. | Ops/installer | `npm run flowchain:real-value-pilot:ops` | Missing dedicated pilot command. |
| Final pilot gate runs baseline commands plus every available dedicated proof command. | HQ/Ops | `npm run flowchain:real-value-pilot:e2e` | Added here; expected incomplete until subsystem commands land. |

## In-Flight Implementation Status

This HQ branch has inspected the active pilot worktrees and found branch-local
work that can feed future merges. None of the rows below is enough to mark the
owner pilot `go`, because the final proof commands still need to exist and pass
from `main`.

| Area | In-flight branch state | Required next step |
| --- | --- | --- |
| Contracts | `agent/real-value-pilot-contracts` reports passing contract tests, hardening, deploy dry-run, and product E2E after dependency install. | Merge reviewed contract work and expose a dedicated root pilot contracts proof command. |
| Bridge relayer | `agent/real-value-pilot-bridge` contains Base `8453` observer and mock pilot E2E work, with verification rows still pending. | Finish bridge verification, then expose a dedicated root bridge proof command. |
| Chain runtime | `agent/real-value-pilot-chain` contains bridge-credit runtime work in progress, with current pilot experiments still pending. | Finish runtime apply/replay/restart/export proof, then expose a dedicated root runtime proof command. |
| Wallet/operator | `agent/real-value-pilot-wallet` contains pilot signing, validation, schema, and operator-doc work with test rows still pending. | Finish wallet negative vectors and public metadata checks, then expose a dedicated root wallet proof command. |
| Control plane/dashboard | `agent/real-value-pilot-control-dashboard` contains pilot API/dashboard work and a service-local E2E, with checklist rows still incomplete. | Finish API/dashboard verification, then expose a dedicated root control-dashboard proof command. |
| Ops/installer | `agent/real-value-pilot-ops` contains root pilot wrappers, emergency stop, sanitized export, and a passing local checklist after an ops-side static-analysis wrapper change. | Reconcile product E2E hardening policy and merge a reviewed ops proof command. |

## Owner Go/No-Go Checklist

The owner should mark the pilot `go` only when all rows are true:

- [ ] `npm run flowchain:product-e2e` passes from a clean `main` checkout.
- [ ] `npm run flowchain:l1-e2e` passes from the same checkout.
- [ ] `npm run flowchain:real-value-pilot:e2e` passes without `-AllowIncomplete`.
- [ ] The pilot report has empty `missingProofs` and no failed command results.
- [ ] Base chain ID `8453` is verified in the live observer path.
- [ ] Per-deposit and total pilot caps are tiny, nonzero, enforced, and recorded.
- [ ] Supported asset and lockbox address are read from explicit local config or env.
- [ ] Pause, emergency stop, revoke, release, restart, and export evidence are tested.
- [ ] Replay and duplicate-event behavior has deterministic evidence.
- [ ] No committed file, report, export, local route, or dashboard payload contains
  a private key, seed phrase, mnemonic, RPC credential, API key, or webhook.
- [ ] The owner has reviewed the exact commands and expected loss boundary for
  the tiny capped test amount.
- [ ] A rollback/recovery note names the first command to run if the bridge,
  relayer, runtime, wallet, control plane, or dashboard enters a degraded state.

Mark the pilot `no-go` if any row is missing, if any command requires secrets
in committed files, or if any document presents the pilot as public readiness.

## Current Blockers

- Dedicated real-value contracts gate does not exist.
- Dedicated real-value bridge relayer gate does not exist.
- Dedicated real-value runtime gate does not exist.
- Dedicated real-value wallet/operator gate does not exist.
- Dedicated real-value control-plane/dashboard gate does not exist.
- Dedicated real-value ops/installer gate does not exist.
- GitHub issue #130 must define and be accepted as the release-gate boundary before
  any owner pilot work is treated as more than capped validation.
- GitHub issue #131 has a branch-local policy fix in this HQ PR: default
  `contracts:hardening` skips optional Slither unless the audit gate is
  explicitly requested. The issue remains open until the fix is reviewed and
  merged.

## Required PR Evidence

Every real-value pilot PR must include:

- linked issue or explicit HQ assignment;
- allowed and forbidden folders;
- exact worktree and branch;
- commands run and report paths;
- missing blockers, owner, and next action;
- explicit statement that public launch, open-validator readiness, tokenomics,
  broad bridge readiness, and custody claims remain out of scope.
