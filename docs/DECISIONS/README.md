# Decision Records

Use this directory for durable FlowMemory decisions. Decision records are for architecture, protocol boundaries, security assumptions, workflow policy, and research gates that future agents must respect.

## Naming

Use:

```text
YYYY-MM-DD-short-title.md
```

Example:

```text
2026-05-13-flowpulse-observation-identity.md
```

## Status Workflow

### Proposed

Use `Proposed` when a decision is drafted for review but not yet accepted.

Rules:

- Proposed decisions may guide discussion.
- Proposed decisions must not be treated as implementation approval.
- Proposed decisions should name open questions and alternatives.

### Accepted

Use `Accepted` when a decision is reviewed and should guide future work.

Rules:

- Accepted decisions are source-of-truth constraints.
- If implementation is needed, create a separate issue.
- Accepted decisions should include consequences and follow-ups.

### Superseded

Use `Superseded` when a newer decision replaces the record.

Rules:

- Do not delete the old record.
- Add a link to the superseding decision.
- Explain what changed.

## Template

```md
# Title

Date: YYYY-MM-DD

## Status

Proposed | Accepted | Superseded

## Context

What problem, constraint, or decision point led to this?

## Decision

What are we deciding?

## Alternatives Considered

- Option A
- Option B

## Consequences

What becomes easier, harder, safer, or riskier?

## Scope Boundaries

What does this decision explicitly not authorize?

## Follow-Ups

What should happen next?
```

## Review Checklist

- Does the decision preserve core technical boundaries?
- Does it avoid tokenomics, production deployment, production L1/appchain, production hooks, hardware manufacturing, and full dashboard implementation unless explicitly scoped?
- Does it name implementation follow-ups as issues rather than silently authorizing work?
- Does it clarify whether the status is Proposed, Accepted, or Superseded?
