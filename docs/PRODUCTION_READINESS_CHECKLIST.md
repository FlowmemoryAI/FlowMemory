# Production Readiness Checklist

Status: blocking checklist. FlowMemory is not production-ready until every relevant gate is complete and reviewed.

## Launch V0 Reality

Current launch target:

- local/test Rootflow V0 and Flow Memory V0
- fixture-backed dashboard
- Base Sepolia reader path for FlowPulse logs
- contract hardening baseline
- clear claim boundaries

Current launch target is not:

- production mainnet
- production L1
- token launch
- production verifier network
- production Uniswap v4 hook deployment
- decentralized ISP replacement
- free on-chain storage
- AI running on-chain

## Contract Gates

- Foundry tests pass.
- `forge fmt --check` passes or a deliberate formatting-normalization PR is complete.
- `forge build` passes.
- Static-analysis baseline script passes.
- Slither findings are captured before any public testnet deployment.
- Deployment boundary is documented in `contracts/DEPLOYMENT_BOUNDARY.md`.
- Access-control boundary is documented in `contracts/ACCESS_CONTROL_REVIEW.md`.
- Event tests cover every launch-critical state transition.
- No private keys, RPC secrets, deployment mnemonics, or live credentials are committed.

## Indexer And Backend Gates

- Fixture indexer tests pass.
- Live Base Sepolia reader requires an explicit RPC URL.
- Live reader rejects non-Base Sepolia chain ids.
- Live reader persists deterministic state and a durable checkpoint.
- Base mainnet reads are not enabled by default.
- Reorg, pending, finalized, failed, and removed states remain visible to downstream systems.
- Dashboard fixtures can be regenerated from local outputs.

## Flow Memory And Rootflow Gates

- `npm run launch:v0` passes.
- MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, and RootflowTransition schemas are present.
- Rootflow transitions preserve parent/child linkage.
- Contract-event linkage remains explicit.
- Receipt-only metadata remains indexer-derived.
- Verifier status adapter maps valid and invalid reports into Flow Memory states.

## Dashboard Gates

- Dashboard tests pass.
- Dashboard production build passes.
- Dashboard uses generated fixtures until a production API is explicitly scoped.
- Dashboard copy does not imply production deployment, production L1, full trustless verification, free storage, or AI running on-chain.

## Review Gates

- CI passes.
- Claim guardrail script passes.
- Source-of-truth docs are updated after merge.
- Open risks are captured in GitHub issues.
- A review agent checks the diff for scope creep and unsafe claims.

## Go/No-Go Rule

If any gate fails, the project can still demo local/test V0 behavior, but it must not be described as production-ready or mainnet-ready.
