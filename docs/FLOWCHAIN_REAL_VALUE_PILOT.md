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

Current `main` after PR #145 merged at
`91b4d5d033857f1d10526912d852d13ff2e86a23`:

- `npm run flowchain:product-e2e` exists as the local product testnet gate.
- `npm run flowchain:full-smoke` exists as the private/local L1 baseline gate.
- `npm run flowchain:l1-e2e` exists as the current L1 baseline alias to
  `flowchain:full-smoke`; it can be tightened by the ops branch when the
  dedicated L1 wrapper is merged.
- `npm run flowchain:real-value-pilot:e2e` exists as the final pilot
  gate. It fails by default while required subsystem proof commands are missing.
- `npm run flowchain:real-value-pilot:control-dashboard` exists on `main`
  after PR #142 merged.
- `npm run flowchain:real-value-pilot:wallet` exists on `main` after PR
  #143 merged.
- `npm run flowchain:real-value-pilot:ops` exists on `main` after PR #144
  merged.
- `npm run flowchain:real-value-pilot:bridge` exists on `main` after PR #145
  merged.

GitHub source-of-truth state checked for this pass:

- Draft PR #129 adds the copy-ready real-value pilot goal pack.
- Issue #130 is closed; PR #132 merged the capped owner-pilot release-gate
  boundary.
- Issue #131 is closed; PR #132 merged the optional-Slither default hardening
  policy while keeping `contracts:hardening:slither` as the explicit audit gate.
- Issue #137 is closed; PR #142 merged the control-plane/dashboard pilot
  proof command.
- Issue #136 is closed; PR #143 merged the wallet/operator pilot proof
  command.
- Issue #135 is closed; PR #144 merged the ops/installer pilot proof command.
- Issue #138 is closed; PR #145 merged the bridge relayer pilot proof command.
- Issues #133 and #134 remain the open subsystem proof blockers for strict
  pilot-gate pass.

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

## Ops Command Surface

The ops proof command exists on `main` after PR #144:

```powershell
npm run flowchain:real-value-pilot:ops
```

It verifies that the owner-pilot scripts parse, dry-run mode needs no live RPC
URL or private key, live mode refuses missing acknowledgement/env values,
emergency stop prints the pause recovery command, and evidence export excludes
secret-shaped files.

Live owner actions require explicit local shell env vars and are not run by the
proof command. The command surface is:

```powershell
npm run flowchain:real-value-pilot -- --Mode Live --Action Deploy
npm run flowchain:real-value-pilot -- --Mode Live --Action Deploy -Execute
npm run flowchain:real-value-pilot -- --Mode Live --Action Observe
npm run flowchain:real-value-pilot -- --Mode Live --Action Credit
npm run flowchain:real-value-pilot -- --Mode Live --Action Withdraw
npm run flowchain:real-value-pilot:emergency-stop
npm run flowchain:real-value-pilot -- --Mode Live --Action Resume -Execute
npm run flowchain:real-value-pilot:export
npm run flowchain:real-value-pilot -- --Mode Live --Action Restart
```

Set live env vars only in a local shell or ignored env file. The minimum
operator acknowledgement is:

```powershell
$env:FLOWCHAIN_PILOT_OPERATOR_ACK="I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT"
```

The ops wrapper also requires action-specific Base `8453` RPC, lockbox,
owner/release/submitter/recipient, block range, and tiny cap env values before
any live action proceeds.

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
| L1 baseline gate remains green. | HQ/Ops | `npm run flowchain:l1-e2e` | Exists on `main` as current alias to `flowchain:full-smoke`; latest local main-equivalent run passed. |
| Base chain ID `8453` is verified before any live observer or deployment action. | Contracts + Bridge + Ops | `npm run flowchain:real-value-pilot:contracts`; `npm run flowchain:real-value-pilot:bridge`; `npm run flowchain:real-value-pilot:ops` | Contracts branch command added here; bridge and ops are merged. |
| Lockbox address is loaded from ignored local config or env, not hardcoded as a blanket endorsement. | Contracts + Ops | `npm run flowchain:real-value-pilot:contracts`; `npm run flowchain:real-value-pilot:ops` | Contracts branch command added here; ops is merged. |
| Per-deposit cap, total pilot cap, supported-asset allowlist, pause, release, recovery, and replay protection are covered by tests and dry-run deployment evidence. | Contracts | `npm run flowchain:real-value-pilot:contracts` | Branch command added here; local proof passes, pending PR merge. |
| Deposit observation writes deterministic observation, credit, and evidence files. | Bridge relayer | `npm run flowchain:real-value-pilot:bridge` | Merged on `main` by PR #145; latest local main-equivalent proof passed. |
| Duplicate Base event replay is rejected or idempotent with explicit evidence. | Bridge relayer + Chain runtime | `npm run flowchain:real-value-pilot:bridge`; `npm run flowchain:real-value-pilot:runtime` | Bridge proof is merged; runtime command still missing. |
| Local runtime applies each pilot bridge credit exactly once and preserves state across restart/export/import. | Chain runtime | `npm run flowchain:real-value-pilot:runtime` | Missing dedicated pilot command. |
| Operator wallet can sign pilot acknowledgements, withdrawal intents, release evidence, and emergency messages without committing secrets. | Wallet/operator | `npm run flowchain:real-value-pilot:wallet` | Merged on `main` by PR #143; latest local main-equivalent proof passed. |
| Wallet verification rejects wrong chain ID, wrong contract, wrong operator, mutated payload, replay nonce, expired message, and missing cap fields. | Wallet/operator | `npm run flowchain:real-value-pilot:wallet` | Merged on `main` by PR #143; latest local main-equivalent proof passed. |
| API exposes pilot status, observations, credits, withdrawal intents, release evidence, cap status, pause status, retry state, and emergency state. | Control plane/dashboard | `npm run flowchain:real-value-pilot:control-dashboard` | Merged on `main` by PR #142; latest local main-equivalent proof passed. |
| Dashboard labels the flow as capped owner testing and shows live/degraded/error state plus exact next operator commands. | Control plane/dashboard | `npm run flowchain:real-value-pilot:control-dashboard` | Merged on `main` by PR #142; latest local main-equivalent proof passed. |
| Browser stores no private keys or RPC credentials. | Control plane/dashboard + Wallet/operator | `npm run flowchain:real-value-pilot:control-dashboard`; `npm run flowchain:real-value-pilot:wallet` | Control-dashboard and wallet proofs are merged. |
| Ops path verifies required env, tiny caps, explicit owner ack, emergency stop, export evidence, restart recovery, and no-secret scans. | Ops/installer | `npm run flowchain:real-value-pilot:ops` | Merged on `main` by PR #144; latest local main-equivalent proof passed. |
| Final pilot gate runs baseline commands plus every available dedicated proof command. | HQ/Ops | `npm run flowchain:real-value-pilot:e2e` | Exists on `main`; strict mode still fails until subsystem commands land. |

