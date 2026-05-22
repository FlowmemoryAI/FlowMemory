# Launch Demo Runbook

This runbook is the public-safe FlowMemory launch demo path. It shows the product story without claiming production readiness, tokenomics, guaranteed recourse, hosted APIs, or audited infrastructure.

## Demo Promise

Use this talk track:

```text
FlowMemory is an accountability layer for autonomous agents. It combines FlowPulse receipts, Rootflow transitions, Flow Memory objects, Agent Bonds, public-agent launch primitives, and operator apps so builders can inspect what agents did, what evidence exists, and which work is verified or challenged.
```

The demo shows:

- public launch docs and tester lanes;
- generated FlowMemory V0 dashboard fixtures;
- Agent Bonds task-accountability state;
- public-agent and swarm fixture state;
- browser, desktop, Android, and planned iOS operator-app story;
- guarded Base canary review where explicitly documented.

The demo does not claim:

- production mainnet readiness;
- tokenomics, token launch, or public incentive mechanics;
- production bridge readiness;
- hosted production API availability;
- audited cryptography;
- guaranteed reimbursement or insurance;
- hardware manufacturing or field deployment.

## Preflight

From the repo root:

```powershell
npm install
npm install --prefix apps/dashboard
npm run public:hardening
npm run public:test:quick
npm run public:test:cli
```

For the full public launch gate:

```powershell
npm run public:test:all
```

If a command fails, capture the first failing command, the relevant output, and the changed files. Do not skip the failing lane and call the demo ready.

## Browser Demo

Generate the dashboard fixture and start the dashboard:

```powershell
npm run flowmemory:generate
npm run dev --prefix apps/dashboard
```

Open the local Vite URL printed by the command.

Click through:

| Route | What to show |
| --- | --- |
| `/overview` | FlowMemory launch fixture metrics, alerts, and current public-launch state. |
| `/flowmemory` | MemorySignal, MemoryReceipt, RootfieldBundle, AgentMemoryView, and RootflowTransition state. |
| `/flowpulse` | FlowPulse event observations and receipt linkage. |
| `/rootfields` | Rootfield namespaces and committed roots. |
| `/work` | Work receipts and evidence pointers. |
| `/verifier` | Verifier reports and reason codes. |
| `/agent-bonds` | Task accountability, challenge, recourse, and settlement state. |
| `/agents` | Public-agent and swarm state. |
| `/hardware` | FlowRouter POC heartbeat/control-signal records. |
| `/alerts` | Operator warnings and recommended local actions. |
| `/raw` | JSON payloads only when a reviewer asks for source data. |
| `/canary` | Guarded Base canary evidence, clearly labeled as historical canary-only test evidence. |

## Mobile And Desktop Story

Show the committed app packaging tracks:

```powershell
npm run mobile:android:sync --prefix apps/dashboard
npm run desktop:pack --prefix apps/dashboard
```

Only run Android debug builds when Java and Android tooling are installed:

```powershell
npm run mobile:android:debug --prefix apps/dashboard
```

State clearly that Android has a committed Capacitor shell and iOS remains a documented product track until an Xcode project and CI lane are committed.

## Public Tester Packet

Generate a tester report locally:

```powershell
npm run public:test:report
```

The report writes under `reports/local/public-test-reports/`, which is ignored by Git. Never paste private keys, mnemonics, RPC credentials, API keys, webhook URLs, or personal data into tester reports.

## Recovery

If fixture data looks stale:

```powershell
npm run flowmemory:generate
npm run build --prefix apps/dashboard
```

If public docs or claims changed:

```powershell
npm run public:hardening
node infra/scripts/check-unsafe-claims.mjs
```

If a public test lane fails, fix the source issue. Do not suppress tests, narrow the demo, or relabel an incomplete lane as launch-ready.
