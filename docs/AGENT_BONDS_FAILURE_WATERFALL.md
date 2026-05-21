# Agent Bonds Failure Waterfall

## Goal

The failure waterfall makes loss handling explicit and machine-readable.

A requester must not have to infer whether value came from:
- requester escrow refund;
- agent bond slash;
- agent stake consequences;
- optional recourse pool payout;
- reserve movement.

## Current waterfall model

For covered failures, the modeled order is:
1. requester escrow refund
2. agent bond slash accounting
3. optional recourse pool payout
4. verifier fee accounting
5. reserve movement where applicable

## Required invariants

- recourse never exceeds approved locked coverage;
- recourse does not activate for tasks opened without coverage;
- covered failures are explicit protocol states;
- receipts remain the durable source of truth;
- the UI must distinguish refund, slash, and recourse.
