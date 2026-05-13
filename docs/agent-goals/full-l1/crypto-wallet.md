/goal You are the FlowChain crypto, wallet, and local key agent.

You are working in `E:\FlowMemory\flowmemory-crypto`.

Mission: make FlowChain locally usable by adding the wallet/signing/object
identity layer needed for a real private/local L1 testnet. Build on the existing
`crypto/` package and `schemas/flowmemory/`. Do not create a second crypto
package.

Read first:
- AGENTS.md
- docs/FLOWCHAIN_FULL_PRIVATE_TESTNET.md
- docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md
- crypto/
- schemas/flowmemory/
- crates/flowmemory-devnet/ transaction/object model

Allowed folders:
- crypto/
- schemas/flowmemory/
- docs/DECISIONS/ for crypto/key decisions
- docs/FLOWCHAIN_TESTNET_ACCEPTANCE.md only for acceptance evidence

Do not edit:
- apps/
- services/ implementation
- contracts/
- hardware/
- crates/flowmemory-devnet/ except tiny schema examples only if coordinated

Build requirements:
1. Define canonical local transaction envelopes with domain separation,
   chain-id, nonce, signer, payload hash, and signature.
2. Add object IDs, hash inputs, schemas, and vectors for:
   AgentAccount, ModelPassport, WorkReceipt, ArtifactAvailabilityProof,
   VerifierModule, VerifierReport, MemoryCell, Challenge, FinalityReceipt,
   BridgeDeposit, BridgeCredit, BridgeWithdrawal, and local account balance.
3. Add a local encrypted wallet/vault for test keys. It must support create,
   unlock, list public accounts, sign transaction, import/export public metadata,
   and rotate or create additional accounts.
4. Keep secrets out of committed fixtures and exports.
5. Add negative vectors for wrong chain id, wrong domain, wrong signer, replayed
   nonce, malformed roots, malformed bridge deposit, and changed object type.
6. Provide a small CLI or npm script surface that other agents can call for
   wallet create/sign/verify.

Expected commands to add or make work:
- `npm run wallet:create --prefix crypto`
- `npm run wallet:sign --prefix crypto`
- `npm run wallet:verify --prefix crypto`
- `npm run validate:vectors --prefix crypto`
- contribute to `npm run flowchain:full-smoke`

Acceptance:
- `npm test --prefix crypto` passes.
- crypto vector validation passes.
- A local transaction envelope can be signed and verified without exposing the
  private key.
- The devnet agent can consume the envelope format.
- The control-plane agent can display public signer/account metadata without
  secrets.
- `git diff --check` passes.
- Open a PR and push your branch.
