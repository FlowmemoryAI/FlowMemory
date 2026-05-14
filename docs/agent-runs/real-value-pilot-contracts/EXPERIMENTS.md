# Real-Value Pilot Contracts Experiments

## Commands

Commands will be recorded here with pass/fail status and concise evidence.

| Command | Status | Notes |
| --- | --- | --- |
| `forge test --match-path tests/bridge/BaseBridgeLockbox.t.sol` | pass | 17 passed, 0 failed. |
| `forge test --match-path tests/FlowChainSettlementSpine.t.sol` | pass | 8 passed, 0 failed. |
| `npm run flowchain:real-value-pilot:contracts` | pass | Focused tests passed, `contracts:hardening` passed with 87 tests, local Anvil dry run passed, Base `8453` missing ack rejected, Base `8453` acknowledged dry run passed, and report written under `devnet/local/real-value-pilot/contracts-e2e/`. |
| Local Anvil `forge script` dry run | pass | `DeployBridgeSpine` simulated on chain `31337` from the root proof wrapper. |
| Base `8453` missing-ack dry run | pass | Rejected with `Base8453PilotAckRequired`. |
| Base `8453` acknowledged dry run | pass | Simulated on chain `8453` with `FLOWCHAIN_BASE8453_PILOT_ACK=true` and nonzero native total cap. |
| `npm run flowchain:product-e2e` | pass | Product Testnet V1 E2E passed. Generated outputs were restored afterward. |
| `npm run flowchain:l1-e2e` | pass | Private/local L1 full-smoke alias passed. Generated outputs were restored afterward. |
| `git diff --check` | pass | Exit 0; Git printed CRLF normalization warnings only. |
| `node infra/scripts/check-unsafe-claims.mjs` | pass | Unsafe-claim scan passed. |
| `npm run flowchain:real-value-pilot:e2e -- -AllowIncomplete` | pass | Incomplete coordination report now lists only runtime #134 missing. |
| `npm run flowchain:real-value-pilot:e2e` | expected fail | Strict final gate fails clearly with only runtime #134 missing. |

## Additional Commands

- `forge fmt --check contracts/FlowChainSettlementSpine.sol script/DeployBridgeSpine.s.sol tests/FlowChainSettlementSpine.t.sol tests/bridge/BaseBridgeLockbox.t.sol`: the source branch recorded existing line-ending/format normalization noise; no broad formatter pass is included in this integration branch.
- `contracts:hardening` keeps Slither optional by default after the HQ policy merge. Explicit Slither audit remains `npm run contracts:hardening:slither` and is outside this contracts proof PR.

## Findings

- The relayer already supports Base `8453` observations in its schema and code,
  but Base mainnet canary mode is read-only on the bridge-full side.
- Contract-side work should preserve the existing `BridgeDeposit` ABI so the
  relayer's parser remains compatible.
- `DeployBridgeSpine` now gates local Anvil `31337`, Base Sepolia `84532`, and
  Base `8453`; the `8453` path requires `FLOWCHAIN_BASE8453_PILOT_ACK=true` and
  nonzero total caps for configured assets.
