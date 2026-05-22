# Public Tester Guide

Status: public tester guide for the current local/test FlowMemory release.

This guide is for people who want to try something real in the public repo and report useful feedback. The goal is not to prove production readiness. The goal is to make the local/test agent-memory, Agent Bonds, public-agent, SDK, CLI, and dashboard surfaces easy to reproduce and evaluate.

## What Testers Can Use Today

| Lane | What you test | Requires | Main command |
| --- | --- | --- | --- |
| Quick JS smoke | Public-agent helpers, SDK wrappers, agent-memory client, control-plane-backed flows | Node.js + npm | `npm run public:test:quick` |
| Public-agent contracts | Agent class/tool registries, launch factory, shell factory, swarms, budget vault | Foundry | `npm run public:test:contracts` |
| Local public-agent e2e | Full local public-agent + swarm script path | Foundry | `npm run public:test:e2e` |
| Dashboard/mobile workbench | React dashboard views, shared mobile UI surface, and production build | Node.js + npm | `npm run public:test:dashboard` |
| CLI / control-plane smoke | Public-agent and public-swarm CLI calls against a live local control-plane server | Node.js + npm | `npm run public:test:cli` |
| Public hardening gate | Public docs, scripts, issue-template, and CI wiring | Node.js + npm | `npm run public:hardening` |
| Full public local pass | All public tester lanes plus hardening and claim guardrails | Node.js + npm + Foundry | `npm run public:test:all` |


Authorized operators can also rehearse the Base Sepolia public-agent deployment plan and bounded readback path. That lane is not required for normal public testers because dry run, broadcast, and readback require local RPC and deployer credentials.
If you only have Node.js, run the quick JS smoke first. If you also have Foundry, run the contract and e2e lanes.

## Setup

```powershell
git clone https://github.com/FlowmemoryAI/FlowMemory.git
cd FlowMemory
npm install
npm install --prefix apps/dashboard
```

Foundry is required only for the Solidity lanes:

```powershell
forge --version
```

Do not create or commit `.env` files for these tests. The public tester lanes use deterministic local/test data and do not require live private keys or RPC credentials.

Before reporting a public docs or setup problem, you can run the static public hardening gate:

```powershell
npm run public:hardening
```

To generate a paste-ready local report for GitHub:

```powershell
npm run public:test:report
```

By default this runs the quick JS smoke lane and writes public-safe JSON and Markdown files under `reports/local/public-test-reports/`. That folder is intentionally ignored by Git.

You can include more lanes:

```powershell
npm run public:test:report -- --contracts --e2e
npm run public:test:report -- --all
```


## Lane 1: Quick JS Smoke

Run:

```powershell
npm run public:test:quick
```

This exercises:

- public-agent launch preview and launch-intent helper code;
- public swarm launch preview and intent helper code;
- SDK wrapper method coverage;
- agent-memory SDK fixture/control-plane client flows.

Useful feedback:

- Did the command run without extra undocumented setup?
- Were failures clear enough to diagnose?
- Which Node/npm versions worked or failed?

## Lane 2: Public-Agent Contracts

Run:

```powershell
npm run public:test:contracts
```

This runs the Foundry tests under `tests/Public*.t.sol`, including:

- class, tool, profile, bond, fuel, lineage, and receipt registries;
- `AgentFactory` signed launch flow and nonce rejection;
- swarm creation, membership, budget lines, reservations, spends, and lifecycle transitions;
- shell factory checks.

Useful feedback:

- Did Foundry install cleanly on your platform?
- Did any contract test fail nondeterministically?
- Were public-agent or swarm concepts confusing from test names/output?

## Lane 3: Local Public-Agent E2E

Run:

```powershell
npm run public:test:e2e
```

This runs `script/RunPublicAgentNetworkLocalE2E.s.sol:RunPublicAgentNetworkLocalE2E` in local Foundry script mode. It deploys the public-agent and swarm stack locally, signs a deterministic launch intent, creates an agent, creates a swarm containing that agent, creates a budget line, reserves/releases budget, and records a spend.

