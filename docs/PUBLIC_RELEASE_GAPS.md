# Public Release Gap Register

Status: public gap register for the current repository release.

These are not hidden defects. They are the remaining work required before FlowMemory can move from public local/test implementation toward externally operated pilots or broader production claims.

## Open Gaps

### 1. Base Sepolia public-agent deployment and readback

Tracking issue: https://github.com/FlowmemoryAI/FlowMemory/issues/164

Current state: public-agent deployment, smoke-broadcast, source-verification, and bounded event-readback tooling now exists. The configured public testnet deployer address is recorded in `fixtures/deployments/public-agent-network-base-sepolia-plan.json` and `docs/DEPLOYMENTS/BASE_SEPOLIA_PUBLIC_AGENT_NETWORK.md`, but no full public-agent network Base Sepolia broadcast/readback evidence is committed yet.

Missing work:

- fund the dedicated Base Sepolia deployer and set local env without committed secrets;
- run dry-run, broadcast, and bounded readback for the public-agent and swarm stack;
- commit non-secret deployment/readback evidence with transaction hashes, contract addresses, and event-group counts;
- source-verify deployed contracts where supported and record submitted/verified/pending status per contract.

### 2. Keeper / runtime automation

Tracking issue: https://github.com/FlowmemoryAI/FlowMemory/issues/165

Current state: contracts expose launch, fuel, bond, receipt, lineage, and swarm primitives. The long-running automation layer is not implemented.

Missing work:

- keeper loop for fuel metering and memory receipts;
- challenge/correction projection into every SDK and dashboard surface;
- replay-safe lifecycle job orchestration;
- operator runbook and failure drill for automation.

### 3. Direct contract-backed SDK submission

Tracking issue: https://github.com/FlowmemoryAI/FlowMemory/issues/166

Current state: the public helper layer exposes control-plane wrappers, deterministic roots, contract-aligned launch hashes, direct calldata builders, EIP-712 typed-data signing requests, EIP-1193 provider-backed submission helpers, transaction receipt polling, and public-agent/swarm receipt event decoding. The SDK does not accept raw private keys by default.

Missing work:

- local Anvil SDK e2e that prepares, signs through an external provider, submits `AgentFactory.launchAgent`, waits for the receipt, and checks decoded launch/fuel/bond events;
- local Anvil SDK e2e that submits `SwarmFactory.createSwarm`, waits for the receipt, and checks decoded swarm/budget events;
- negative local Anvil coverage for nonce replay and bad class/toolset through the direct SDK lane;
- public evidence from those local Anvil broadcast logs.

### 4. Public-network dashboard live data

Tracking issue: https://github.com/FlowmemoryAI/FlowMemory/issues/167

Current state: the dashboard renders a public-agent-network view backed by deterministic local data and control-plane projections.

Missing work:

- contract event backed discovery rows;
- agent profile detail pages;
- launch-bond and memory-fuel account panels;
- swarm budget-line, reservation, spend, membership, fork, dissolve, and graduation views;
- correction/challenge timelines.

### 5. Swarm-born agents and memory inheritance

Tracking issue: https://github.com/FlowmemoryAI/FlowMemory/issues/168

Current state: lineage supports parent agents and swarms, and swarms support membership and lifecycle transitions.

Missing work:

- swarm-to-agent launch UX and SDK flow;
- inherited memory root policy;
- reputation / receipt inheritance projection;
- forked swarm and child-agent replay report.


### 6. Mobile operator apps and iOS shell

Tracking issue: https://github.com/FlowmemoryAI/FlowMemory/issues/174

Current state: the shared dashboard/workbench has a committed Android Capacitor shell and desktop Electron builds. The iOS app is a documented product track, but no Xcode project or macOS CI lane is committed yet.

Missing work:

- Android debug APK public tester lane and clean-clone evidence;
- mobile-first Agent Bonds, receipts, recourse, wallet/budget, public-agent, and alert views;
- iOS Capacitor/Xcode project;
- macOS CI build lane for iOS simulator/device testing;
- mobile signing and release runbook that does not require committed secrets.

## Verification Rule

A gap closes only when the implementation, docs, tests, and public-safe evidence all exist in the repository or linked GitHub issue/PR history. A passing unit test alone is not enough.
