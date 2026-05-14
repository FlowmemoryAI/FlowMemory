# FlowChain L1 Long-Loop Goal Pack

Status: copy-ready `/goal` prompts for long-running Codex agents.

Last updated: 2026-05-14.

## Baseline

Start from current `main`. Do not rebuild what already exists.

Already implemented and verified:

- local/private FlowChain product testnet package;
- `npm run flowchain:product-e2e`;
- local devnet runtime with product token and DEX smoke;
- wallet signing and product transaction vectors;
- control-plane API and product read methods;
- dashboard/workbench product surfaces;
- bridge local-credit handoff smoke;
- contracts, crypto, dashboard, hardware, services, and full smoke gates;
- second-computer verification on `FalconXtreme`.

## Final Stop Condition

The long-loop program is complete only when this command exists and passes from
a clean-ish Windows checkout:

```powershell
npm run flowchain:l1-e2e
```

That command must prove:

1. `npm run flowchain:product-e2e` passes.
2. A multi-node local network smoke passes.
3. A local wallet E2E passes for create/import/export/account switching/signing.
4. A bridge testnet/local-credit E2E passes without real mainnet funds.
5. The control-plane/explorer can query live node, wallet, tx, token, DEX,
   bridge, hardware, and provenance state.
6. The dashboard can run against the live API and show clear recovery actions.
7. A beginner/offline second-computer bundle can be produced and smoke-tested.
8. No public API, export, log, fixture, or dashboard payload exposes
   private-key, seed, mnemonic, RPC credential, API key, or webhook material.

## Agent Tracking Rules

Each agent must create and maintain its own files under:

```text
docs/agent-runs/<agent-name>/
```

Required files:

- `PLAN.md` for the current plan and stop condition.
- `CHECKLIST.md` for measurable items, checked off as they pass.
- `EXPERIMENTS.md` for attempts, results, and failures.
- `NOTES.md` for concise chronological handoff notes.

Each agent must keep its feedback loop tight. Prefer the smallest relevant test
first, then the subsystem smoke, then `npm run flowchain:product-e2e`, then the
future `npm run flowchain:l1-e2e`.

## Prompt Files

- `chain-network.md`
- `wallet-crypto.md`
- `control-plane-explorer.md`
- `dashboard-workbench.md`
- `bridge-testnet.md`
- `contracts-settlement.md`
- `installer-ops.md`
- `hardware-signals.md`
- `research-decisions.md`
- `hq-review.md`

## Launcher

From the main checkout:

```powershell
cd E:\FlowMemory\flowchain-release
powershell -ExecutionPolicy Bypass -File .\infra\scripts\launch-flowchain-l1-long-loop-agents.ps1
```

Use `-DryRun` first to print the windows that would be started.
