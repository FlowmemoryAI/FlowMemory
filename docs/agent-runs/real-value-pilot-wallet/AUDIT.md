# Real-Value Pilot Wallet Completion Audit

Status: wallet/operator scope complete; required gates are now covered after
rebasing onto GitHub source-of-truth `origin/main` commit `c4959f8`.

## Objective

Build local operator/wallet support for the capped real-value pilot without
committing secrets and without browser-side private-key handling.

## Prompt-To-Artifact Checklist

| Requirement | Evidence | Status |
| --- | --- | --- |
| Inspect current crypto wallet CLI | Reviewed `crypto/src/wallet-cli.js`, `crypto/src/wallet.js`, `crypto/src/transactions.js`, and wallet scripts. | covered |
| Inspect active `E:\FlowMemory\flowmemory-crypto` long-loop work | Reviewed sibling branch status and wallet hardening files; notes recorded in `NOTES.md`. | covered |
| Inspect bridge relayer env/config needs | Reviewed `services/bridge-relayer/README.md` and `src/observe-base-lockbox.ts` read-only; no services edits. | covered |
| Maintain `PLAN.md` | `docs/agent-runs/real-value-pilot-wallet/PLAN.md`. | covered |
| Maintain `CHECKLIST.md` | `docs/agent-runs/real-value-pilot-wallet/CHECKLIST.md`. | covered |
| Maintain `EXPERIMENTS.md` | `docs/agent-runs/real-value-pilot-wallet/EXPERIMENTS.md`. | covered |
| Maintain `NOTES.md` | `docs/agent-runs/real-value-pilot-wallet/NOTES.md`. | covered |
| `npm test --prefix crypto` passes | Rerun passed: 23 tests. | covered |
| Existing product wallet smoke passes | `npm run wallet:product-smoke --prefix crypto` passed: 8 documents, 8 transactions, 9 negative transactions. | covered |
| New pilot wallet/operator E2E command exists and passes | `crypto/package.json` exposes `wallet:pilot-e2e`; rerun passed with 5 documents, 5 envelopes, 7 negative cases. | covered |
| Root pilot wallet/operator command exists and passes | Root `package.json` exposes `flowchain:real-value-pilot:wallet`, delegating to the crypto pilot E2E; rerun passed with 5 documents, 5 envelopes, 7 negative cases. | covered |
| Local operator config can be created from env without committing secrets | `wallet:pilot-config` creates `flowchain.real_value_pilot.operator_config.v0`; rerun produced only public config fields and next commands. Crypto tests now also reject unsupported chain id, malformed cap id, zero cap, used-over-max cap, closed cap window, secret-shaped local path, Base mainnet non-`USDC-6` cap, and Base mainnet cap above 25 USD before config export. | covered |
| Public metadata export excludes private keys, seed phrases, mnemonics, RPC credentials, API keys, and webhooks | `assertPublicPilotMetadataContainsNoSecrets`, E2E checks, operator docs, reviewed secret-pattern scan, and standalone `wallet:pilot-metadata` CLI run cover secret-shaped fields. Metadata export now also requires an active operator signer matching the pilot config, and a standalone mismatch CLI run verifies fail-closed behavior. | covered |
| Signing supports bridge credit acknowledgment | `buildPilotBridgeCreditAckDocument`, `pilotBridgeCreditAckId`, and E2E signed envelope. | covered |
| Signing supports withdrawal intent | `buildPilotWithdrawalIntentDocument`, `pilotWithdrawalIntentId`, and E2E signed envelope. | covered |
| Signing supports release evidence | `buildPilotReleaseEvidenceDocument`, `pilotReleaseEvidenceId`, E2E signed envelope, and standalone `wallet:pilot-sign`/`wallet:pilot-verify` CLI run. | covered |
| Signing supports emergency pause/revoke | `buildPilotEmergencyControlDocument`, `pilotEmergencyControlId`, and E2E signs both `pause` and `revoke`. | covered |
| Verification rejects wrong chain ID | `validatePilotOperatorEnvelope`; crypto test and pilot E2E negative case. | covered |
| Verification rejects wrong contract address | `validatePilotOperatorEnvelope`; crypto test and pilot E2E negative case. | covered |
| Verification rejects wrong operator | `validatePilotOperatorEnvelope`; crypto test and pilot E2E negative case. | covered |
| Verification rejects mutated payload | Existing payload hash validation plus pilot E2E negative case. | covered |
| Verification rejects replay nonce | `pilotEnvelopeReplayKey`; crypto test and pilot E2E negative case. | covered |
| Verification rejects expired message | `validatePilotOperatorEnvelope`; crypto test and pilot E2E negative case. | covered |
| Verification rejects missing cap fields | `validatePilotOperatorEnvelope`; crypto test and pilot E2E negative case. | covered |
| CLI prints exact next commands for deploy/observe/credit/release workflow | `npm run wallet:pilot-next --prefix crypto -- --config out/pilot-wallet-config-check.json` printed deploy plan, observe, bridge credit smoke, release signing, and release verification commands; `flowchain-wallet-pilot-config.ps1` also prints next-command output. Pilot config and public metadata schemas now require at least five `nextCommands`. | covered |
| Runtime/control-plane can validate public envelopes without loading secret vault code | Direct ESM import of `crypto/src/pilot-envelope-validation.js` exports `validatePilotOperatorEnvelope`; `rg` confirms no wallet/vault/signing imports in the public validator files. | covered |
| `npm run flowchain:product-e2e` still passes | After `git merge --ff-only origin/main`, raw `npm run flowchain:product-e2e` passed in the current environment. Upstream `14f378b` made Slither optional for the default hardening gate; explicit Slither audit remains tracked by #131. | covered |
| Scope limited to allowed folders | `git status --short --branch` shows changed files only under allowed `crypto/`, `schemas/flowmemory/`, `infra/scripts/flowchain-wallet*.ps1`, `docs/agent-runs/real-value-pilot-wallet/`, wallet/operator docs, `docs/FLOWCHAIN_REAL_VALUE_PILOT.md`, and root `package.json`. | covered |
| PR output includes env/config boundary | `docs/agent-runs/real-value-pilot-wallet/PR_OUTPUT.md`, `docs/OPERATIONS/REAL_VALUE_PILOT_WALLET_OPERATOR.md`, and `NOTES.md`. | covered |
| PR output includes exact commands run | `docs/agent-runs/real-value-pilot-wallet/PR_OUTPUT.md` and `EXPERIMENTS.md`. | covered |
| PR output includes remaining integration blockers | `docs/agent-runs/real-value-pilot-wallet/PR_OUTPUT.md`, this audit, and `NOTES.md` record that no wallet-scope blocker remains; #131 remains an explicit Slither audit follow-up. | covered |

