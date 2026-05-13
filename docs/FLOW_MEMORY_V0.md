# Flow Memory V0

Status: launch-critical V0 specification.

Flow Memory is the AI-facing memory layer built from FlowPulse observations, Rootflow transitions, receipts, verifier reports, and committed roots.

Flow Memory V0 does not put heavy AI memory on-chain. It turns compact public signals and verifiable receipts into structured memory objects that agents and dashboards can read.

## Purpose

Flow Memory V0 answers:

1. What happened?
2. Why does it matter as memory?
3. Which root or Rootfield does it affect?
4. What is the verification status?
5. How can an AI agent cite or use it without pretending raw model data lives on-chain?

## Launch Flow

```text
Uniswap v4 adapter or fixture activity
-> FlowPulse
-> indexed observation
-> MemorySignal
-> MemoryReceipt
-> RootflowTransition
-> RootfieldBundle
-> AgentMemoryView
```

## Core Objects

### MemorySignal

A `MemorySignal` is the smallest agent-readable event derived from a FlowPulse observation.

Minimum V0 fields:

```json
{
  "schema": "flowmemory.memory_signal.v0",
  "signalId": "bytes32-or-hex-string",
  "pulseId": "bytes32-or-hex-string",
  "rootfieldId": "bytes32-or-hex-string",
  "signalType": "rootfield_registration|root_commitment|swap_memory_signal|unsupported_pulse",
  "subject": "bytes32-or-hex-string",
  "commitment": "bytes32-or-hex-string",
  "contractEvent": {
    "schema": "flowmemory.flowpulse_contract_event.v0",
    "interfaceName": "IFlowPulse",
    "eventName": "FlowPulse",
    "eventSignatureText": "FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)",
    "pulseTypeName": "ROOT_COMMITTED",
    "indexed": {
      "pulseId": "bytes32-or-hex-string",
      "rootfieldId": "bytes32-or-hex-string",
      "actor": "0x..."
    },
    "payload": {
      "subject": "bytes32-or-hex-string",
      "commitment": "bytes32-or-hex-string",
      "parentPulseId": "bytes32-or-hex-string",
      "sequence": "2"
    },
    "receiptLocator": {
      "chainId": "8453",
      "blockNumber": "123457",
      "txHash": "0x...",
      "logIndex": "3"
    }
  },
  "status": "observed|pending|verified|failed|reorged|unsupported"
}
```

`contractEvent` is intentionally split between contract-emitted event fields and
receipt-derived locator fields. `IFlowPulse` emits `pulseId`, `rootfieldId`,
`actor`, `pulseType`, `subject`, `commitment`, `parentPulseId`, `sequence`,
`occurredAt`, and `uri`; the indexer adds `txHash`, `logIndex`, block metadata,
and receipt status after receipts/logs exist.

`swap_memory_signal` is the V0 name for a swap-derived signal. The current
contract path is `FlowMemoryHookAdapter.afterSwap`, which emits a FlowPulse with
`pulseType = 4`, `subject = poolId`, and a caller-supplied memory commitment.
The adapter cannot know `txHash` or `logIndex`; those fields are added by the
indexer after receipts/logs exist.

### MemoryReceipt

A `MemoryReceipt` links a signal to evidence, commitments, and verifier output.

Minimum V0 fields:

```json
{
  "schema": "flowmemory.memory_receipt.v0",
  "receiptId": "bytes32-or-hex-string",
  "signalId": "bytes32-or-hex-string",
  "rootfieldId": "bytes32-or-hex-string",
  "artifactCommitment": "bytes32-or-hex-string",
  "evidenceURI": "string-or-null",
  "verifierReportId": "bytes32-or-hex-string-or-null",
  "status": "pending|verified|failed|reorged|unsupported"
}
```

### RootfieldBundle

A `RootfieldBundle` is the current dashboard and agent-facing state for one Rootfield namespace.

Minimum V0 fields:

```json
{
  "schema": "flowmemory.rootfield_bundle.v0",
  "rootfieldId": "bytes32-or-hex-string",
  "schemaHash": "bytes32-or-hex-string",
  "metadataHash": "bytes32-or-hex-string",
  "latestRoot": "bytes32-or-hex-string",
  "latestTransitionId": "bytes32-or-hex-string-or-null",
  "pulseCount": 1,
  "rootCount": 1,
  "status": "active|inactive|unknown",
  "updatedAt": "iso-8601"
}
```

### AgentMemoryView

An `AgentMemoryView` is the safe output shape for AI agents.

Minimum V0 fields:

```json
{
  "schema": "flowmemory.agent_memory_view.v0",
  "rootfieldId": "bytes32-or-hex-string",
  "latestRoot": "bytes32-or-hex-string",
  "verifiedSignals": [],
  "pendingSignals": [],
  "failedSignals": [],
  "reorgedSignals": [],
  "openQuestions": [],
  "limitations": [
    "Heavy memory artifacts are off-chain.",
    "V0 verification is local/testnet readiness, not a production trustless proof network."
  ]
}
```

## Work And Reliability Vocabulary

Flow Memory V0 reserves these work lanes for agent and dashboard vocabulary:

- `MEMORY_REFRESH`
- `FAILURE_DISCOVERY`
- `FAILURE_REPAIR`
- `MANIFOLD_DISCOVERY`
- `STEERING_VALIDATION`
- `CHECKPOINT_STORAGE`
- `GPU_TRAINING`
- `EVAL_COUNTEREXAMPLE`

These names do not mean the repo already implements GPU training, proof networks, or production agent automation. They are V0 vocabulary for future-compatible memory records.

## What Agents May Say

Allowed:

- "This swap or fixture produced a FlowPulse."
- "The indexer observed the pulse and derived receipt metadata."
- "This MemorySignal is linked to `IFlowPulse.FlowPulse` event semantics."
- "The verifier produced a V0 report."
- "Rootflow moved this Rootfield from one committed root to another."
- "This AgentMemoryView exposes verified and pending memory signals."

Not allowed:

- "AI runs on-chain."
- "All memory is stored on-chain."
- "Storage is free."
- "The hook knows txHash or logIndex during execution."
- "FlowMemory is a production L1."
- "V0 verification is fully trustless."

## Dashboard Display Path

The dashboard should be able to render:

- Rootfield list.
- Rootfield detail.
- Rootflow transition timeline.
- MemorySignal feed.
- MemoryReceipt detail.
- Verifier report status.
- AgentMemoryView JSON or readable summary.

Fixtures are acceptable for V0 launch if they are deterministic and documented.

## Launch Acceptance

Flow Memory V0 is launch-ready only when the local system can:

1. Produce or load a FlowPulse fixture.
2. Derive a MemorySignal.
3. Link a MemoryReceipt.
4. Produce a verifier report.
5. Produce a Rootflow transition.
6. Update a RootfieldBundle.
7. Render an AgentMemoryView or dashboard equivalent.

The current local/test generator is:

```powershell
npm run launch:v0
```

The stricter local launch-candidate gate is:

```powershell
npm run launch:candidate
```

It writes generated Flow Memory V0 objects to:

```text
fixtures/launch-core/flowmemory-launch-v0.json
```

Canonical local/test schemas live in:

```text
schemas/flowmemory/
```

The first launch can be fixture-backed, but the boundaries must be honest and documented.