## In-Flight Implementation Status

This HQ branch has inspected the active pilot worktrees and found branch-local
work that can feed future merges. None of the rows below is enough to mark the
owner pilot `go`, because the final proof commands still need to exist and pass
from `main`.

| Area | In-flight branch state | Required next step |
| --- | --- | --- |
| Contracts | This branch adapts `agent/real-value-pilot-contracts` work onto `91b4d5d` and exposes branch-local `flowchain:real-value-pilot:contracts`. | Open a PR for issue #133 so the proof command lands on `main`. |
| Bridge relayer | `flowchain:real-value-pilot:bridge` merged on `main` through PR #145 and closed issue #138. | No bridge relayer blocker remains for the final pilot gate. |
| Chain runtime | `agent/real-value-pilot-chain` checklist reports runtime credit/replay/restart/export proof complete through the direct wrapper; root package command is missing. | Rebase onto `91b4d5d`, expose `flowchain:real-value-pilot:runtime`, rerun evidence, and open a PR. |
| Wallet/operator | `flowchain:real-value-pilot:wallet` merged on `main` through PR #143 and closed issue #136. | No wallet/operator blocker remains for the final pilot gate. |
| Control plane/dashboard | `flowchain:real-value-pilot:control-dashboard` merged on `main` through PR #142 and closed issue #137. | No control-dashboard blocker remains for the final pilot gate. |
| Ops/installer | `flowchain:real-value-pilot:ops` merged on `main` through PR #144 and closed issue #135. | No ops/installer blocker remains for the final pilot gate. |

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

- Dedicated real-value contracts gate exists branch-locally and passes; tracked by issue #133 until merged.
- Dedicated real-value bridge relayer gate is merged on `main`; issue #138 is closed by PR #145.
- Dedicated real-value runtime gate does not exist; tracked by issue #134.
- Dedicated real-value wallet/operator gate is merged on `main`; issue #136 is closed by PR #143.
- Dedicated real-value control-plane/dashboard gate is merged on `main`; issue #137 is closed by PR #142.
- Dedicated real-value ops/installer gate is merged on `main`; issue #135 is closed by PR #144.
- Issue #130 is closed by PR #132; the release-gate boundary is now on `main`.
- Issue #131 is closed by PR #132; default `contracts:hardening` skips optional
  Slither unless the audit gate is explicitly requested.
- HQ posted refresh comments on issues #133 through #138 with the latest local
  worktree evidence and next integration actions.

## Tracking Issues

| Area | Issue | Required command |
| --- | --- | --- |
| Contracts | #133 | `npm run flowchain:real-value-pilot:contracts` |
| Bridge relayer | #138, closed by PR #145 | `npm run flowchain:real-value-pilot:bridge` |
| Chain runtime | #134 | `npm run flowchain:real-value-pilot:runtime` |
| Wallet/operator | #136, closed by PR #143 | `npm run flowchain:real-value-pilot:wallet` |
| Control plane/dashboard | #137, closed by PR #142 | `npm run flowchain:real-value-pilot:control-dashboard` |
| Ops/installer | #135, closed by PR #144 | `npm run flowchain:real-value-pilot:ops` |
| Release-gate boundary | #130, closed by PR #132 | `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` until proofs land |
| Static-analysis policy | #131, closed by PR #132 | `npm run contracts:hardening`; `npm run contracts:hardening:slither` |

## Required PR Evidence

Every real-value pilot PR must include:

- linked issue or explicit HQ assignment;
- allowed and forbidden folders;
- exact worktree and branch;
- commands run and report paths;
- missing blockers, owner, and next action;
- explicit statement that public launch, open-validator readiness, tokenomics,
  broad bridge readiness, and custody claims remain out of scope.
