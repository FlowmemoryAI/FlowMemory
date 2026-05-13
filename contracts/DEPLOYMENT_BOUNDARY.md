# Contracts Deployment Boundary

Status: V0 local and Base Sepolia readiness boundary.

## Allowed Now

- Local Foundry tests.
- Local fixture generation and indexer/verifier/dashboard flows.
- Base Sepolia deployment dry runs and explicit broadcasts for the current V0 contracts.
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

## Current Commands

```powershell
npm run deploy:base-sepolia
npm run deploy:base-sepolia:broadcast
npm run read:base-sepolia -- --rpc-url <base-sepolia-rpc-url> --address <flowpulse-contract> --from-block <n> --to-block <n>
npm run verify:base-canary:sources -- --json
```

`deploy:base-sepolia` requires `BASE_SEPOLIA_RPC_URL` and
`BASE_SEPOLIA_DEPLOYER_KEY_HEX` from the local shell or an untracked `.env`
loader. The example file is `.env.example`; real key material must stay
outside Git.

`verify:base-canary:sources` reads `fixtures/deployments/base-canary-v0.json`
and prints a dry-run verification plan by default. It also writes the same
non-secret plan to
`fixtures/deployments/base-canary-source-verification-plan.json`. Actual
submission uses `npm run verify:base-canary:sources:submit` and requires
`BASESCAN_API_KEY`. This script does not need a private key.

## Current Contract Set

- `RootfieldRegistry`: Rootfield namespaces and root commitment pulses.
- `FlowMemoryHookAdapter`: dependency-light hook-adapter plus Uniswap v4-shaped afterSwap callback path, not a production Uniswap hook deployment.
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
