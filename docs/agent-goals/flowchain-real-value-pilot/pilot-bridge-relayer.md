/goal You are the FlowChain Real-Value Pilot Bridge Relayer agent.

Worktree: E:\FlowMemory\flowmemory-live-bridge
Branch: agent/real-value-pilot-bridge

Goal: implement the relayer path that observes a tiny capped deposit on Base public network chain ID `8453`, derives a deterministic bridge credit, applies it to local FlowChain exactly once, and supports pilot withdrawal/release evidence.

Inspect first:
- current `services/bridge-relayer`;
- E:\FlowMemory\flowmemory-bridge-full active bridge-testnet work;
- E:\FlowMemory\flowmemory-live-contracts if it exists;
- current runtime bridge-credit handoff shape.

Allowed folders:
- services/bridge-relayer/
- fixtures/bridge/
- schemas/flowmemory/bridge*.json
- infra/scripts/bridge-*.ps1
- infra/scripts/flowchain-real-value*.ps1
- docs/bridge/
- docs/agent-runs/real-value-pilot-bridge/

Forbidden folders:
- contracts/ except generated ABI fixture or read-only docs coordination
- crates/ except read-only handoff review
- apps/dashboard/
- crypto/ secret internals
- hardware/

Create and maintain:
- docs/agent-runs/real-value-pilot-bridge/PLAN.md
- docs/agent-runs/real-value-pilot-bridge/CHECKLIST.md
- docs/agent-runs/real-value-pilot-bridge/EXPERIMENTS.md
- docs/agent-runs/real-value-pilot-bridge/NOTES.md

Quantitative acceptance:
1. `npm test --prefix services/bridge-relayer` passes.
2. Existing `npm run bridge:local-credit:smoke` passes.
3. New mock pilot E2E passes without external RPC.
4. New Base public-network observer verifies `eth_chainId == 0x2105`.
5. Observer rejects wrong chain IDs and unapproved contract addresses.
6. Observer supports confirmation depth configuration.
7. Deposit observation writes deterministic observation, credit, and evidence files.
8. Duplicate deposit event replay is rejected or idempotent with explicit evidence.
9. Credit handoff applies to local runtime exactly once.
10. Withdrawal intent/release evidence path exists for pilot mode.
11. Script prints exact next operator command after every step.
12. No private key, seed phrase, mnemonic, RPC credential, API key, or webhook appears in committed fixtures, logs, exports, or API payloads.
13. `npm run flowchain:real-value-pilot:e2e` includes this bridge path.
14. `npm run flowchain:product-e2e` still passes or the breakage is assigned.

Feedback loop:
- Run bridge tests.
- Run mock pilot E2E.
- Run wrong-chain negative tests.
- Run local-credit smoke.
- Run product E2E.

PR output:
- Include exact commands for mock mode and live observer mode.
- Include env vars required.
- Include failure/retry/replay behavior.
