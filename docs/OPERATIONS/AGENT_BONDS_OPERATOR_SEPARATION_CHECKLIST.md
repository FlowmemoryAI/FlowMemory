# Agent Bonds Operator Separation Checklist

Date: 2026-05-20

## Objective

No public value-bearing pilot should ship with one operator silently controlling every safety role.

## Required Distinct Roles

At minimum, these roles must not collapse into one person or one hot wallet:

- multisig owners
- pause guardian
- resolution authority
- designated verifier
- confirming verifier
- requester operator when running internal pilot tasks

## Required Checks

- multisig owners are unique and threshold is at least 2
- pause guardian is not a multisig owner
- resolution authority is not the same key as pause guardian
- designated verifier is not also the confirming verifier
- production-shaped policy has `requiredConfirmations >= 1`
- filled pilot config passes `npm run flowmemory:agent-bonds:pilot-config:validate`

## Sign-Off Table

Record the actual operators before public pilot launch:

| Role | Address | Operator name | Separate from every conflicting role? |
| --- | --- | --- | --- |
| Multisig owner 1 | | | |
| Multisig owner 2 | | | |
| Multisig owner 3 | | | |
| Pause guardian | | | |
| Resolution authority | | | |
| Designated verifier | | | |
| Confirming verifier | | | |

## Go/No-Go Rule

If this table is incomplete or any conflict remains unresolved, the system can still be published on GitHub and demonstrated locally, but it is not ready for a public value-bearing pilot.
