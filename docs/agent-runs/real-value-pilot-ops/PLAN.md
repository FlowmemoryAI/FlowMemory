# Real-Value Pilot Ops Plan

Status: integrated on current `main` (`a16fb9a`) as the branch-local
`flowchain:real-value-pilot:ops` proof.

## Scope

- Add docs and wrapper scripts for the capped Base `8453` owner pilot.
- Keep changes inside `infra/scripts/`, `docs/`, `README.md`, and `package.json`.
- Do not edit protocol, service, crypto, dashboard, hardware, or contract code.

## Plan

1. Inspect current setup docs, installer scripts, product E2E, long-loop installer work, and GitHub prompt state.
2. Add a dry-run-safe pilot ops proof command.
3. Add live-mode preflight checks for explicit env vars, operator acknowledgement, Base chain id `8453`, tiny nonzero caps, and explicit contract/block ranges.
4. Add live observer wiring to the existing bridge observer path without committing RPC URLs or keys.
5. Add emergency stop and evidence export wrappers.
6. Update second-computer setup and troubleshooting docs with exact owner commands and failure recovery.
7. Preserve the merged HQ final pilot gate by keeping ops dry-run validation in
   `infra/scripts/flowchain-real-value-pilot-ops-e2e.ps1`.
8. Run syntax checks, dry-run pilot ops proof, final pilot report-only gate,
   unsafe-claims scan, `git diff --check`, and product E2E.

## Guardrails

- Dry-run must not require live RPC URLs or private keys.
- Live mode must fail closed without the required env values and explicit acknowledgement.
- Evidence bundles must exclude Git metadata, dependencies, build output, local vaults, private keys, and env files.
- The pilot remains a capped owner-controlled canary, not a production bridge or public release.
