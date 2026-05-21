# Public Release Gap Register

Status: public gap register for the current repository release.

These are not hidden defects. They are the remaining work required before FlowMemory can move from public local/test implementation toward externally operated pilots or broader production claims.

## Open Gaps

### 1. Base Sepolia public-agent deployment and readback

Tracking issue: https://github.com/FlowmemoryAI/FlowMemory/issues/164

Current state: scripts and contract stack exist, but no full public-agent network Base Sepolia broadcast/readback is committed for this release.

Missing work:

- fund and configure a dedicated testnet deployer locally;
- broadcast the public-agent and swarm stack to Base Sepolia;
- read back emitted launch, registry, fuel, bond, and swarm events with bounded block ranges;
- commit non-secret deployment/readback evidence;
- source-verify deployed contracts where supported.

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

Current state: FlowChain SDK exposes control-plane wrappers, and FlowMemory helpers produce deterministic roots plus contract-aligned launch hashes. Direct transaction submission is not yet a complete SDK surface.

Missing work:

- signer-provider abstraction that does not accept raw secrets by default;
- calldata or provider-backed submission for `AgentFactory.launchAgent`;
- calldata or provider-backed submission for `SwarmFactory.createSwarm`;
- receipt polling and event decoding;
- test coverage against local Anvil broadcast logs.

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

## Verification Rule

A gap closes only when the implementation, docs, tests, and public-safe evidence all exist in the repository or linked GitHub issue/PR history. A passing unit test alone is not enough.
