# Contracts Static Analysis

Status: pre-production hardening setup.

This repository now has one standard command for contract hardening checks:

```powershell
npm run contracts:hardening
```

The underlying platform scripts remain available:

```bash
bash infra/scripts/contracts-static-analysis.sh
```

The command runs:

- `forge build`
- `forge test`
- `slither . --config-file .slither.config.json` when Slither is installed

Formatting can be checked explicitly:

```powershell
.\infra\scripts\contracts-static-analysis.ps1 -CheckFormat
```

```bash
CHECK_FORGE_FMT=1 bash infra/scripts/contracts-static-analysis.sh
```

Audit environments should require Slither explicitly:

```powershell
npm run contracts:hardening:slither
```

```bash
REQUIRE_SLITHER=1 bash infra/scripts/contracts-static-analysis.sh
```

## Slither Triage

`.slither.config.json` excludes the `timestamp` detector for V0 because the current contracts use `block.timestamp` only for advisory `registeredAt`, `updatedAt`, `submittedAt`, `scheduledAt`, and FlowPulse `occurredAt` fields plus `uint64` overflow guards. Those timestamps do not drive randomness, rewards, custody, slashing, dynamic fees, or protocol-critical authorization in the current V0 boundary.

Latest local required-Slither pass on 2026-05-13 analyzed 22 contracts with
100 detectors and found 0 results.

## Current Boundary

The contracts are V0 launch foundations for FlowPulse, Rootfield, receipts, workers, verifiers, cursors, and hook-adapter events. They are not a production L1, production verifier network, token system, custody system, fee system, or production Uniswap v4 hook deployment.

Static-analysis findings should be triaged into:

- blocker: unsafe access control, broken event schema, corrupted state transition, or deploy-time risk
- launch-v0 fix: issue that matters for Base Sepolia/demo correctness
- future hardening: useful improvement that does not block the V0 launch boundary

## Required Before Any Public Testnet Deployment

- All Foundry tests pass.
- `forge fmt --check` passes or a deliberate formatting-normalization PR is opened.
- Slither is run and findings are attached to the PR or issue.
- Access-control changes are reviewed against [ACCESS_CONTROL_REVIEW.md](./ACCESS_CONTROL_REVIEW.md).
- Deployment scope is reviewed against [DEPLOYMENT_BOUNDARY.md](./DEPLOYMENT_BOUNDARY.md).
