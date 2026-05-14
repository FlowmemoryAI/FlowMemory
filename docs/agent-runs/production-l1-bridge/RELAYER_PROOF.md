# Relayer Proof

Status: implemented and tested.

Main implementation:

- `services/bridge-relayer/src/observe-base-lockbox.ts`
- `services/bridge-relayer/src/bridge-pilot-e2e.ts`
- `services/bridge-relayer/src/bridge-live-readiness-check.ts`

Live Base gates:

- Calls `eth_chainId` before log reads.
- Requires `0x2105` for Base chain ID `8453`.
- Requires explicit operator acknowledgement.
- Requires explicit lockbox address.
- Requires explicit supported token.
- Requires confirmation depth.
- Requires bounded `fromBlock` and `toBlock`.
- Rejects scans wider than 5000 blocks.
- Rejects unapproved lockbox.
- Rejects unsupported token.
- Rejects missing local recipient.
- Rejects deposits over configured cap.

Deterministic IDs:

- observation ID: derived from observed deposit source fields
- replay key: derived from source chain, lockbox, tx hash, log index, and deposit ID
- credit ID: derived from observation ID and deposit fields
- pilot evidence ID: derived from observation, credit, and guardrails
- withdrawal intent ID: derived from credit, asset, amount, FlowChain account, and Base recipient
- release evidence ID: derived from withdrawal intent and release evidence hash
- withdrawal authorization ID: derived from withdrawal intent, signed payload hash, and deterministic test signature

Evidence outputs:

- `bridge-observation.json`
- `bridge-credit.json`
- `bridge-pilot-evidence.json`
- `bridge-runtime-handoff.json`
- `bridge-withdrawal-intent.json`
- `bridge-withdrawal-authorization.json`
- `bridge-release-evidence.json`
- `bridge-local-usage-proof.json`

Test proof:

- `npm test --prefix services/bridge-relayer` passed with 15 tests.
- `npm run bridge:pilot:mock:e2e` passed.
- `npm run bridge:pilot:live:check` passed.
