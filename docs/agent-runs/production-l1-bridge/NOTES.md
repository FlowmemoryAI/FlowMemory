# Capped Base 8453 Bridge Pilot Notes

Initial assumptions:

- Live Base credentials and owner keys are not available in the repository.
- The mock pilot path must fully run without live RPC or keys.
- Live Base mode must fail closed until the owner supplies local env values and explicit acknowledgement.
- Evidence and logs must name required env variables but never print env values.

Resolved decisions:

- The current lockbox supports both native ETH and ERC20 custody paths. The owner pilot activates exactly one configured asset through `FLOWCHAIN_BASE8453_SUPPORTED_TOKEN`; zero address means native ETH, any nonzero address means that ERC20.
- Local FlowChain credit state is represented by bridge-relayer JSON state and handoff artifacts under `services/bridge-relayer/out/` and `fixtures/bridge/local-runtime-bridge-handoff.json`.
- The bridge relayer writes a deterministic local transfer handoff artifact. Product/DEX usage remains covered by the existing `npm run flowchain:product-e2e` gate because this task does not edit runtime, dashboard, or product execution modules.
- Live Base transaction execution remains blocked without owner-supplied RPC URL, deployer private key, lockbox address, supported asset, caps, confirmations, bounded block range, and acknowledgement.
