# Production L1 Wallet Plan

## Scope

- Worktree: `E:\FlowMemory\flowmemory-prod-wallet`
- Branch: `agent/production-l1-wallet`
- Allowed implementation surfaces: `crypto/`, `schemas/flowmemory/`, `fixtures/crypto/`, `docs/`, wallet/operator scripts under `infra/scripts/`, and root `package.json` wallet aliases only.
- Forbidden surfaces: `crates/`, `services/`, `contracts/`, `apps/dashboard/`, `hardware/`, committed local vaults, and any committed private material.

## Implementation Phases

1. Inventory existing wallet commands, transaction envelope helpers, product transaction fixtures, local wallet schemas, bridge/operator scripts, and tests.
2. Make the vault boundary explicit in code, tests, and docs.
3. Extend signed envelope creation and verification for transfer, token, DEX, withdrawal intent, and validator/finality action payloads as supported by the local protocol shape.
4. Add human CLI commands for account lifecycle, public metadata, signing, verification, local two-wallet transfer proof, and operator bridge checks.
5. Add negative tests for password, chain, nonce/replay, malformed addresses/keys, mutated payloads, and public metadata secret boundaries.
6. Write proof artifacts using public-only sample values.
7. Run required crypto checks, wallet E2E commands, wallet verify command, no-secret scan, and `git diff --check`.

## Current Boundaries

- This task makes a local/private pilot wallet and signing operator usable. It must not claim production deployment, audited cryptography, public validators, or production bridge readiness.
- Signed envelopes must carry enough metadata for runtime/API intake without exposing private material.
- Live Base pilot commands must validate environment presence and chain ID without logging RPC URLs or keys.

