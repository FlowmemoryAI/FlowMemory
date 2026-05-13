# Marketing Claims Guardrails

Status: required for launch copy, README updates, docs, and marketing drafts.

FlowMemory can have ambitious language. It should not make claims that the current repo cannot support.

## Strong Claims That Are Allowed

- FlowMemory turns market and network activity into verifiable memory signals for AI agents.
- FlowPulse events create a public signal spine for roots, receipts, work state, and verifier reports.
- Rootflow models parent/child memory-state transitions.
- Flow Memory V0 exposes agent-facing MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, and RootflowTransition objects.
- Heavy AI, model, memory, media, and artifact data stays off-chain while commitments and receipts stay on-chain or in signed fixtures.
- Base Sepolia live reading is being built as a testnet reader path.
- The documented Base mainnet V0 canary can be described only as a guarded
  canary/testing deployment with `productionReady: false`.
- FlowRouter and FlowNet are research directions for hardware, cache, mesh signaling, and receipt relay.

## Claims That Remain Blocked

- FlowMemory is production-ready.
- FlowMemory is mainnet-ready.
- FlowMemory has had a production launch.
- FlowMemory has had a mainnet launch.
- FlowMemory has production mainnet contracts.
- FlowMemory has production deployment automation.
- FlowMemory is a production L1.
- FlowMemory runs a production verifier network.
- FlowMemory has a production Uniswap v4 hook.
- FlowMemory has a production bridge.
- FlowMemory provides production custody or wallet support.
- FlowMemory cryptography or contracts are audited unless a named audit artifact exists.
- AI runs on-chain.
- Storage is free.
- Transaction hashes store arbitrary AI data.
- The Uniswap v4 hook can know `txHash` or `logIndex` during execution.
- The verifier network is fully trustless.
- FlowRouter replaces ISPs.
- Meshtastic provides normal internet bandwidth.
- Current hardware is manufactured, certified, or field deployed.

## Required Framing

Use:

- local/test V0
- fixture-backed dashboard
- Base Sepolia reader path
- guarded Base mainnet canary for documented V0 testing only
- canary-only and `productionReady: false`
- off-chain verification path
- commitments, receipts, roots, and state transitions
- future appchain/L1 research

Avoid:

- production launch
- mainnet launch
- production mainnet contracts
- trustless network
- production verifier network
- production bridge
- production custody
- audited cryptography
- on-chain AI
- free storage
- decentralized ISP replacement
- final hardware

## CI Enforcement

The repository hygiene workflow runs:

```powershell
node infra/scripts/check-unsafe-claims.mjs
```

The script scans `README.md`, `docs/`, and `marketing/` if present. It fails on unsafe positive claims unless the line or section clearly marks them as blocked, non-goals, boundaries, or not implemented.
