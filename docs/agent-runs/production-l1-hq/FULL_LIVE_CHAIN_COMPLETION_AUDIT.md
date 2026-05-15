# Full Live Chain Completion Audit

Date: 2026-05-14
Branch: `agent/production-l1-hq`

## Objective Restatement

FlowChain is complete only when it is a live, running L1 with its own node/RPC
surface, block production, usable wallets, transaction execution, bridge
crediting from Base 8453, spendable bridged funds, explorer/control-plane
visibility, storage/recovery, docs, SDK/dev kits, and release verification. The
goal is not complete if any path is local-only, fixture-only, blocked by missing
deployment input, or unverified.

## Current Result

Status: `NOT_COMPLETE`.

The local/private path is now substantially green, including runtime-backed RPC
submission and local production-shaped E2E. The public/live path is still
blocked by missing public RPC deployment inputs and Base 8453 bridge inputs. A
new uncovered goal prompt was added for SDK, docs, examples, and developer
tooling because the original goal pack did not assign that requirement to a
dedicated agent. A second uncovered prompt was added for live infrastructure,
public RPC hosting/readiness, service persistence, backup readiness, and Base
8453 deployment coordination because the original ops prompt focused on local
Windows installation.

## Prompt-To-Artifact Checklist

| Requirement | Evidence inspected | Status |
| --- | --- | --- |
| Produce blocks | `devnet/local/production-l1-e2e/flowchain-production-l1-e2e-report.json` shows `latestHeight`, `latestHash`, `finalizedHeight`; `npm run flowchain:node:smoke` previously passed | Local/private proven |
| Transaction intake and execution | `npm run flowchain:wallet:transfer:e2e` passed; production E2E `walletE2EStatus` and `transferE2EStatus` are `passed` | Local/private proven |
| Runtime-backed RPC | `devnet/local/rpc-e2e/flowchain-rpc-e2e-report.json` shows `runtimeSubmitChecked`, `mempoolVisibleBeforeBlock`, block/tx/account/balance/provenance/restart checks all true | Local/private proven |
| Public RPC readiness | RPC E2E reports `readinessStatus: BLOCKED`, `publicRpcReady: false` | Blocked |
| Missing public RPC inputs | RPC E2E names `FLOWCHAIN_RPC_PUBLIC_URL`, `FLOWCHAIN_RPC_ALLOWED_ORIGINS`, `FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE`, `FLOWCHAIN_RPC_TLS_TERMINATED`, `FLOWCHAIN_RPC_STATE_BACKUP_PATH` | Blocked |
| Wallet create/send/transfer | production E2E has wallet commands passed; desktop/mobile wallet agent still owns full installable app completion | Partially proven |
| Bridge mock path | production E2E `bridgeMockStatus: passed` | Local/mock proven |
| Live Base 8453 bridge readiness | production E2E `bridgeLiveReadinessStatus: blocked`; pass/fail summary `passed-with-live-blockers` | Blocked |
| Missing live bridge inputs | production E2E names `FLOWCHAIN_PILOT_OPERATOR_ACK`, `FLOWCHAIN_BASE8453_RPC_URL`, `FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS`, `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`, `FLOWCHAIN_BASE8453_ASSET_DECIMALS`, `FLOWCHAIN_BASE8453_FROM_BLOCK`, `FLOWCHAIN_BASE8453_TO_BLOCK`, `FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI`, `FLOWCHAIN_PILOT_TOTAL_CAP_WEI`, `FLOWCHAIN_PILOT_CONFIRMATIONS` | Blocked |
| Exact bridge credit spendability | Mock/local bridge and wallet transfer paths pass; configured-live Base 8453 credit/spend path is blocked before broadcast | Not live-proven |
| Assets/DEX/swap | production E2E `tokenE2EStatus` and `dexE2EStatus` are `passed` | Local/private proven |
| Explorer/control-plane visibility | production E2E `rpcSmokeStatus` and `dashboardBuildOrBrowserStatus` are `passed`; control-plane smoke passed | Local/private proven |
| Storage/export/import/restart | production E2E `exportImportStatus` and `restartRecoveryStatus` are `passed` | Local/private proven |
| Cryptography/signing safety | wallet E2E and no-secret scan passed; dedicated wallet/keys and consensus agents still own deeper production hardening | Partially proven |
| Docs and dev kits | No dedicated prompt existed in the goal pack; added `14-sdk-docs-developer-tooling.md` and launcher entry | Newly assigned, not built |
| Public infrastructure owner | Original ops prompt was local-run focused; added `15-live-infrastructure-public-rpc.md` and launcher entry for public RPC, service persistence, backups, and Base 8453 deployment readiness | Newly assigned, not built |
| Final live product verifier | `13-live-product-verification.md` exists and requires `npm run flowchain:live-product:e2e`, but that final command is not yet evidenced as passing | Not complete |
| GitHub state | SDK/docs prompt commit `4b8afe4` was pushed; current infra prompt additions must be committed/pushed | Pending |

## Actual Command Evidence

- `npm test --prefix services/control-plane`: passed, 27/27.
- `npm run control-plane:smoke`: passed.
- `npm run flowchain:rpc:e2e`: passed locally with public readiness blocked.
- `npm run flowchain:node:smoke`: passed locally.
- `npm run flowchain:wallet:transfer:e2e`: passed locally.
- `npm run flowchain:l1-e2e`: passed locally.
- `npm run flowchain:production-l1:e2e`: `passed-with-live-blockers`.
- `npm run flowchain:no-secret:scan`: passed.
- `node infra/scripts/check-unsafe-claims.mjs`: passed.
- `git diff --check`: passed before this audit update; must be rerun after.

## Missing Or Weakly Verified Requirements

1. Public FlowChain RPC is not ready until public URL, CORS, rate limit, TLS
   termination, and state backup path inputs are configured and verified.
2. Live Base 8453 bridge is not ready until operator acknowledgement, Base RPC,
   lockbox address, token metadata, block range, caps, and confirmations are
   configured and verified.
3. Real Base deposit to exact FlowChain credit to spendable transfer is not
   live-proven; only mock/local paths are currently green.
4. Desktop/mobile wallet installability and every side panel still need final
   verification from the wallet-apps and release-gate prompts.
5. SDK/docs/devkit work was uncovered by the original 13-prompt pack; it now has
   a dedicated prompt and launcher entry but no completed artifacts yet.
6. Public RPC hosting, service persistence, state backup readiness, and live
   bridge deployment coordination were not deeply owned by the local ops prompt;
   they now have a dedicated prompt and launcher entry but no completed
   artifacts yet.
7. `npm run flowchain:live-product:e2e` is required by the goal pack but has not
   been proven passing from a clean checkout with configured live dependencies.

## Next Prompt Action

Added:

- `docs/agent-goals/production-l1-live-chain/14-sdk-docs-developer-tooling.md`
- `docs/agent-goals/production-l1-live-chain/15-live-infrastructure-public-rpc.md`
- launcher entry for `sdk-docs`
- launcher entry for `infra-rpc`

This new prompt must keep looping until FlowChain has runnable SDK/devkit/docs
artifacts and `npm run flowchain:sdk:e2e` passes locally while keeping live
paths fail-closed. The infra prompt must keep looping until
`npm run flowchain:live-infra:check` exists and proves public RPC/service/backup
and Base 8453 deployment readiness or fails closed with exact owner inputs.

## Completion Decision

Do not mark the active goal complete. FlowChain is not yet a fully live L1 with
public RPC, configured live Base bridge, spendable live bridged funds, and
completed SDK/devkit/docs verification.
