# Real-Value Pilot Wallet Plan

Status: implementation complete; root pilot command added after rebasing onto
GitHub source-of-truth `origin/main` commit `c4959f8`.

## Scope

- Worktree: `E:\FlowMemory\flowmemory-live-wallet`
- Branch: `agent/real-value-pilot-wallet`
- Allowed writes: `crypto/`, `schemas/flowmemory/`, `fixtures/crypto/`, `infra/scripts/flowchain-wallet*.ps1`, this run directory, and wallet/operator docs under `docs/`.
- Read-only integration review: `services/bridge-relayer/`.
- Forbidden writes: `crates/`, `contracts/`, `services/`, `apps/dashboard/`, and `hardware/`.

## Implementation Plan

1. Done: Add pilot-specific public schemas for capped real-value operator config, public metadata, and signed pilot messages.
2. Done: Extend the crypto object vocabulary with pilot bridge credit acknowledgment, withdrawal intent, release evidence, and emergency control messages.
3. Done: Add a public pilot envelope validator that imports hash/verification helpers but not encrypted vault creation or unlock code.
4. Done: Add local CLI support for config-from-env, metadata export, signing, verification, and exact next-command output.
5. Done: Add a deterministic pilot wallet/operator E2E command that creates local test config from env, signs all required message types, validates negative cases, and scans public outputs for secrets.
6. Done: Add wallet/operator docs for the env/config boundary and non-browser private-key rule.
7. Done: Expose the wallet proof through root `npm run flowchain:real-value-pilot:wallet`.
8. Done: Run focused crypto, wallet, product smoke, pilot E2E, parser, diff, and raw product E2E checks. Product E2E passes on the updated `origin/main` default hardening policy; explicit Slither audit findings remain tracked by #131.

## Non-Goals

- No browser-side private-key handling.
- No committed secrets, RPC credentials, API keys, webhooks, mnemonics, seed phrases, or private keys.
- No production custody, audited wallet, public validator, tokenomics, or production bridge claim.
