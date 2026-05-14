# Production L1 Consensus Notes

## Working Boundaries

- This pass targets private/local authority-set consensus only.
- It does not implement public validator onboarding, staking, slashing, public permissionless consensus, production bridge custody, tokenomics, or audited cryptography.
- Validator keys are represented by public identity and local key-reference metadata. Secret key material must stay out of committed files.

## Source Context

- GitHub/open PR status was checked with `infra/scripts/status-report.ps1`.
- Sibling production runtime notes exist but are early tracking only; there is no final runtime handoff to consume yet.
- No production protocol handoff was present in the production protocol worktree.

## Test Notes

- `flowchain:consensus:smoke` uses an ignored crate-local Cargo target directory to avoid stale binaries from the shared multi-worktree `CARGO_TARGET_DIR`.
- Direct Cargo tests were verified after cleaning the shared package artifact because other worktrees use the same `flowmemory-devnet` crate/package name.
