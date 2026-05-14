# FlowChain Private/Local Protocol Contract

Date: 2026-05-13

## Status

Accepted for the private/local testnet package.

## Context

Runtime, crypto, RPC, wallet, bridge, and dashboard agents need one source of truth for profile IDs, genesis, accounts, transaction envelopes, payloads, blocks, receipts, events, bridge evidence, state roots, finality, and export snapshots.

The existing Rust devnet and control-plane surfaces already model many of these concepts, but they did not have one schema-backed fixture package that every downstream agent could validate.

## Decision

Add private/local FlowChain protocol schemas under `schemas/flowmemory/production-*.schema.json` and deterministic fixtures under `fixtures/production-l1/`.

The canonical profile IDs are:

- `flowchain-local-private`
- `flowchain-local-multinode`
- `flowchain-base8453-pilot`

The old phrases `flowchain-local` and `flowchain-private-lan` are aliases only. They are not valid signing-domain profile IDs.

The Base pilot profile is local/private on the destination side and uses Base chain ID `8453` only as the source evidence chain.

## Consequences

- Downstream agents can run `npm run validate:production-l1-protocol` and `npm run validate:production-l1-fixtures`.
- The fixture package contains one valid transaction for every payload type and one invalid transaction for every payload type.
- Bridge duplicate-source-event rejection has a stable error code.
- State roots and genesis hashes are deterministic and recomputed by validation.

## Scope Boundaries

This decision does not authorize public mainnet readiness, public validators, tokenomics, value-bearing bridge readiness, audited cryptography, public RPC, or hosted services.

## Follow-Ups

- Runtime agent: implement typed state transition checks against the payload catalog.
- Wallet/crypto agent: replace fixture-only signatures with the accepted local signing helper.
- Bridge agent: preserve source event duplicate keys from bounded Base readers.
- RPC/dashboard agents: display structured receipt failure reasons and finality states.
