# FlowChain Full L1 Agent Goals

Status: copy-ready long-running `/goal` prompts for building FlowChain from the
current local deterministic devnet into a runnable private/local L1 testnet.

These prompts are intentionally implementation-heavy. They are for dedicated
Codex agents in separate worktrees. Agents must build on existing code and must
not create replacement systems.

Target local acceptance:

1. A clean Windows machine can install and run FlowChain with one obvious path.
2. At least one long-running local node produces blocks.
3. Optional LAN or multi-process nodes can join a private testnet.
4. Transactions can be signed, submitted, included, queried, exported, and
   replayed deterministically.
5. Agent, model, receipt, artifact, verifier, memory, challenge, and finality
   lifecycle objects are real local runtime objects, not only static fixtures.
6. The control-plane API exposes node, chain, account, transaction, bridge, and
   object state to the workbench.
7. The workbench shows verified live API status and can inspect or trigger the
   local flow.
8. A bridge POC can observe Base Sepolia or mocked Base lock events and credit
   the local chain in a replay-safe test mode.
9. `npm run flowchain:full-smoke` proves the whole path.

Prompt files:

- `chain-runtime.md`
- `crypto-wallet.md`
- `control-plane-indexer.md`
- `dashboard-workbench.md`
- `contracts-settlement.md`
- `bridge-relayer.md`
- `hardware-signals.md`
- `research-consensus.md`
- `hq-integration-review.md`

Launch helper:

```powershell
cd E:\FlowMemory\flowchain-release
powershell -ExecutionPolicy Bypass -File .\infra\scripts\launch-full-l1-agents.ps1
```
