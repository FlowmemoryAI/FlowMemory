# Agent Bonds / FlowMemory Discovered Live References

Date: 2026-05-20

## Purpose

This file records live addresses and transactions that already exist in the repository so operators do not have to rediscover them manually.

These are not Agent Bonds pilot deployment addresses. They are the existing Base canary V0 references already committed to the repo.

## Most Likely Prior Live Testing Address

The strongest candidate for the address you previously used with real ETH is the committed Base canary deployer:

- `0x3A6fBA5a78216ba3a8DA8d8F501dee2C8186aFf9`

Why:

- it is explicitly recorded as the Base mainnet canary deployer
- it had a nonzero ETH balance during the live canary actions
- it is also recorded as the on-chain owner of the smoke-tested Rootfield

Committed evidence:

- `docs/DEPLOYMENTS/2026-05-13-base-canary-v0.md`
- `docs/OPERATIONS/V0_OPERATOR_POLICY.md`

Observed balance from the committed deployment record:

- before deploy/smoke: `0.005451853012787615 ETH`
- after deploy/smoke: `0.005423591837039270 ETH`

## Existing Base Mainnet Canary Contract Addresses

- RootfieldRegistry: `0x2a7ADd68a1d45C3251E2F92fFe4926124654a97C`
- FlowMemoryHookAdapter: `0x179Df6d52e9DeF5D02704583a2E4E5a9FF427245`
- ArtifactRegistry: `0x8F074d0F4e66975b740A4b7a316330c9660a485E`
- CursorRegistry: `0x3360689009685eade15c876855D24161b05829C1`
- ReceiptVerifier: `0x94ba7aA4562f8F8528C327378F6352350f6ddB5B`
- WorkerRegistry: `0xa8c07eF53Eeb4e57297ee35025a9cD5303fCCD29`
- VerifierRegistry: `0xAf920ca7436Bb72172E27C96E0B716f01dcC5DBd`
- WorkReceiptRegistry: `0x2874cee0D581E4562ac9015BfCf330f1ea58a1F3`
- VerifierReportRegistry: `0x95bC7455AdFD60e1B908ba455c25Ae732C1Ef996`
- WorkDebtScheduler: `0xa752e9bC7fAf39f659110D8Cf408E7707db94E34`

## Machine-Readable Version

- `fixtures/agent-bonds/discovered-live-references.json`

## Boundary

These references are useful for:

- identifying the known live deployer account
- browsing existing canary contracts and transactions
- comparing a future capped Agent Bonds deployment against prior FlowMemory live activity

These references are not enough to approve a new public value-bearing launch by themselves.
