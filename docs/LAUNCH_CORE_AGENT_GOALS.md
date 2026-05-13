# Launch-Core Agent Goals

Status: copy-ready coordination prompts for Rootflow V0 and Flow Memory V0.

Use these prompts for the active launch-core workstreams. They are intentionally larger than a small issue prompt. Each agent must keep working until it produces concrete evidence for `docs/V0_LAUNCH_ACCEPTANCE.md`.

Before starting any builder, read:

- `AGENTS.md`
- `docs/START_HERE.md`
- `docs/CURRENT_STATE.md`
- `docs/ROOTFLOW_V0.md`
- `docs/FLOW_MEMORY_V0.md`
- `docs/V0_LAUNCH_ACCEPTANCE.md`
- `docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md`

## Shared Goal Prefix

```text
/goal You are contributing to the Rootflow V0 and Flow Memory V0 launch core.

This is not complete when a small PR is opened. Continue until your assigned subsystem produces concrete evidence for docs/V0_LAUNCH_ACCEPTANCE.md and resolves the relevant gaps in docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md.

GitHub is the source of truth. Read the repo docs first. Work only in your assigned worktree and assigned folders. Add commits to the existing PR branch when one exists.

Do not claim production L1, production mainnet readiness, full trustless verification, free storage, or AI running on-chain.

Before finishing, provide:
- files changed;
- exact commands run;
- exact acceptance rows satisfied;
- acceptance rows still incomplete;
- risks and follow-up issues.
```

## Contracts Agent

Worktree:

```powershell
cd E:\FlowMemory\flowmemory-contracts
gh pr checkout 57
```

Assigned issue: #63.

Prompt:

```text
Use the shared launch-core goal prefix.

Build the contracts-side Rootflow V0 support and coverage.

Primary scope:
- contracts/
- tests/
- foundry.toml
- contract decision records only when needed

Required outcomes:
- Rootfield namespaces are hardened and tested.
- Root commitments are hardened and tested.
- Parent pulse/root linkage needed by Rootflow V0 is emitted or preserved.
- FlowPulse linkage is explicit and test-covered.
- Contract state stays compact.
- Contracts do not pretend to know txHash or logIndex.
- No production hook deployment, tokenomics, dynamic fees, governance, or production deployment config.

Required evidence:
- forge test output.
- git diff --check output.
- PR summary mapping work to docs/V0_LAUNCH_ACCEPTANCE.md rows.
```

## Crypto Agent

Worktree:

```powershell
cd E:\FlowMemory\flowmemory-crypto
```

Assigned issue: #64.

Prompt:

```text
Use the shared launch-core goal prefix.

Build the canonical crypto/schema/fixture layer for Rootflow V0 and Flow Memory V0.

Primary scope:
- crypto/
- packages/crypto/ if present
- fixtures/crypto/ if present or created
- crypto-related docs and decisions

Required outcomes:
- Canonical ids, serialization, hash inputs, and JSON schemas for:
  - MemorySignal
  - MemoryReceipt
  - RootflowTransition
  - RootfieldBundle
  - AgentMemoryView
  - verifier report
- Deterministic fixture vectors.
- Positive and negative validation cases.
- Clear boundary between V0 local/testnet readiness and future proof-carrying receipts.

Required evidence:
- package validation/test command output.
- fixture paths.
- schema paths.
- PR summary mapping work to docs/V0_LAUNCH_ACCEPTANCE.md rows.
```

## Indexer/Verifier Agent

Worktree:

```powershell
cd E:\FlowMemory\flowmemory-indexer
gh pr checkout 61
```

Assigned issue: #65.

Prompt:

```text
Use the shared launch-core goal prefix.

Build the Rootflow V0 fixture engine and verifier report pipeline.

Primary scope:
- services/indexer/
- services/verifier/
- services/shared/
- fixtures/
- indexer/verifier docs

Required outcomes:
- Parse FlowPulse fixtures.
- Derive observation identity from receipt/log data.
- Produce MemorySignal fixtures.
- Link MemoryReceipt fixtures.
- Produce RootflowTransition fixtures.
- Produce verifier reports.
- Export dashboard-readable RootfieldBundle and AgentMemoryView state.
- Support observed, pending, verified, failed, reorged, and unsupported external states.
- If internal statuses use valid/invalid, document and implement the adapter to external verified/failed naming.

Required evidence:
- npm test or equivalent output.
- fixture generation command output.
- output fixture paths.
- PR summary mapping work to docs/V0_LAUNCH_ACCEPTANCE.md rows.
```

## Dashboard Agent

Worktree:

```powershell
cd E:\FlowMemory\flowmemory-dashboard
gh pr checkout 62
```

Assigned issue: #66.

Prompt:

```text
Use the shared launch-core goal prefix.

Build the fixture-backed dashboard display path for Rootflow V0 and Flow Memory V0.

Primary scope:
- apps/dashboard/
- dashboard docs
- dashboard fixture adapters

Required outcomes:
- Render Rootfield namespaces.
- Render Rootflow transition timeline.
- Render MemorySignal feed.
- Render MemoryReceipt detail.
- Render verifier report status.
- Render AgentMemoryView or equivalent agent-readable state.
- Support observed, pending, verified, failed, reorged, unsupported, unresolved, and invalid where adapters require them.
- Use deterministic fixtures first.
- No hosted production API or production deployment config.

Required evidence:
- npm test output.
- npm run build output.
- local preview or screenshot evidence when possible.
- PR summary mapping views to docs/V0_LAUNCH_ACCEPTANCE.md rows.
```

## Review Agent

Worktree:

```powershell
cd E:\FlowMemory\flowmemory-review
```

Assigned issue: #67.

Prompt:

```text
Use the shared launch-core goal prefix.

Audit Rootflow V0 and Flow Memory V0 acceptance across PRs.

Primary scope:
- docs/
- .github/
- infra/scripts/
- review notes

Required outcomes:
- Update docs/reviews/ROOTFLOW_FLOW_MEMORY_V0_ACCEPTANCE_AUDIT.md after each launch-core PR changes.
- Map every acceptance row to concrete files, commands, tests, fixtures, or dashboard evidence.
- Identify missing evidence.
- Identify unsafe claims.
- Identify cross-PR conflicts.
- Recommend merge order.
- Do not implement subsystem product work.

Required evidence:
- updated review matrix.
- merge readiness status.
- named blockers.
- comments on PRs when acceptance evidence is missing.
```
