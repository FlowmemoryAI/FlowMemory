# Private/Local Ops Wrapper Plan

Status: in progress.

## Scope

Allowed folders:

- `infra/scripts/`
- `docs/`
- `package.json`
- `README.md`
- `.github/`
- `docs/agent-runs/production-l1-ops/`

Forbidden folders:

- `crates/`
- `contracts/`
- `services/`
- `crypto/`
- `apps/dashboard/`
- `hardware/`
- committed local secrets

## Plan

1. Inventory package scripts, PowerShell wrappers, docs, and generated report paths.
2. Add or normalize root command aliases without breaking existing command names.
3. Implement a mock-safe `flowchain:production-l1:e2e` orchestrator that writes JSON and readable summaries without claiming production readiness.
4. Add Windows prereq, doctor, lifecycle, status, logs, export/import, restart, evidence, emergency, and live-readiness command wrappers where missing.
5. Fail closed for Base `8453` live-readiness checks and print only env names.
6. Add secret-safe evidence export and final no-secret/unsafe-claim checks.
7. Update second-computer, troubleshooting, operator, command matrix, and proof docs.
8. Run parser checks and required npm gates, then record the final result.
