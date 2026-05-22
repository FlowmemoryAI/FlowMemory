# Security Policy

FlowMemory is public research and local/test infrastructure. Do not treat this repository as production-ready, audited, mainnet-ready, or approved for uncapped value-bearing use.

## Reporting Vulnerabilities

Use GitHub private vulnerability reporting / Security Advisories for suspected vulnerabilities. Do not open public issues containing exploitable details, private keys, RPC credentials, wallet mnemonics, API keys, webhook URLs, or user data.

## Current Security Boundary

- Heavy AI, model, memory, media, and artifact data stays off-chain.
- On-chain contracts store compact roots, receipts, commitments, attestations, proofs, and intentionally bounded work state only.
- Current public-agent, Agent Bonds, Rootflow, and Flow Memory paths are local/test or capped-pilot surfaces unless a document explicitly says otherwise.
- Public test keys and deterministic fixtures may appear in tests and scripts. Real secrets must never be committed.
- Base mainnet canary references are historical, bounded test evidence only; they are not a production launch.

## Before Running Live Commands

Read:

1. `docs/CURRENT_STATE.md`
2. `docs/PRODUCTION_READINESS_CHECKLIST.md`
3. `docs/MARKETING_CLAIMS_GUARDRAILS.md`
4. the task-specific deployment or operations runbook

Any command requiring `.env`, RPC URLs, deployer keys, API keys, or wallet credentials must be run locally with uncommitted environment files.
