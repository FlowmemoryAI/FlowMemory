/goal You are the FlowChain Wallet/Crypto long-loop agent.

Worktree: E:\FlowMemory\flowmemory-crypto
Branch: agent/l1-loop-wallet-crypto

Baseline: product transaction schemas and wallet product smoke already exist. Extend them. Do not create a second wallet system.

Allowed folders:
- crypto/
- schemas/flowmemory/
- fixtures/crypto/ if present
- docs/agent-runs/wallet-crypto/
- wallet/crypto docs under docs/

Forbidden folders:
- crates/
- services/
- apps/dashboard/
- contracts/
- hardware/

Create tracking files first:
- docs/agent-runs/wallet-crypto/PLAN.md
- docs/agent-runs/wallet-crypto/CHECKLIST.md
- docs/agent-runs/wallet-crypto/EXPERIMENTS.md
- docs/agent-runs/wallet-crypto/NOTES.md

Quantitative goal: complete 10/10 checks below:
1. `npm test --prefix crypto` passes.
2. `npm run wallet:product-smoke --prefix crypto` passes.
3. A wallet E2E command exists and passes from root or crypto package.
4. The wallet can create, unlock, export public metadata, import test metadata, rotate local accounts, and list accounts.
5. The wallet can sign every current product transaction type.
6. The verifier rejects replay, wrong chain id, wrong signer role, mutated payload, malformed public key, duplicate nonce, and expired or missing envelope fields.
7. Test vectors include positive and negative cases for transfer, token launch, pool create, add/remove liquidity, swap, bridge credit ack, withdrawal intent, node/operator signal, and network join authorization if supported.
8. No exported public metadata contains private key, seed, mnemonic, RPC credential, API key, or webhook-shaped text.
9. Runtime/control-plane consumers can validate envelopes without importing secret-handling code.
10. `npm run flowchain:product-e2e` still passes after your changes.

Implementation constraints:
- Use existing crypto helpers and schemas.
- Keep secrets local and ignored.
- Keep this testnet/local until a separate audit gate exists.
- Do not implement tokenomics or production custody.

Feedback loop:
1. Run focused crypto tests.
2. Run wallet smoke.
3. Run schema/vector validation.
4. Run `npm run flowchain:product-e2e`.
5. If `npm run flowchain:l1-e2e` exists, run it last.

PR output:
- Document schema/version changes.
- Include exact commands run.
- Name any runtime/control-plane integration contract that changed.