## Product E2E Resolution

This branch was first fast-forwarded to GitHub source-of-truth `origin/main` at
`14f378b` with:

```powershell
git merge --ff-only origin/main
```

The exact raw gate then passed:

```powershell
npm run flowchain:product-e2e
```

Report path:

```text
devnet/local/product-e2e/flowchain-product-e2e-report.json
```

Generated smoke artifacts outside this wallet scope were restored after the
successful run; `git status --short --branch` again shows only allowed
wallet/operator/schema/doc changes.

Before publishing the wallet proof PR, this branch was rebased onto current
`origin/main` at `c4959f8`, which includes the merged
control-plane/dashboard pilot command. The root wallet pilot command now gives
the HQ final gate a concrete proof command for issue #136:

```powershell
npm run flowchain:real-value-pilot:wallet
```

## Slither Audit Follow-Up

GitHub source-of-truth tracker: https://github.com/FlowmemoryAI/FlowMemory/issues/131.
Earlier wallet-branch evidence comment: https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446800854.
Post-fast-forward pass evidence comment: https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446898654.

Focused reproduction:

```powershell
slither . --config-file .slither.config.json
```

Result: failed with two Slither detector findings:

- `missing-zero-check` on `BaseBridgeLockbox.releaseNative(...).recipient`
  flowing into `recipient.call{value: amount}("")` at
  `contracts/bridge/BaseBridgeLockbox.sol:201-208`.
- `low-level-calls` on the same `recipient.call{value: amount}("")` at
  `contracts/bridge/BaseBridgeLockbox.sol:208`.

Read-only contract inspection found that `_recordRelease` does check
`recipient == address(0)` at `contracts/bridge/BaseBridgeLockbox.sol:308-313`
before `releaseNative` performs the call, so the `missing-zero-check` item is
likely a static-analysis/path-sensitivity issue rather than an absent runtime
check. The `low-level-calls` item is still a Slither hardening-policy finding.
Handling either finding remains a contracts/security audit follow-up outside
this wallet/operator scope. It no longer blocks the default raw product E2E
gate on current `origin/main`.
