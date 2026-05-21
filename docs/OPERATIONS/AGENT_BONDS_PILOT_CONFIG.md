# Agent Bonds Pilot Config

Date: 2026-05-20

## Purpose

A public capped pilot should not rely on ad hoc operator memory for roles, caps, and addresses.

Use:

- `fixtures/agent-bonds/pilot-config.template.json` as the canonical config template
- `schemas/flowmemory/agent-bonds-pilot-config.schema.json` as the validation contract
- `npm run flowmemory:agent-bonds:pilot-config:validate -- fixtures/agent-bonds/pilot-config.template.json` to validate a filled config

Practical default:

- `contracts.settlementToken` = external stable asset used for payouts/refunds/bonds, usually USDC on Base
- `contracts.stakeToken` = your project token
  - If you are using Base mainnet, the official Circle USDC address is `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`.
- if you launch only one project token, do not use it as the settlement token in the public value-bearing path


## What The Validator Enforces

- nonzero addresses for core contracts and roles
- multisig threshold does not exceed owner count
- multisig owners are unique
- designated verifiers and confirming verifiers are distinct
- pause guardian is separate from multisig owners
- max open exposure is at least max payout per task
- slither gate is explicitly acknowledged
- production-shaped policy requires at least one independent confirmation

- a sole company owner can still satisfy the multisig requirement with a company-controlled signer set; the requirement is about operational key separation, not equity ownership

## What The Validator Does Not Prove

- the addresses actually control the deployed contracts
- the operators are independent in the real world
- the target RPC, custody, or settlement-token issuer is safe
- the config is economically sensible for your audience size

This config file is a go-live input artifact, not a go-live proof by itself.

For the final public value-bearing gate, combine the filled pilot config with `fixtures/agent-bonds/launch-approval.template.json` and run the public launch validator described in `docs/OPERATIONS/AGENT_BONDS_PUBLIC_LAUNCH_APPROVAL.md`.
