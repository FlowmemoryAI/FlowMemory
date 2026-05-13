# Contracts Static Analysis

Status: pre-production hardening setup.

This repository now has one standard command for contract hardening checks:

```powershell
.\infra\scripts\contracts-static-analysis.ps1
```

On bash-compatible shells:

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
.\infra\scripts\contracts-static-analysis.ps1 -RequireSlither
```

```bash
REQUIRE_SLITHER=1 bash infra/scripts/contracts-static-analysis.sh
```

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
