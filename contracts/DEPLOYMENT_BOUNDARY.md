# Contracts Deployment Boundary

Status: V0 local and Base Sepolia readiness boundary.

## Allowed Now

- Local Foundry tests.
- Local fixture generation and indexer/verifier/dashboard flows.
- Base Sepolia deployment preparation for the current V0 contracts.
- Base Sepolia reads from explicit RPC URLs.
- Public docs that describe emitted events, roots, receipts, and off-chain verification paths.

## Not Allowed Yet

- Base mainnet deployment claims.
- Production-mainnet readiness claims.
- Production L1 claims.
- Token launch, rewards, slashing, or fee-market mechanics.
- Dynamic Uniswap v4 fee hooks.
- Custody of user tokens.
- Claims that contracts can know `txHash` or `logIndex` during execution.
- Claims that on-chain storage is free or that arbitrary AI data is stored on-chain.

## Deployment Inputs Required

Before a Base Sepolia deployment transaction is sent, the PR or issue must record:

- target chain: Base Sepolia, chain id `84532`
- exact contract names and constructor arguments
- deployer account address
- compiled bytecode hash or Foundry build commit
- expected event signatures
- post-deploy verification steps
- rollback or redeploy plan

Private keys must not be committed to the repo, copied into docs, or stored in generated artifacts.

## Current Contract Set

- `RootfieldRegistry`: Rootfield namespaces and root commitment pulses.
- `FlowMemoryHookAdapter`: dependency-light hook-adapter event scaffold, not a production Uniswap hook.
- `ReceiptVerifier`: compact receipt-report commitments, not cryptographic receipt verification.
- `VerifierReportRegistry`: owner-authorized verifier report commitments.
- `WorkReceiptRegistry`: owner-authorized worker receipt commitments.
- `WorkerRegistry`: self-registration for worker identity metadata.
- `VerifierRegistry`: self-registration for verifier identity metadata.
- `ArtifactRegistry`: artifact commitment metadata.
- `CursorRegistry`: off-chain cursor commitment metadata.
- `WorkDebtScheduler`: work-state commitments without token debt.

## Post-Deploy Checks

- Verify source on the explorer when possible.
- Emit one small test event per deployed event source where safe.
- Run the Base Sepolia indexer reader over the deployment block range.
- Confirm persisted indexer state and checkpoint exist.
- Confirm dashboard fixtures can read the generated state.
- Update `docs/CURRENT_STATE.md` with what is deployed and what remains local-only.
