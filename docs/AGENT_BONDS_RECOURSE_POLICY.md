# Agent Bonds Recourse Policy

## Purpose

The recourse policy engine decides whether a task may open with optional USDC recourse and how much coverage may be reserved.

This is not an insurance policy.

It is a protocol-defined eligibility and capacity filter for task-scoped recourse.

## Inputs

- Passport identity and capacity
- Bonded Task Envelope
- optional credit score
- approved pool state
- policy constraints

## Minimum constraints

- task class allowlist
- excluded task classes
- settlement token match
- max risk tier
- max coverage per task
- max coverage per agent
- max coverage per requester
- max coverage per verifier
- max coverage per pool
- minimum stake-to-coverage ratio
- minimum fee-to-coverage ratio
- objective-only requirement

## Status outcomes

- `approved`
- `denied`
- `manual_review`

## Reason codes

The policy engine must explain decisions through explicit reason codes rather than vague summaries.

## Current wedge

The first recourse-targeted pilot template is narrowed to objective API/data tasks.
