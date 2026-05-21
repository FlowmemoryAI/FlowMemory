# Security and Trust Boundaries

## Security posture

This workstream should be designed as a bounded local/test protocol extension first. It handles autonomous action and public memory, so the default posture must be conservative: small action spaces, explicit caps, fail-closed checks, and visible failure memory.

## Core boundaries

1. Chain-side memory is public.
2. Storage is expensive and must stay compact.
3. Full model reasoning stays off-chain unless reduced to a bounded deterministic kernel.
4. Contracts do not know final transaction hash or log index during execution.
5. Indexers and verifiers are part of the trust story and must be named.
6. Gateways and runtimes may improve UX but must not become hidden sources of truth.
7. Tool routing must be allowlisted and capped.
8. Corrections must be append-only.
9. Production or mainnet readiness remains blocked without separate gates, tests, review, and owner approval.

## Threat model

| Threat | Risk | Mitigation |
| --- | --- | --- |
| Memory poisoning | Agent records false or malicious memory. | Typed memory, source receipts, verifier reports, challenge/correction path. |
| Hidden off-chain decision | Runtime chooses action not produced by kernel. | Preview/commit parity, expected preview hash, replay checks. |
| Over-broad tool access | Agent calls unsafe targets. | Tool allowlist roots, selector checks, value caps, rate limits. |
| Stale preview | Caller commits action from old state. | Sequence checks and parent root checks. |
| Cap bypass | Agent spends more than policy allows. | Per-action and epoch counters in contract. |
| External call revert | Agent state becomes inconsistent. | Checks-effects-interactions discipline, explicit failure memory, safe revert behavior. |
| Evidence unavailable | Memory appears supported but cannot be verified. | `unresolved` status and evidence availability windows. |
| Reorg | Memory is based on non-canonical receipt. | Reorg-aware indexer and status projection. |
| Admin key misuse | Owner changes policy or pauses unfairly. | Two-step ownership/timelock where appropriate, visible policy updates. |
| Upgrade ambiguity | Users misunderstand mutable contracts. | Address registry and docs label upgrade/owner category. |
| Secret leakage | Private prompts or keys enter public memory. | Secret scanning, content-mode defaults, explicit public-memory rule. |
| Model overclaim | Docs imply unrestricted chain-side reasoning. | Bounded kernel language and guardrail checks. |

## Privacy boundary

Anything written to contract storage or event logs is public. This includes short strings, roots, pointers, labels, and event payloads.

Rules:

- never write secrets;
- never write API keys, RPC URLs, private keys, seed phrases, or webhook URLs;
- never write private prompts by default;
- never write user-private memory as public content;
- default heavy/private content to commitments;
- show content mode in SDK and dashboard.

## Action safety

Actions must be safe by construction.

Required controls:

- fixed action enum;
- allowed target address;
- allowed selector;
- call data hash or typed parameter validation;
- max value per action;
- max value per epoch;
- max calls per window;
- pause and self-pause paths;
- failure memory;
- replay-visible reason code.

Do not add a generic arbitrary-call executor to the first implementation.

## Kernel safety

The kernel must be deterministic.

Required controls:

- no randomness unless explicitly sourced and replayable;
- no external state reads outside declared inputs unless documented;
- no unbounded loops over large memory;
- no free-form target/call generation;
- integer or fixed-point scoring only;
- all action choices gated by rules;
- fixed output struct.

Later tiny model kernels must be constrained to classification or ranking over a small action set.

## Memory safety

Memory writes must be bounded and typed.

Required controls:

- known memory type;
- content mode;
- source observation or receipt;
- parent root;
- new root;
- status;
- expiry/supersession fields when relevant;
- challenge/correction path.

Memory updates must not silently overwrite earlier memory.

## Trust boundaries by layer

| Layer | Trusted for | Not trusted for |
| --- | --- | --- |
| Contracts | Enforcing state transitions, caps, allowlists, event emission. | Knowing receipt metadata, storing large/private data. |
| Indexer | Deriving receipt/log identity and projections. | Creating facts not present in receipts or configured evidence. |
| Verifier | Applying named rules to observations and commitments. | Absolute truth beyond its rules and evidence. |
| SDK | Safe encoding, reads, previews, submissions, replay helpers. | Secret management beyond no-persistence guidance. |
| Runtime/keeper | Watching and submitting transactions. | Hidden agent reasoning. |
| Dashboard | Human-readable projection. | Source of protocol truth. |
| External models | Design/review assistance. | Runtime authority unless output is compiled into deterministic policy. |

## Admin and ownership

Early local/test contracts can use simple ownership for speed, but docs must label it clearly.

Later surfaces should choose explicitly:

- immutable once deployed;
- owner-controlled pilot;
- timelocked owner;
- governed upgrade path;
- deprecated/read-only historical surface.

No address should be presented without its ownership and pause model.

## Pause model

Pause must be available at least at the agent level.

Pause effects:

- block `step` mutations;
- block memory commits unless correction-only mode is explicitly allowed;
- preserve reads;
- preserve replay;
- emit visible pause event or FlowPulse;
- expose pause reason code where possible.

## Challenge and correction safety

Corrections must not delete evidence.

A correct correction flow:

1. target a memory cell or transition;
2. include evidence root or verifier report;
3. emit a correction event;
4. produce a new memory root;
5. mark old memory as superseded in projections;
6. preserve the original receipt trail.

## Documentation guardrails

Docs must not claim:

- production readiness;
- mainnet readiness;
- unrestricted chain-side model inference;
- private on-chain memory;
- fully trustless verification;
- free storage;
- hidden gateway memory as chain-resident memory;
- external model review as protocol proof.

## Security review checklist

Before any implementation PR claims completion for this workstream:

- [ ] Preview and commit parity tests exist.
- [ ] Tool allowlist tests exist.
- [ ] Cap enforcement tests exist.
- [ ] Stale sequence tests exist.
- [ ] Parent root mismatch tests exist.
- [ ] Paused agent mutation tests exist.
- [ ] Failed action handling is tested.
- [ ] Event fields support indexer replay.
- [ ] Secret-shaped inputs are rejected where runtime intake exists.
- [ ] Docs label chain, environment, owner, and deployment boundary.
- [ ] SDK examples distinguish `eth_call` preview from mutation.
- [ ] Dashboard labels pending/failed/unresolved/unsupported/reorged states.

## Incident scenarios to rehearse

- accepted task later fails evidence availability;
- tool target disabled after preview but before commit;
- task state changes between preview and commit;
- memory root changes because another step landed first;
- verifier reports unsupported memory type;
- source receipt is reorged;
- owner pauses agent during active task;
- external review identifies unsafe policy after registration.

Each scenario should produce visible state, not silence.
