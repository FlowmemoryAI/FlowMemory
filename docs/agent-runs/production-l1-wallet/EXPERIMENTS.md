# Production L1 Wallet Experiments

## Log

| Time | Command | Result | Notes |
| --- | --- | --- | --- |
| 2026-05-14 | `git status --short --branch` | Pass | Current wallet worktree clean on `agent/production-l1-wallet`. |
| 2026-05-14 | `infra/scripts/status-report.ps1` | Pass | Confirmed GitHub issue/PR state and unrelated dirty sibling worktrees. |
| 2026-05-14 | `npm test --prefix crypto` | Pass | 24 tests passed, including wallet metadata/envelope negative cases. |
| 2026-05-14 | `npm run wallet:e2e --prefix crypto` | Pass | Two-wallet transfer plus token, DEX, withdrawal signing; local API mempool accepted 2 envelopes. |
| 2026-05-14 | `npm run wallet:transfer:e2e --prefix crypto` | Pass | Transfer-only two-wallet proof; local API mempool accepted 1 envelope. |
| 2026-05-14 | `npm run wallet:verify --prefix crypto` | Pass | Verification smoke returned `valid: true`. |
| 2026-05-14 | `npm run flowchain:real-value-pilot:wallet` | Pass | Runs pilot wallet E2E and production L1 wallet E2E together. |
| 2026-05-14 | `wallet:operator-bridge env / prepare-*` | Pass | Printed required env names, dry-run commands, live commands, and no RPC values. |
| 2026-05-14 | mock `wallet:operator-bridge validate --live` | Pass | Accepted mock Base `0x2105` and rejected mock wrong chain `0x1`. |
| 2026-05-14 | CLI create/list/metadata/sign/verify/unlock/lock smoke | Pass | Human CLI path created two ignored local vaults, printed only schema/address/public key on create, signed and verified a transfer envelope. |
| 2026-05-14 | CLI import smoke | Pass | Import printed only schema/address and wrote the vault under ignored local storage. |
