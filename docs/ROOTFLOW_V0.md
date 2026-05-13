# Rootflow V0

Status: launch-critical V0 specification.

Rootflow is the FlowMemory state-transition layer. It explains how a FlowPulse event, receipt, verifier report, and committed root become a new memory state.

Rootflow V0 is not a production L1, proof network, storage layer, governance system, or token system. It is the local and testnet-ready transition model that lets contracts, crypto, indexers, verifiers, and dashboard agents agree on one memory-state shape.

## Purpose

Rootflow answers five questions:

1. What Rootfield namespace does this memory state belong to?
2. What pulse or previous root does this transition build on?
3. What new root or commitment is being proposed?
4. What receipt and verifier status support the transition?
5. What should a dashboard or AI agent show as the current state?

The launch wedge is:

```text
FlowPulse
-> indexed observation
-> receipt
-> verifier report
-> Rootflow transition
-> Rootfield bundle
-> dashboard-readable Flow Memory state
```

## Core Terms

- `FlowPulse`: the compact on-chain event emitted by a contract or future hook adapter.
- `Rootfield`: a namespace for a memory-state stream.
- `RootfieldBundle`: the current committed root state for a Rootfield namespace.
- `RootflowTransition`: one proposed or accepted state transition within a Rootfield.
- `MemoryReceipt`: an off-chain or future on-chain receipt that links evidence to a signal or transition.
- `VerifierReport`: a deterministic report describing whether a receipt or transition is valid.
- `AgentMemoryView`: the agent-facing projection of verified or pending memory state.

## Required Statuses

Rootflow V0 uses this minimum status vocabulary:

| Status | Meaning |
| --- | --- |
| `observed` | A FlowPulse log or fixture has been read, but it is not yet ready to commit. |
| `pending` | A transition candidate exists and is waiting for verification, confirmation, or required evidence. |
| `verified` | The transition is accepted by the V0 verifier rules. |
| `failed` | The transition was checked and rejected. |
| `reorged` | The underlying observation was removed or superseded by a chain reorg. |
| `unsupported` | The event or receipt uses a schema the V0 verifier does not support. |

Dashboard and verifier work may expose more detailed internal states, but these statuses are the V0 cross-agent contract.

## Rootflow Transition Shape

Every Rootflow transition must be expressible with this canonical shape:

```json
{
  "schema": "flowmemory.rootflow.transition.v0",
  "transitionId": "bytes32-or-hex-string",
  "rootfieldId": "bytes32-or-hex-string",
  "pulseId": "bytes32-or-hex-string",
  "parentPulseId": "bytes32-or-hex-string-or-null",
  "parentRoot": "bytes32-or-hex-string-or-null",
  "newRoot": "bytes32-or-hex-string",
  "artifactCommitment": "bytes32-or-hex-string",
  "receiptId": "bytes32-or-hex-string",
  "verifierReportId": "bytes32-or-hex-string-or-null",
  "status": "observed|pending|verified|failed|reorged|unsupported",
  "sequence": 1,
  "observedAt": "iso-8601-or-block-time",
  "updatedAt": "iso-8601",
  "source": {
    "chainId": 84532,
    "contractAddress": "0x...",
    "blockNumber": 1,
    "blockHash": "0x...",
    "txHash": "0x...",
    "logIndex": 0
  }
}
```

The exact JSON schema may live in the crypto or indexer package, but the fields above are the V0 minimum.

## Invariants

- A transition must belong to exactly one `rootfieldId`.
- A transition must link to one `pulseId`.
- A transition must identify its source observation after the indexer reads receipts and logs.
- A contract must not claim final `txHash` or `logIndex` during execution.
- Heavy memory, model, evaluation, media, and artifact data stays off-chain.
- On-chain state stores compact roots, commitments, receipts, counters, and intentional protocol state only.
- A `verified` transition must have a verifier report or accepted V0 fixture proof.
- A `reorged` transition must not remain the current verified state.

## Agent Responsibilities

Contracts agent:

- Keep `RootfieldRegistry` compact.
- Emit `FlowPulse` events.
- Add lifecycle support only when the status and ownership decisions are accepted.
- Do not add production hooks, tokenomics, governance, or dynamic fees.

Crypto agent:

- Define canonical serialization and hash inputs for Rootflow transitions.
- Define receipt ids, verifier report ids, and domain separation.
- Produce deterministic fixtures.
- Do not build proof circuits or verifier economics for V0.

Indexer/verifier agent:

- Derive `txHash`, `logIndex`, block metadata, and observation identity from receipts and logs.
- Build transition candidates.
- Apply verifier statuses.
- Persist or export the Rootflow timeline for dashboard use.

Dashboard agent:

- Display Rootfield namespaces, Rootflow transitions, status, source observation, and receipt links.
- Treat fixtures as the first data source.
- Do not imply production proof security.

HQ/review agent:

- Keep this spec, current state, roadmap, decision records, and acceptance matrix aligned with GitHub.
- Review PRs against the launch acceptance gates.

## Launch Acceptance

Rootflow V0 is launch-ready only when a local developer can:

1. Emit or load a FlowPulse.
2. Observe it with the indexer.
3. Create or validate a receipt.
4. Commit or update a Rootfield root.
5. Produce a Rootflow transition.
6. Show the resulting transition and status in the dashboard.

Passing an isolated unit test or opening a small PR is not enough.

The current local/test command for this path is:

```powershell
npm run launch:v0
```

It writes generated Rootflow transitions to:

```text
fixtures/launch-core/rootflow-transitions.json
```

## Explicit Non-Goals

- No production L1 claim.
- No production mainnet readiness claim.
- No full trustless verifier network claim.
- No free-storage claim.
- No AI-runs-on-chain claim.
- No tokenomics or dynamic fee hooks.
- No hardware trustlessness claim without verifier/proof infrastructure.
