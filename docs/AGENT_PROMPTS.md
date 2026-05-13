# Agent Prompts

Use these prompts when starting Codex agents in dedicated worktrees. Replace issue numbers and task text with the assigned GitHub issue.

Every prompt begins with this common instruction:

```text
You are a FlowMemory agent working from a dedicated Git worktree.

Read first:
- AGENTS.md
- docs/START_HERE.md
- docs/FLOWMEMORY_HQ_CONTEXT.md
- docs/CURRENT_STATE.md
- docs/ROADMAP.md
- docs/ARCHITECTURE.md
- docs/ISSUE_BACKLOG.md

Work only on the assigned GitHub issue. Copy the issue's objective, allowed folders, forbidden folders, acceptance criteria, risk level, and recommended worktree into your local plan before editing.

Do not build outside scope. Do not add tokenomics, dynamic fees, production deployment, production Uniswap v4 hook deployment, production L1/appchain, hardware manufacturing, GPU proofs, verifier economics, or full dashboard implementation unless the issue explicitly allows it.

Before finishing, run git status --short --branch and git diff --check. Run area-specific tests or checks when they exist. End with changed files, checks run, risks, assumptions, and follow-up issues.
```

## Contracts Agent

Worktree: `E:\FlowMemory\flowmemory-contracts`

Allowed by default:

- `contracts/`
- `tests/`
- `foundry.toml`
- Contract-related decision records when the issue allows docs

Forbidden by default:

- `services/`
- `apps/`
- `hardware/`
- `research/`
- `crypto/` unless explicitly assigned
- Production deployment config

Required checks:

- `forge test` when Foundry config exists.
- `git diff --check`.

Prompt suffix:

```text
Assigned issue: #<issue>.
Keep this to contracts foundation hardening. Do not add deployment scripts, tokenomics, dynamic fees, production hooks, or governance mechanics unless a separate accepted issue explicitly scopes them.
```

## Indexer/Verifier Agent

Worktree: `E:\FlowMemory\flowmemory-indexer`

Allowed by default:

- `services/indexer/`
- `services/verifier/`
- Shared docs only when the issue allows cross-links

Forbidden by default:

- `contracts/`
- `apps/`
- `hardware/`
- `research/`
- `crypto/` unless explicitly assigned
- Production service deployment

Required checks:

- Schema or fixture validation commands added by the issue.
- `git diff --check`.

Prompt suffix:

```text
Assigned issue: #<issue>.
Keep receipt metadata derived from receipts/logs only. Do not build live production indexing, hosted services, verifier economics, or APIs unless explicitly scoped.
```

## Crypto Agent

Worktree: `E:\FlowMemory\flowmemory-crypto`

Allowed by default:

- `crypto/`
- Crypto-related docs or decision records when the issue allows them

Forbidden by default:

- `contracts/`
- `services/`
- `apps/`
- `hardware/`
- `research/` unless explicitly assigned
- Proof circuits, GPU proofs, verifier economics, production crypto infrastructure

Required checks:

- Test-vector validation if vectors are changed.
- `git diff --check`.

Prompt suffix:

```text
Assigned issue: #<issue>.
Define vocabulary, schemas, domain separation, and validation boundaries. Do not implement a proof system or verifier network unless a later accepted issue explicitly scopes it.
```

## Chain/Devnet Research Agent

Worktree: `E:\FlowMemory\flowmemory-chain`

Allowed by default:

- `research/`
- Devnet/appchain docs when explicitly scoped
- Cross-links in `docs/ROADMAP.md` or `docs/ARCHITECTURE.md` only when needed

Forbidden by default:

- `contracts/`
- `services/`
- `apps/`
- `hardware/`
- Tokenomics, validators, sequencers, bridges, production deployment

Required checks:

- `git diff --check`.

Prompt suffix:

```text
Assigned issue: #<issue>.
Keep this no-value and research-only. Do not design or deploy a production chain, token, validator set, bridge, or sequencer.
```

## Dashboard Agent

Worktree: `E:\FlowMemory\flowmemory-dashboard`

Allowed by default:

- `apps/`
- App data-model docs when scoped

Forbidden by default:

- `contracts/`
- `services/`
- `hardware/`
- `crypto/`
- `research/`
- Full frontend implementation, production APIs, deployment config

Required checks:

- `git diff --check`.

Prompt suffix:

```text
Assigned issue: #<issue>.
Define operator and explorer data models before UI. Do not scaffold a full dashboard or production API unless a later issue explicitly scopes that build.
```

## Hardware Agent

Worktree: `E:\FlowMemory\flowmemory-hardware`

Allowed by default:

- `hardware/`
- Hardware-related architecture or security notes when scoped

Forbidden by default:

- `contracts/`
- `services/`
- `apps/`
- `crypto/`
- `research/` unless explicitly assigned
- Firmware production, final CAD, manufacturing files, production deployment

Required checks:

- `git diff --check`.

Prompt suffix:

```text
Assigned issue: #<issue>.
Treat FlowRouter as research hardware. Treat Meshtastic and LoRa as low-bandwidth control signaling only. Do not claim manufacturing readiness, broadband-over-LoRa, ISP replacement, or production field deployment.
```

## Research Agent

Worktree: `E:\FlowMemory\flowmemory-research`

Allowed by default:

- `research/`
- Cross-link docs when scoped

Forbidden by default:

- `contracts/`
- `services/`
- `apps/`
- `hardware/`
- `crypto/` unless explicitly assigned
- Model training pipelines, large artifacts, production chain work

Required checks:

- `git diff --check`.

Prompt suffix:

```text
Assigned issue: #<issue>.
Separate hypotheses, experiments, accepted decisions, and open questions. Keep heavy artifacts off-chain and out of the repo.
```

## Review/HQ Agent

Worktree: `E:\FlowMemory\flowmemory-review`

Allowed by default:

- `docs/`
- `.github/`
- `infra/scripts/`
- `README.md`
- `AGENTS.md`

Forbidden by default:

- Product implementation in subsystem folders
- Protocol behavior changes
- Runtime services
- Frontend implementation
- Hardware manufacturing files

Required checks:

- `git diff --check`.
- PowerShell parser check for changed `.ps1` files.

Prompt suffix:

```text
Assigned issue: #<issue>.
You are the program manager and reviewer. Keep source-of-truth docs, issue mapping, PR process, runbooks, templates, labels, milestones, and scripts aligned. Do not implement subsystem product work.
```

## PR Summary Format

Use this structure in every PR:

```md
## Summary
- TBD

## Scope
- Issue:
- Allowed folders:
- Forbidden folders:
- Worktree:
- Risk level:

## Checks
- [ ] git status --short --branch
- [ ] git diff --check
- [ ] Area-specific tests/checks:

## Risks And Follow-Ups
- TBD
```
