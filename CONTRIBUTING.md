# Contributing

FlowMemory uses GitHub issues and pull requests as the source of truth.

## Start Here

Before changing code or docs, read:

1. `AGENTS.md`
2. `docs/START_HERE.md`
3. `docs/FLOWMEMORY_HQ_CONTEXT.md`
4. `docs/CURRENT_STATE.md`
5. `docs/PR_PROCESS.md`

## Rules That Matter

- Do not commit secrets, private keys, seed phrases, RPC credentials, API keys, webhook URLs, or private user data.
- Do not claim production readiness, mainnet readiness, trustless verification, free storage, or AI running on-chain.
- Keep heavy AI/model/memory/media artifacts off-chain.
- Prefer small, scoped PRs with tests or documented verification.
- Update docs when changing architecture, security assumptions, public schemas, public contracts, or agent workflows.

## Local Checks

Run the checks for the area you touched. Common gates:

```powershell
npm test
npm run contracts:hardening
npm run launch:candidate
npm run public-agent-network:contracts
npm run public-agent-network:local-e2e
npm test --prefix apps/dashboard
npm run build --prefix apps/dashboard
node infra/scripts/check-unsafe-claims.mjs
git diff --check
```

Some checks require optional local dependencies. If a check cannot run in your environment, say exactly why in the PR.

## Pull Request Summary

Every PR should include:

- What changed
- Why it changed
- Tests or checks run
- Risks, assumptions, and follow-ups
