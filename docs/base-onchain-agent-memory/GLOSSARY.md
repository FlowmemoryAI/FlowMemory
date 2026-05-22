# Glossary

## AgentAccount

The chain-side identity and configuration record for a bounded agent. It binds owner/admin, kernel, policy root, tool allowlist root, memory root, sequence, and status.

## AgentKernel

A deterministic decision function that maps an observation plus current memory and policy into a small action output. First kernels should be rule or rule-gated scoring kernels.

## AgentMemoryView

The agent-facing projection of current memory state, recent transitions, statuses, and replay warnings. It is derived from contracts, receipts, indexer output, verifier reports, and Rootflow transitions.

## AgentPolicy

A committed policy defining autonomy level, allowed task classes, caps, pause rules, tool rules, and memory admission rules.

## AgentStepRouter

The contract surface that checks preview parity, sequence, policy, caps, tool allowlists, action execution, memory commit, and FlowPulse emission.

## AgentToolRouter

The safety boundary that maps approved action enums to specific allowed contract calls. It is not a generic arbitrary-call executor.

## Autonomy level

A bounded capability tier describing whether an agent can only read, write memory, accept tasks, use capped value, or use multiple approved tools.

## Chain-side memory

Public contract state, roots, logs, events, and compact memory cells that are intentionally committed to a chain-side state machine.

## Cold memory

Append-only memory history behind the current root. It may live in logs, Rootflow transitions, content-addressed artifacts, Merkleized archives, or later immutable data pages.

## Content mode

A field describing how memory content is stored: public short content, commitment only, pointer commitment, contract page, or event-only reconstruction.

## Correction

An append-only update that supersedes or fixes prior memory without deleting the original record.

## External model review

Off-chain model-assisted critique used to improve architecture, tests, and policy. It is not protocol evidence unless converted into a bounded, accepted, committed artifact.

## FlowPulse

FlowMemory's shared event stream for compact protocol activity, roots, commitments, work lifecycle, and memory-relevant signals.

## Hot memory

Bounded working memory stored or readable in compact contract state: latest root, sequence, active goal, policy root, allowlist root, recent roots, counters, and status references.

## Kernel output

The deterministic output from a kernel: action enum, tool id, target, selector, call data hash, memory delta root, reason code, and cap impact.

## MemoryCell

A typed unit of agent memory. It can be a short public memory, a commitment, a pointer commitment, or an event-derived memory.

## MemoryDelta

An append-only transition from a parent memory root to a new memory root.

## Memory root

A cryptographic commitment to current memory state under a named schema and domain.

## Broad coordination systems

Agent coordination networks with identity, reputation, gateway, marketplace, tooling, and hosted-memory features. They are outside FlowMemory's first public scope.

## Observation

A typed input the agent can reason over, such as task state, chain state, event data, receipt data, verifier report, or admitted evidence commitment.

## Observation identity

Receipt-derived identity for an event/log: chain id, contract address, block number, block hash, transaction hash, log index, event signature, and payload hash.

## On-Chain Task Scout

The first proposed agent class: a bounded task agent that reads task/bond state and public memory, previews a deterministic decision, accepts or rejects allowed tasks, writes memory, and exposes replay.

## Preview

A read-only simulation of the next step, normally through `eth_call`. Preview must not mutate state.

## Preview hash

A commitment to the preview output and relevant inputs. The commit path can require it to prevent stale or altered submissions.

## Reason code

A compact protocol value explaining why the kernel selected an action, no-op, rejection, or escalation.

## Replay

Independent reconstruction of a committed step from prior state, receipts, logs, schemas, and admitted evidence.

## RootflowTransition

The FlowMemory transition object binding parent root, new root, source observation, receipt, verifier report, status, and sequence.

## Scar tissue memory

Memory that records failures, slashes, reorgs, stale assumptions, and blocked actions so the agent avoids repeating known mistakes.

## Step

A committed transaction that processes a previewed output, routes an allowed action, writes memory, and emits events.

## Tool allowlist root

A commitment to the set of approved target contracts, selectors, value caps, rate limits, and tool rules.

## VerifierReport

A deterministic report assigning status to an observation, receipt, memory delta, or Rootflow transition under a named ruleset.
