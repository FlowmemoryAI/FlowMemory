# Contract Event Spine For Launch-Core V0

Date: 2026-05-13

Status: accepted for local/test V0 fixtures.

## Context

The launch-core generator already connected indexer observations, verifier
reports, Rootflow transitions, and dashboard fixture output. The missing piece
was an explicit contract-event spine that showed how generated Flow Memory
objects map back to `IFlowPulse.FlowPulse` semantics.

Without this spine, dashboards and reviewers could see `pulseId`, `txHash`, and
`logIndex`, but they had to infer which fields were emitted by the contract and
which fields were derived by the indexer after receipts/logs existed.

## Decision

Generated `MemorySignal` objects now include `contractEvent`:

- `interfaceName`: `IFlowPulse`
- `eventName`: `FlowPulse`
- event signature text and topic0
- source contract address
- pulse type id and pulse type name
- indexed event fields: `pulseId`, `rootfieldId`, `actor`
- payload fields: `subject`, `commitment`, `parentPulseId`, `sequence`,
  `occurredAt`, `uri`
- receipt-derived locator fields: `chainId`, `blockNumber`, `blockHash`,
  `txHash`, `transactionIndex`, `logIndex`, `receiptStatus`

Generated `RootflowTransition` objects now include `contractEventRef`, a compact
reference back to the event that produced the transition's MemorySignal.

The dashboard may display this event spine for launch demos, but it must remain
fixture-backed until a separate live indexing/API decision is accepted.

## Boundaries

- Contracts do not know `txHash`, `transactionIndex`, `logIndex`, `blockHash`,
  or receipt status during execution.
- Indexers derive receipt locator fields after reading receipts and logs.
- This is not a production Uniswap v4 deployment.
- This is not a production L1, production mainnet readiness, full trustless
  verification, free storage, or AI running on-chain.

## Consequences

- Reviewers can trace MemorySignals and RootflowTransitions back to concrete
  contract event semantics.
- Dashboard demos can show the full local path from `FlowPulse` to agent memory
  without implying that heavy memory data lives on-chain.
- Future live indexing work must preserve the same emitted-vs-derived boundary.