Useful feedback:

- Did the script run on a clean clone?
- Were the emitted addresses and ids understandable?
- What output would make it easier to trust what happened?

## Lane 4: Dashboard Workbench

Run:

```powershell
npm run public:test:dashboard
```

Then optionally start the dashboard:

```powershell
npm run dev --prefix apps/dashboard
```

Open the local URL printed by Vite and review:

- Flow Memory / Rootflow views;
- Agent Bonds view;
- Public Agent Network view;
- Base canary boundary copy;
- raw JSON views.
- Mobile app purpose and boundary from `docs/MOBILE_APPS.md`;

Useful feedback:

- Could you tell what was fixture-backed versus live?
- Were unsafe claims or production-sounding copy visible?
- Which view felt most real, and which felt like a placeholder?
- Is the mobile/operator app purpose clear from the dashboard and docs?

## Lane 5: CLI / Control-Plane Trial

Fast path:

```powershell
npm run public:test:cli
```

Manual setup is not required for this lane; the command starts and stops its own local server:

```powershell
npm run public:test:cli
```

The smoke command starts a local control-plane server, runs the public-agent and public-swarm CLI checks against it, validates JSON schemas, and shuts the server down.

Useful feedback:
- Did the commands return useful JSON?
- Were field names understandable?
- What should the CLI summarize for non-protocol users?


## Authorized Operator Lane: Base Sepolia Public-Agent Rehearsal

Public-safe plan command:

```powershell
npm run public-agent-network:base-sepolia:plan -- --deployer-address 0x69F55917209C446bf9d31D2903e01966B75a8cDe --json
```

Operator-only dry run, broadcast, and readback commands are documented in `docs/DEPLOYMENTS/BASE_SEPOLIA_PUBLIC_AGENT_NETWORK.md`. Reports from that lane should include only public addresses, transaction hashes, contract addresses, bounded block ranges, event counts, and source-verification statuses. Never include private keys, RPC URLs, explorer API keys, or `.env` content.

## What To Report
If you want the repo to generate most of the report body, run:

```powershell
npm run public:test:report
```

Then copy the generated `.md` file from `reports/local/public-test-reports/` into the issue.


Open a GitHub issue using the **Public Tester Report** template and include:

- operating system;
- Node/npm/Foundry versions when relevant;
- exact commands run;
- whether each lane passed or failed;
- the first useful error, not a huge log dump;
- screenshots for dashboard issues;
- whether the docs matched what actually happened.

Never include private keys, seed phrases, RPC credentials, API keys, webhook URLs, wallet secrets, or private user data.

## What Good Feedback Looks Like

Good:

```text
Lane: Public-agent contracts
OS: Windows 11
Command: npm run public:test:contracts
Result: failed
First error: forge could not find solc 0.8.24
Expected docs to mention the Foundry install command.
```

Good:

```text
Lane: Dashboard workbench
Route: Public Agent Network
Result: passed
Feedback: The class/tool panels are understandable, but the swarm budget section needs a clear empty/live/prototype badge.
```

Not useful:

```text
It did not work.
```

## Current Public Test Missions

The maintainer can pin tester issues with the `public-tester` label. Good first missions are:

1. Run `npm run public:test:quick` on a clean clone.
2. Run `npm run public:test:contracts` on Windows, macOS, or Linux.
3. Run `npm run public:test:e2e` and report the emitted local ids.
4. Run the dashboard and review public-agent / Agent Bonds copy for clarity.
5. Start the control-plane and try the public-agent CLI commands.
6. Review `docs/MOBILE_APPS.md` and confirm the Android/iOS boundary is clear.

## Boundary Reminder

Passing these tests means the local/test public surfaces are reproducible. It does not mean the contracts are audited, production-ready, mainnet-ready, or approved for uncapped value-bearing use.

Mobile note: Android shell code is committed and documented. iOS is a product track, but public testers should not expect a runnable iOS app until `apps/dashboard/ios` exists.
