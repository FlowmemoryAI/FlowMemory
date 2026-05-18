/goal You are the FlowChain Real-Value Pilot Wallet/Operator agent.

Worktree: E:\FlowMemory\flowmemory-live-wallet
Branch: agent/real-value-pilot-wallet

Goal: build the local operator/wallet support needed to run the capped real-value pilot without committing secrets and without browser-side private-key handling.

Inspect first:
- current `crypto` wallet CLI;
- E:\FlowMemory\flowmemory-crypto active long-loop work;
- bridge relayer env/config needs.

Allowed folders:
- crypto/
- schemas/flowmemory/
- fixtures/crypto/
- infra/scripts/flowchain-wallet*.ps1
- docs/agent-runs/real-value-pilot-wallet/
- wallet/operator docs under docs/

Forbidden folders:
- crates/
- contracts/
- services/ except read-only integration review
- apps/dashboard/
- hardware/

Create and maintain:
- docs/agent-runs/real-value-pilot-wallet/PLAN.md
- docs/agent-runs/real-value-pilot-wallet/CHECKLIST.md
- docs/agent-runs/real-value-pilot-wallet/EXPERIMENTS.md
- docs/agent-runs/real-value-pilot-wallet/NOTES.md

Quantitative acceptance:
1. `npm test --prefix crypto` passes.
2. Existing product wallet smoke passes.
3. New pilot wallet/operator E2E command exists and passes.
4. Local operator config can be created from env without committing secrets.
5. Public metadata export excludes private keys, seed phrases, mnemonics, RPC credentials, API keys, and webhooks.
6. Signing supports bridge credit acknowledgment, withdrawal intent, release evidence, and emergency pause/revoke messages where relevant.
7. Verification rejects wrong chain ID, wrong contract address, wrong operator, mutated payload, replay nonce, expired message, and missing cap fields.
8. CLI prints exact next commands for deploy/observe/credit/release workflow.
9. Runtime/control-plane can validate public envelopes without loading secret vault code.
10. `npm run flowchain:product-e2e` still passes.

Feedback loop:
- Run focused crypto tests.
- Run wallet E2E.
- Run product smoke.
- Run pilot E2E if available.

PR output:
- Include env/config boundary.
- Include exact commands run.
- Include remaining integration blockers.
