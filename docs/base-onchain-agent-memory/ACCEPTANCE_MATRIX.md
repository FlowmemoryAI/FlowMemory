# Acceptance Matrix

## Completion standard

This workstream is complete only when the local/test On-Chain Task Scout can be replayed end-to-end and the docs, contracts, schemas, services, SDK, examples, and dashboard all describe the same state machine.

## Documentation acceptance

| Requirement | Evidence |
| --- | --- |
| Home exists | `docs/base-onchain-agent-memory/README.md`. |
| Overview exists | `docs/base-onchain-agent-memory/OVERVIEW.md`. |
| Architecture exists | `docs/base-onchain-agent-memory/ARCHITECTURE.md`. |
| Smart-contract docs exist | `docs/base-onchain-agent-memory/SMART_CONTRACTS.md`. |
| SDK/runtime docs exist | `docs/base-onchain-agent-memory/SDK_RUNTIME.md`. |
| Memory model exists | `docs/base-onchain-agent-memory/MEMORY_MODEL.md`. |
| Agent model exists | `docs/base-onchain-agent-memory/AGENT_MODEL.md`. |
| Verification/replay docs exist | `docs/base-onchain-agent-memory/VERIFICATION_REPLAY.md`. |
| Security/trust boundaries exist | `docs/base-onchain-agent-memory/SECURITY_TRUST_BOUNDARIES.md`. |
| Data flow exists | `docs/base-onchain-agent-memory/DATA_FLOW.md`. |
| Local dev/simulation docs exist | `docs/base-onchain-agent-memory/LOCAL_DEV_AND_SIMULATION.md`. |
| Examples exist | `docs/base-onchain-agent-memory/EXAMPLES.md`. |
| Glossary and FAQ exist | `docs/base-onchain-agent-memory/GLOSSARY.md`, `docs/base-onchain-agent-memory/FAQ.md`. |
| Public docs are sanitized | Raw goal prompts stay out of the public repository. |

## MVP 0 fixture acceptance

| Requirement | Evidence |
| --- | --- |
| Agent config fixture | Deterministic JSON fixture with agent id, owner, kernel, policy root, tool root, memory root, sequence, status. |
| Hot memory fixture | Latest root, sequence, goal, policy/tool roots, counters, last report/action ids. |
| Task observation fixture | Canonical task fields and observation root. |
| Preview fixture | Action enum, tool id, target, selector, memory delta root, reason code, preview hash. |
| Action receipt fixture | Selected action, call result/no-op/escalation, receipt id, source observation. |
| Memory delta fixture | Parent root, delta root, new root, memory cells, source receipt. |
| Verifier report fixture | Named checks and status. |
| Rootflow transition fixture | Parent root to new root with observation, receipt, report, status. |
| AgentMemoryView fixture | Current memory, buckets by status, recent actions, warnings. |
| Drift check | Generated fixture matches committed fixture. |

## Contract acceptance

| Requirement | Required tests |
| --- | --- |
| Agent registration | Stores initial roots and emits event/FlowPulse. |
| Read-only preview | Does not mutate state. |
| Preview/commit parity | Commit rejects mismatched preview output. |
| Sequence safety | Commit rejects stale expected sequence. |
| Parent root safety | Memory commit rejects wrong parent root. |
| Tool allowlist | Unknown target/selector/tool id rejected. |
| Cap enforcement | Per-action and epoch caps enforced. |
| Pause | Paused agent cannot mutate. |
| Action failure | Revert/no-op/escalation behavior is explicit. |
| Memory update | New root and sequence update exactly once. |
| Event replay fields | Emitted fields are sufficient for indexer reconstruction. |
| Receipt metadata boundary | Contract never relies on final `txHash` or `logIndex`. |

## Schema and crypto acceptance

| Requirement | Evidence |
| --- | --- |
| Domain-separated ids | Agent, observation, preview, receipt, memory delta, report ids use named domains. |
| Canonical encoding | Hash inputs are documented and covered by vectors or tests. |
| JSON schemas | Schemas exist for fixture objects. |
| Status vocabulary | Uses existing FlowMemory statuses where possible. |
| Negative vectors | Mutated root/action/task kind/delta fixtures fail validation or replay. |

## Indexer/verifier acceptance

| Requirement | Evidence |
| --- | --- |
| Event decoding | Agent and FlowPulse events decoded. |
| Observation identity | Derived from receipt/log fields. |
| Duplicate handling | Duplicate logs do not create duplicate memory transitions. |
| Reorg handling | Reorged observations update status. |
| Replay checks | Kernel, policy, tool, cap, memory root, and receipt checks. |
| Verifier report | Deterministic report with status and checks. |
| Rootflow projection | Transition output references observation, receipt, report, and roots. |
| AgentMemoryView projection | Buckets memory by verified/pending/failed/unresolved/unsupported/reorged/corrected. |

## SDK acceptance

| Requirement | Evidence |
| --- | --- |
| Config validation | Chain id and contract addresses checked. |
| Reads | Agent and hot memory reads. |
| Observation encoding | Task observation helper. |
| Preview | `previewStep` read-only helper. |
| Mutation | `step` requires expected preview and sequence. |
| Event decoding | FlowPulse and agent events decoded. |
| Replay | Receipt or observation replay helper. |
| Errors | Explicit error codes. |
| Example | Runnable local/test example. |

## Dashboard/explorer acceptance

| Requirement | Evidence |
| --- | --- |
| Agent overview | ID, status, sequence, roots. |
| Hot memory | Active goal, counters, recent roots. |
| Memory buckets | Verified, pending, failed, unresolved, unsupported, reorged, corrected. |
| Recent actions | Action, reason, status, receipt. |
| Verifier status | Latest report and checks. |
| Replay trace | Parent root to new root path visible. |
| Boundary labels | Fixture/local/test/canary mode clear. |

## Security acceptance

| Requirement | Evidence |
| --- | --- |
| No secrets | Secret-shaped values are not committed or accepted by runtime intake. |
| Public memory warning | Docs and UI show chain-side memory is public. |
| No broad executor | Router is allowlisted/capped. |
| No hidden decision source | Runtime cannot bypass preview/commit semantics. |
| Failure memory | Failed actions produce visible state. |
| Correction model | Supersession path is documented and tested when implemented. |
| Claim guardrails | Unsafe claim checker passes. |

## Gated later acceptance

These are not required for the first MVP and must not be claimed early.

| Later item | Gate |
| --- | --- |
| Tiny fixed-shape model kernel | Rule/scoring kernel and replay are stable; gas profile and tests accepted. |
| Base Sepolia rehearsal | Local fixture, contracts, services, SDK, docs, and guardrails green. |
| Capped value actions | Cap tests, pause controls, operator runbooks, and review complete. |
| Challenge contracts | Memory correction fixture and verifier semantics stable. |
| Integration with external agent networks | Memory/replay kernel proven independently first. |

## Final claim checklist

Before claiming the workstream complete:

- [ ] All touched area tests pass.
- [ ] Launch-core baseline still passes if affected.
- [ ] Fixture drift checks pass.
- [ ] Claim guardrails pass.
- [ ] `git diff --check` passes.
- [ ] Docs, SDK, contracts, schemas, and dashboard use the same terms.
- [ ] Every major claim has code, schema, fixture, test, or explicit non-goal support.
- [ ] Remaining gaps are listed as gates, not hidden.
