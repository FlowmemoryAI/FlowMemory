# Real-Value Pilot Wallet Notes

## Context Read

- `docs/CURRENT_STATE.md` names encrypted local operator vault behavior as present for local test use but still not production custody.
- `docs/FLOWCHAIN_PRODUCT_TESTNET_V1_ACCEPTANCE.md` keeps `npm run flowchain:product-e2e` as the stricter existing product gate.
- `services/bridge-relayer/README.md` says Base Sepolia reads require env-supplied RPC/lockbox inputs and no private key, seed phrase, RPC credential, or API key belongs in that package or committed fixtures.

## Sibling Worktree Review

`E:\FlowMemory\flowmemory-crypto` has active unmerged work on `agent/l1-loop-wallet-crypto` that adds wallet expiry handling, public metadata import, a public envelope-validation subpath, and a wallet E2E command. This branch will reuse the public-validation boundary idea without editing that sibling worktree.

## Design Notes

- Pilot messages should be separately typed instead of changing existing product transaction schemas, so `flowchain:product-e2e` and product wallet vectors keep their current contract.
- Public validation must live in a module that does not import encrypted vault creation/unlock/signing helpers.
- Env-created operator config should record public chain, contract, operator, and cap policy while treating network credentials and signing material as runtime-only inputs.

## Results

- Added dedicated pilot message schemas for bridge credit acknowledgment, withdrawal intent, release evidence, and emergency pause/revoke controls.
- Added env-derived pilot operator config and public metadata export schemas.
- Added fail-closed pilot config validation for unsupported chain ids, malformed cap ids, zero caps, used-over-max caps, closed cap windows, secret-shaped local paths, Base mainnet non-`USDC-6` caps, and Base mainnet caps above 25 USD before config export.
- Tightened pilot config and public metadata schemas so `nextCommands` requires at least five commands, matching deploy, observe, credit, release-sign, and release-verify output.
- Added fail-closed pilot public metadata export requiring an active operator signer matching the pilot config, and verified the standalone metadata CLI workflow.
- Added `@flowmemory/crypto/pilot-envelope-validation` for runtime/control-plane public validation without vault signing imports.
- Added `npm run wallet:pilot-config`, `wallet:pilot-metadata`, `wallet:pilot-sign`, `wallet:pilot-verify`, `wallet:pilot-next`, and `wallet:pilot-e2e`.
- Added `infra/scripts/flowchain-wallet-pilot-config.ps1` and `infra/scripts/flowchain-wallet-pilot-observe.ps1`.

## Integration Notes

- Bridge relayer env inputs remain runtime-only. `FLOWCHAIN_PILOT_RPC_URL` is consumed by the observe wrapper and is not written to pilot config or public metadata.
- The observe wrapper supports Base Sepolia and capped Base mainnet canary reads. Base mainnet requires `FLOWCHAIN_PILOT_REAL_FUNDS_ACK=I_ACCEPT_CAPPED_REAL_VALUE_PILOT` and a `USDC-6` cap at or below 25 USD.
- The first unmodified `npm run flowchain:product-e2e` run failed before this branch was fast-forwarded because installed Slither reported existing `BaseBridgeLockbox.releaseNative` findings in `contracts/bridge/BaseBridgeLockbox.sol`. Contracts are outside this task's write scope.
- A focused `slither . --config-file .slither.config.json` reproduction failed on `missing-zero-check` and `low-level-calls` for `recipient.call{value: amount}("")` in `BaseBridgeLockbox.releaseNative` at `contracts/bridge/BaseBridgeLockbox.sol:201-208`.
- Read-only contract inspection found `_recordRelease` already rejects `recipient == address(0)` at `contracts/bridge/BaseBridgeLockbox.sol:308-313`, so the zero-check finding likely needs contract-structure or Slither-policy handling by the contract/hardening owner. The low-level native call finding is still a hardening-policy issue.
- The documented optional-Slither path passed after removing only `C:\Users\ntrap\AppData\Roaming\Python\Python311\Scripts` from `PATH` for that command.
- A follow-up read-only audit of the older product E2E scripts found no repo-local environment flag that skipped Slither while preserving the exact raw `npm run flowchain:product-e2e` command.
- After fast-forwarding to GitHub source-of-truth `origin/main` commit `14f378b`, the upstream default/audit Slither split is present locally and raw `npm run flowchain:product-e2e` passes in the current environment.
- Before publish, this branch was rebased onto `origin/main` commit `c4959f8`, which includes the merged control-plane/dashboard pilot proof command, and now exposes root `npm run flowchain:real-value-pilot:wallet`.
- GitHub issue #131 tracks the remaining explicit Slither audit follow-up: https://github.com/FlowmemoryAI/FlowMemory/issues/131.
- Wallet-branch evidence was posted to #131 at https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446800854.
- Post-fast-forward pass evidence was posted to #131 at https://github.com/FlowmemoryAI/FlowMemory/issues/131#issuecomment-4446898654.
