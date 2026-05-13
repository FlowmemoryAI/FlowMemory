# V0 Operator Policy

Date: 2026-05-13

Status: launch canary policy. This is not a governance, multisig, token, upgrade,
or production-operations policy.

## Scope

This policy covers the current V0 contracts documented in:

- `fixtures/deployments/base-canary-v0.json`
- `docs/DEPLOYMENTS/2026-05-13-base-canary-v0.md`

It exists so operators and agents do not confuse a live Base canary deployment
with production readiness.

## Current Operator Model

- The canary deployer is `0x3A6fBA5a78216ba3a8DA8d8F501dee2C8186aFf9`.
- V0 contracts are independently deployed implementation contracts.
- There are no proxies, upgrade admins, timelocks, token roles, fee roles, or
  governance roles in the canary package.
- Registry owner-style permissions remain direct V0 ownership or caller
  self-registration as implemented by each contract.
- Worker and verifier authorization lists are local/test operational surfaces,
  not a production verifier network.

## Required Before Any Production Claim

Production language remains blocked until a later decision records:

1. source verification completed for every deployed contract;
2. operational owner separation for deployer, worker admin, verifier admin, and
   emergency response;
3. multisig or comparable account-control decision;
4. key-rotation and lost-key recovery plan;
5. public incident and rollback/redeploy runbook;
6. verifier/report signing policy;
7. Uniswap v4 hook permission and PoolManager integration review;
8. explicit go/no-go approval in `docs/DECISIONS/`.

## Agent Rules

- Do not reuse the deployer key in CI.
- Do not commit RPC URLs, API keys, private keys, mnemonics, or wallet exports.
- Do not add token, fee, custody, upgrade, or governance behavior to close a
  canary issue.
- If a script needs a private service credential, read it from an environment
  variable and make dry-run output useful without the credential.
- If live chain state differs from a document, update the deployment artifact
  and docs with the observed state rather than hiding the difference.

## Current Gaps

- Source verification automation exists, but actual submission requires
  `BASESCAN_API_KEY`.
- The canary deployer is still a single account.
- There is no multisig, timelock, recovery, or operator separation.
- `FlowMemoryHookAdapter` remains a hook-adjacent adapter, not a production
  Uniswap v4 hook wired to PoolManager permissions.
- Live canary dashboard data is not verifier-backed.
